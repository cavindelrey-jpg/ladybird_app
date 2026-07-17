#!/usr/bin/env python3
"""
Academia Past-Paper Ingestion Pipeline
========================================
Takes a ZIP of PDFs (clean text or scanned/photographed), extracts metadata
using Claude, generates thumbnails, checks for duplicates, and uploads
everything to Firebase (Storage + Firestore).

Usage:
    python ingest.py --zip path/to/papers.zip --key path/to/serviceAccount.json --bucket academia-b1705.appspot.com

Requirements (see requirements.txt):
    pip install firebase-admin PyMuPDF pytesseract Pillow anthropic

Also requires Tesseract OCR installed on your system (NOT a pip package):
    Windows: https://github.com/UB-Mannheim/tesseract/wiki  (installer)
    After installing, note the install path, e.g.
    C:\\Program Files\\Tesseract-OCR\\tesseract.exe
    Set it below in TESSERACT_CMD or via --tesseract-path flag.

Environment variable required:
    ANTHROPIC_API_KEY   -> your own Anthropic API key (console.anthropic.com)
"""

import argparse
import hashlib
import io
import json
import os
import shutil
import sys
import tempfile
import zipfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

# ---- Third-party imports (installed via requirements.txt) ----
try:
    import fitz  # PyMuPDF
except ImportError:
    print("Missing dependency: PyMuPDF. Run: pip install PyMuPDF")
    sys.exit(1)

try:
    import pytesseract
    from PIL import Image
except ImportError:
    print("Missing dependency: pytesseract/Pillow. Run: pip install pytesseract Pillow")
    sys.exit(1)

try:
    import firebase_admin
    from firebase_admin import credentials, firestore, storage
except ImportError:
    print("Missing dependency: firebase-admin. Run: pip install firebase-admin")
    sys.exit(1)

try:
    import anthropic
except ImportError:
    print("Missing dependency: anthropic. Run: pip install anthropic")
    sys.exit(1)


# =========================================================================
# CONFIG
# =========================================================================

# If Tesseract isn't on your system PATH, set the full path here, e.g.:
# TESSERACT_CMD = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
TESSERACT_CMD = None

# Minimum characters of extracted text before we consider a page "has text"
# (below this threshold, we treat the page as scanned/image-only and OCR it)
TEXT_THRESHOLD_PER_PAGE = 40

# How many characters of extracted text to send to Claude for metadata inference
MAX_TEXT_CHARS_FOR_CLAUDE = 6000

# Claude model to use for metadata extraction
CLAUDE_MODEL = "claude-sonnet-4-6"

FIRESTORE_COLLECTION = "papers"
STORAGE_PDF_PREFIX = "papers"
STORAGE_THUMB_PREFIX = "thumbnails"


# =========================================================================
# DATA STRUCTURES
# =========================================================================

@dataclass
class ProcessResult:
    filename: str
    status: str  # "uploaded" | "duplicate" | "needs_review" | "failed"
    reason: str = ""
    metadata: dict = field(default_factory=dict)
    firestore_id: str = ""


# =========================================================================
# TEXT EXTRACTION (native + OCR fallback)
# =========================================================================

def extract_text_from_pdf(pdf_path: Path) -> tuple[str, bool]:
    """
    Returns (extracted_text, was_ocr_used).
    Tries native text extraction first; falls back to OCR per-page
    if a page has little/no extractable text.
    """
    doc = fitz.open(pdf_path)
    all_text = []
    ocr_used = False

    # Only process first 5 pages for metadata purposes (enough context,
    # keeps things fast for exam papers which are often 10-30 pages)
    max_pages_for_text = min(len(doc), 5)

    for page_num in range(max_pages_for_text):
        page = doc[page_num]
        native_text = page.get_text().strip()

        if len(native_text) >= TEXT_THRESHOLD_PER_PAGE:
            all_text.append(native_text)
        else:
            # Fall back to OCR for this page
            ocr_used = True
            pix = page.get_pixmap(dpi=200)
            img_bytes = pix.tobytes("png")
            img = Image.open(io.BytesIO(img_bytes))
            ocr_text = pytesseract.image_to_string(img).strip()
            all_text.append(ocr_text)

    doc.close()
    combined = "\n".join(all_text).strip()
    return combined, ocr_used


