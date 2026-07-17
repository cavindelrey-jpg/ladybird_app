# Academia Ingest Pipeline

A local script that takes a ZIP of past papers (clean or scanned), classifies each
one with Claude, generates thumbnails, skips duplicates, and uploads everything
straight to your Academia Firebase project (Firestore + Storage).

Academia the app never touches this — it's a separate admin-only tool you run
from your PC when you have a batch of papers to add.

---

## 1. One-time setup

Recommended location on your machine (next to, not inside, the Flutter project):

```
C:\Users\12406\academia_cameroon\ingest_tool\
```

Put `ingest.py`, `requirements.txt`, and this README in that folder.

### Install Python packages

```powershell
cd C:\Users\12406\academia_cameroon\ingest_tool
pip install -r requirements.txt
```

### Install Tesseract OCR (separate from the pip package)

`pytesseract` is just a Python wrapper — it needs the actual Tesseract OCR
program installed on Windows:

1. Download the installer: https://github.com/UB-Mannheim/tesseract/wiki
2. Run it, keep the default install path (usually `C:\Program Files\Tesseract-OCR\`)
3. You'll pass this path to the script with `--tesseract-path`, e.g.:
   ```
   --tesseract-path "C:\Program Files\Tesseract-OCR\tesseract.exe"
   ```
   (or hardcode it once in `ingest.py` under `TESSERACT_CMD` near the top, so
   you don't need to pass the flag every time)

### Firebase service account key

You already generated one. **Because a copy of it was pasted into a chat
conversation, rotate it before relying on this for real uploads:**

1. Firebase Console → Project Settings → Service Accounts
2. Manage service account permissions → find the key → delete/revoke it
3. Generate a new one
4. Save the new JSON file somewhere on your PC, e.g.:
   ```
   C:\Users\12406\academia_cameroon\ingest_tool\firebase-key.json
   ```
5. **Never commit this file to GitHub.** Add it to `.gitignore`.

### Anthropic API key

This script calls the Claude API directly (separate from your claude.ai
subscription) to classify each paper. Get a key from console.anthropic.com,
then set it as an environment variable before running the script:

```powershell
$env:ANTHROPIC_API_KEY = "sk-ant-your-key-here"
```

(This only lasts for the current PowerShell session — you'll set it again
next time you open a new terminal, or add it to your system environment
variables permanently via Windows Settings.)

### Find your Storage bucket name

Firebase Console → Storage → the bucket name is shown at the top, usually:
```
academia-b1705.appspot.com
```
or newer projects use:
```
academia-b1705.firebasestorage.app
```
Check yours and use exactly that string.

---

## 2. Running it

Basic run:

```powershell
python ingest.py --zip "C:\path\to\papers.zip" --key "firebase-key.json" --bucket "academia-b1705.appspot.com" --tesseract-path "C:\Program Files\Tesseract-OCR\tesseract.exe"
```

**Dry run first (recommended)** — classifies everything and shows you what
it *would* do, without touching Firebase at all:

```powershell
python ingest.py --zip "C:\path\to\papers.zip" --key "firebase-key.json" --bucket "academia-b1705.appspot.com" --tesseract-path "C:\Program Files\Tesseract-OCR\tesseract.exe" --dry-run
```

Review the printed classifications and the JSON report it writes out. Once
you're happy with the quality, run again without `--dry-run` for the real
upload.

---

## 3. What it does, step by step

1. Extracts the ZIP to a temp folder
2. For each PDF:
   - Computes a SHA-256 hash and checks it against every existing document
     already in Firestore (and against other files in this same batch) —
     skips exact duplicates
   - Extracts text from the first 5 pages (enough for classification)
   - If a page has little/no extractable text (i.e. it's a scanned photo),
     automatically falls back to OCR for that page
   - Sends the extracted text to Claude, which returns structured metadata:
     title, subject, level (O-Level/A-Level), exam board, document type
     (past_paper / marking_scheme / notes / assignment / other), year, paper
     number, and a confidence rating
   - Generates a JPEG thumbnail from page 1
   - Uploads the PDF and thumbnail to Firebase Storage
   - Creates a Firestore document in the `papers` collection with all
     metadata + public URLs
3. Anything with unparseable/empty text, or an unparseable Claude response,
   gets marked `needs_review` instead of uploaded — you check these by hand
4. Prints a summary (uploaded / duplicates / needs review / failed) and
   writes a full JSON report to disk in the same folder

---

## 4. Firestore schema this creates

Each document in the `papers` collection looks like:

```json
{
  "title": "GCE A-Level Physics Paper 2 2023",
  "subject": "Physics",
  "level": "A-Level",
  "examBoard": "GCE Board Cameroon",
  "docType": "past_paper",
  "year": "2023",
  "paperNumber": "Paper 2",
  "classificationConfidence": "high",
  "fileUrl": "https://storage.googleapis.com/.../papers/...pdf",
  "thumbnailUrl": "https://storage.googleapis.com/.../thumbnails/...jpg",
  "fileHash": "sha256...",
  "originalFilename": "Physics Paper 2 2023.pdf",
  "uploadedAt": "<server timestamp>",
  "uploadSource": "ingest_pipeline_v1"
}
```

**Important:** this schema needs to line up with whatever your Flutter
`PastPaper`/`Library` model expects in `academia_app`. If your existing
Firestore documents use different field names (e.g. `subjectName` instead
of `subject`), tell me and I'll adjust the script — better to fix this now
than after uploading 60 papers with the wrong field names.

---

## 5. Known limitations / things to watch

- Only reads the first 5 pages of each PDF for classification — fine for
  exam papers, but a 40-page notes document will only be classified from
  its intro
- `pdf_blob.make_public()` makes files publicly readable via a direct URL
  (no auth needed to view). If you'd rather use Firebase Storage's signed
  URLs or rely on your existing Firestore security rules instead, tell me
  and I'll switch this to use `download_url` tokens instead
- No retry logic yet if a Claude API call or Firebase upload fails mid-batch
  — a failed file is just logged and skipped, rerun the ZIP (duplicates
  will auto-skip already-uploaded ones)
- Duplicate detection is by exact file hash only — a rescanned copy of the
  same paper won't be caught (would need a title/year similarity check on
  top, doable later if this becomes a real problem)