def generate_thumbnail(pdf_path: Path, output_path: Path) -> bool:
    """Render page 1 of the PDF to a JPEG thumbnail. Returns True on success."""
    try:
        doc = fitz.open(pdf_path)
        page = doc[0]
        pix = page.get_pixmap(dpi=120)
        pix.save(str(output_path))
        doc.close()
        return True
    except Exception as e:
        print(f"  [thumbnail failed] {e}")
        return False


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


# =========================================================================
# METADATA EXTRACTION VIA CLAUDE
# =========================================================================

METADATA_PROMPT_TEMPLATE = """You are helping organize a library of GCE (General Certificate of Education) \
past exam papers, notes, and assignments for a Cameroonian educational platform called Academia.

Below is text extracted from the first few pages of a document (it may be a past exam paper, \
marking scheme, lecture notes, or assignment). Some text may contain OCR errors from scanned pages \
— use context and best judgment.

Analyze the content and respond with ONLY a JSON object (no markdown fences, no preamble, no explanation) \
with these exact fields:

{{
  "title": "string - a clear, human-readable title for this document",
  "subject": "string - e.g. Physics, Chemistry, Biology, Economics, Literature in English, Mathematics, etc.",
  "level": "string - one of: O-Level, A-Level, or Unknown if unclear",
  "examBoard": "string - e.g. GCE Board Cameroon, Cambridge, or Unknown",
  "docType": "string - one of: past_paper, marking_scheme, notes, assignment, other",
  "year": "string - 4-digit exam/document year if identifiable, else empty string",
  "paperNumber": "string - e.g. 'Paper 1', 'Paper 2' if identifiable, else empty string",
  "confidence": "string - one of: high, medium, low - your confidence in this classification"
}}

Filename of this document (may contain hints): {filename}

Extracted text:
---
{text}
---

Respond with ONLY the JSON object.
"""


def infer_metadata_with_claude(client: anthropic.Anthropic, filename: str, text: str) -> dict:
    truncated_text = text[:MAX_TEXT_CHARS_FOR_CLAUDE]
    if not truncated_text.strip():
        truncated_text = "(no text could be extracted from this document, even with OCR)"

    prompt = METADATA_PROMPT_TEMPLATE.format(filename=filename, text=truncated_text)

    response = client.messages.create(
        model=CLAUDE_MODEL,
        max_tokens=500,
        messages=[{"role": "user", "content": prompt}],
    )

    raw_text = "".join(
        block.text for block in response.content if block.type == "text"
    ).strip()

    # Strip markdown fences if Claude adds them despite instructions
    if raw_text.startswith("```"):
        raw_text = raw_text.strip("`")
        if raw_text.startswith("json"):
            raw_text = raw_text[4:]
        raw_text = raw_text.strip()

    try:
        return json.loads(raw_text)
    except json.JSONDecodeError:
        return {
            "title": filename,
            "subject": "Unknown",
            "level": "Unknown",
            "examBoard": "Unknown",
            "docType": "other",
            "year": "",
            "paperNumber": "",
            "confidence": "low",
            "_parse_error": raw_text[:200],
        }


# =========================================================================
# DUPLICATE DETECTION
# =========================================================================

def get_existing_hashes(db) -> set[str]:
    """Fetch all existing file hashes from Firestore to check against."""
    hashes = set()
    docs = db.collection(FIRESTORE_COLLECTION).select(["fileHash"]).stream()
    for doc in docs:
        data = doc.to_dict()
        if data.get("fileHash"):
            hashes.add(data["fileHash"])
    return hashes


# =========================================================================
# FIREBASE UPLOAD
# =========================================================================

def upload_to_firebase(db, bucket, pdf_path: Path, thumb_path: Path | None,
                        metadata: dict, file_hash: str) -> str:
    """Uploads PDF + thumbnail to Storage, creates Firestore doc. Returns doc ID."""
    safe_name = pdf_path.stem.replace(" ", "_")
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    storage_pdf_path = f"{STORAGE_PDF_PREFIX}/{safe_name}_{timestamp}.pdf"

    pdf_blob = bucket.blob(storage_pdf_path)
    pdf_blob.upload_from_filename(str(pdf_path), content_type="application/pdf")
    pdf_blob.make_public()  # remove this line if you want signed URLs instead

    thumb_url = ""
    if thumb_path and thumb_path.exists():
        storage_thumb_path = f"{STORAGE_THUMB_PREFIX}/{safe_name}_{timestamp}.jpg"
        thumb_blob = bucket.blob(storage_thumb_path)
        thumb_blob.upload_from_filename(str(thumb_path), content_type="image/jpeg")
        thumb_blob.make_public()
        thumb_url = thumb_blob.public_url

    doc_data = {
        "title": metadata.get("title", pdf_path.stem),
        "subject": metadata.get("subject", "Unknown"),
        "level": metadata.get("level", "Unknown"),
        "examBoard": metadata.get("examBoard", "Unknown"),
        "docType": metadata.get("docType", "other"),
        "year": metadata.get("year", ""),
        "paperNumber": metadata.get("paperNumber", ""),
        "classificationConfidence": metadata.get("confidence", "low"),
        "fileUrl": pdf_blob.public_url,
        "thumbnailUrl": thumb_url,
        "fileHash": file_hash,
        "originalFilename": pdf_path.name,
        "uploadedAt": firestore.SERVER_TIMESTAMP,
        "uploadSource": "ingest_pipeline_v1",
    }

    _, doc_ref = db.collection(FIRESTORE_COLLECTION).add(doc_data)
    return doc_ref.id


# =========================================================================
# MAIN PIPELINE
# =========================================================================

def main():
    parser = argparse.ArgumentParser(description="Academia past-paper ingestion pipeline")
    parser.add_argument("--zip", required=True, help="Path to ZIP file containing PDFs")
    parser.add_argument("--key", required=True, help="Path to Firebase service account JSON")
    parser.add_argument("--bucket", required=True, help="Firebase Storage bucket name, e.g. academia-b1705.appspot.com")
    parser.add_argument("--tesseract-path", default=None, help="Full path to tesseract.exe if not on PATH")
    parser.add_argument("--dry-run", action="store_true", help="Process and classify but don't upload to Firebase")
    args = parser.parse_args()

    if args.tesseract_path:
        pytesseract.pytesseract.tesseract_cmd = args.tesseract_path
    elif TESSERACT_CMD:
        pytesseract.pytesseract.tesseract_cmd = TESSERACT_CMD

    anthropic_key = os.environ.get("ANTHROPIC_API_KEY")
    if not anthropic_key:
        print("ERROR: Set the ANTHROPIC_API_KEY environment variable with your Anthropic API key.")
        print("  Windows (PowerShell): $env:ANTHROPIC_API_KEY = 'sk-ant-...'")
        sys.exit(1)

    claude_client = anthropic.Anthropic(api_key=anthropic_key)

    zip_path = Path(args.zip)
    key_path = Path(args.key)
    if not zip_path.exists():
        print(f"ERROR: ZIP file not found: {zip_path}")
        sys.exit(1)
    if not key_path.exists():
        print(f"ERROR: Firebase key file not found: {key_path}")
        sys.exit(1)

    # --- Init Firebase ---
    db = None
    bucket = None
    if not args.dry_run:
        cred = credentials.Certificate(str(key_path))
        firebase_admin.initialize_app(cred, {"storageBucket": args.bucket})
        db = firestore.client()
        bucket = storage.bucket()
        print("Fetching existing file hashes for duplicate detection...")
        existing_hashes = get_existing_hashes(db)
        print(f"  Found {len(existing_hashes)} existing documents in Firestore.\n")
    else:
        existing_hashes = set()
        print("[DRY RUN] Skipping Firebase init - no uploads will happen.\n")

    # --- Extract ZIP to temp dir ---
    work_dir = Path(tempfile.mkdtemp(prefix="academia_ingest_"))
    print(f"Extracting {zip_path.name} to temp folder...")
    with zipfile.ZipFile(zip_path, "r") as z:
        z.extractall(work_dir)

    pdf_files = sorted(work_dir.rglob("*.pdf"))
    print(f"Found {len(pdf_files)} PDF files.\n")

    results: list[ProcessResult] = []
    seen_hashes_this_run = set()

    for i, pdf_path in enumerate(pdf_files, 1):
        print(f"[{i}/{len(pdf_files)}] {pdf_path.name}")

        try:
            file_hash = file_sha256(pdf_path)

            if file_hash in existing_hashes or file_hash in seen_hashes_this_run:
                print("  -> Duplicate (matches existing/already-processed file). Skipping.")
                results.append(ProcessResult(pdf_path.name, "duplicate", "hash match"))
                continue
            seen_hashes_this_run.add(file_hash)

            text, ocr_used = extract_text_from_pdf(pdf_path)
            if ocr_used:
                print("  -> Used OCR (scanned/image content detected)")

            if not text.strip():
                print("  -> No text extracted even with OCR. Flagging for manual review.")
                results.append(ProcessResult(pdf_path.name, "needs_review", "no extractable text"))
                continue

            print("  -> Asking Claude to classify metadata...")
            metadata = infer_metadata_with_claude(claude_client, pdf_path.name, text)

            if metadata.get("_parse_error"):
                print("  -> Claude response could not be parsed as JSON. Flagging for manual review.")
                results.append(ProcessResult(pdf_path.name, "needs_review", "metadata parse error", metadata))
                continue

            print(f"  -> {metadata.get('subject')} | {metadata.get('level')} | "
                  f"{metadata.get('docType')} | {metadata.get('year')} | "
                  f"confidence={metadata.get('confidence')}")

            thumb_path = work_dir / f"{pdf_path.stem}_thumb.jpg"
            thumb_ok = generate_thumbnail(pdf_path, thumb_path)
            if not thumb_ok:
                thumb_path = None

            if args.dry_run:
                results.append(ProcessResult(pdf_path.name, "uploaded", "dry-run (not actually uploaded)", metadata))
                continue

            doc_id = upload_to_firebase(db, bucket, pdf_path, thumb_path, metadata, file_hash)
            print(f"  -> Uploaded. Firestore doc: {doc_id}")
            results.append(ProcessResult(pdf_path.name, "uploaded", "", metadata, doc_id))

        except Exception as e:
            print(f"  -> FAILED: {e}")
            results.append(ProcessResult(pdf_path.name, "failed", str(e)))

        print()

    # --- Cleanup temp dir ---
    shutil.rmtree(work_dir, ignore_errors=True)

    # --- Summary report ---
    uploaded = [r for r in results if r.status == "uploaded"]
    duplicates = [r for r in results if r.status == "duplicate"]
    needs_review = [r for r in results if r.status == "needs_review"]
    failed = [r for r in results if r.status == "failed"]

    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Total files processed : {len(results)}")
    print(f"Uploaded              : {len(uploaded)}")
    print(f"Duplicates skipped    : {len(duplicates)}")
    print(f"Needs manual review   : {len(needs_review)}")
    print(f"Failed                : {len(failed)}")
    print()

    if needs_review:
        print("--- Needs Manual Review ---")
        for r in needs_review:
            print(f"  - {r.filename} ({r.reason})")
        print()

    if failed:
        print("--- Failed ---")
        for r in failed:
            print(f"  - {r.filename} ({r.reason})")
        print()

    # Write a JSON report to disk alongside the script
    report_path = Path.cwd() / f"ingest_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(
            [
                {
                    "filename": r.filename,
                    "status": r.status,
                    "reason": r.reason,
                    "metadata": r.metadata,
                    "firestore_id": r.firestore_id,
                }
                for r in results
            ],
            f,
            indent=2,
        )
    print(f"Full report written to: {report_path}")


if __name__ == "__main__":
    main()
