/**
 * Academia Past-Paper Ingestion Pipeline (Cloud Function version)
 * =================================================================
 * Trigger: admin uploads a ZIP of PDFs to Storage path `admin_uploads/*.zip`
 * This function automatically:
 *   1. Downloads + extracts the ZIP
 *   2. For each PDF: checks for duplicates (file hash), extracts text
 *      (native, falling back to Cloud Vision OCR for scanned pages),
 *      asks Claude to classify metadata, generates a thumbnail
 *   3. Uploads PDF + thumbnail to Storage, writes a Firestore doc
 *   4. Writes a summary report to Firestore (`ingestReports` collection)
 *      so the admin screen in the app can show progress/results
 *
 * Deploy: firebase deploy --only functions:ingestPastPapers
 */

const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const AdmZip = require("adm-zip");
const pdfParse = require("pdf-parse");
const vision = require("@google-cloud/vision");
const Anthropic = require("@anthropic-ai/sdk");
const crypto = require("crypto");
const os = require("os");
const path = require("path");
const fs = require("fs");

admin.initializeApp();

// pdf-to-img is an ES module; it must be loaded via dynamic import()
// rather than require(). We cache the loaded function after first use.
let _pdfToImgFn = null;
async function getPdfToImg() {
  if (!_pdfToImgFn) {
    const mod = await import("pdf-to-img");
    _pdfToImgFn = mod.pdf;
  }
  return _pdfToImgFn;
}

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

const FIRESTORE_COLLECTION = "papers";
const REPORTS_COLLECTION = "ingestReports";
const STORAGE_PDF_PREFIX = "papers";
const STORAGE_THUMB_PREFIX = "thumbnails";
const WATCH_FOLDER = "admin_uploads/"; // where admins drop ZIPs from the app
const TEXT_THRESHOLD = 40; // chars below which we treat a page as scanned
const MAX_TEXT_CHARS_FOR_CLAUDE = 6000;
const CLAUDE_MODEL = "claude-sonnet-4-6";

const visionClient = new vision.ImageAnnotatorClient();

// =========================================================================
// TEXT EXTRACTION (native + Vision OCR fallback)
// =========================================================================

async function extractText(pdfBuffer) {
  let nativeText = "";
  try {
    const parsed = await pdfParse(pdfBuffer, { max: 5 }); // first 5 pages
    nativeText = parsed.text.trim();
  } catch (e) {
    logger.warn("pdf-parse failed, will rely on OCR", e.message);
  }

  if (nativeText.length >= TEXT_THRESHOLD) {
    return { text: nativeText, ocrUsed: false };
  }

  // Fall back to OCR: render first page to image, send to Vision API
  logger.info("Native text too short, falling back to OCR");
  const tmpPdfPath = path.join(os.tmpdir(), `ocr_${Date.now()}.pdf`);
  fs.writeFileSync(tmpPdfPath, pdfBuffer);

  let ocrText = "";
  try {
    const pdfToImg = await getPdfToImg();
    const doc = await pdfToImg(tmpPdfPath, { scale: 2 });
    let pageCount = 0;
    for await (const imageBuffer of doc) {
      if (pageCount >= 3) break; // OCR first 3 pages max, keep it fast
      const [result] = await visionClient.textDetection({
        image: { content: imageBuffer },
      });
      const detections = result.textAnnotations;
      if (detections && detections.length > 0) {
        ocrText += detections[0].description + "\n";
      }
      pageCount++;
    }
  } catch (e) {
    logger.error("OCR failed", e.message);
  } finally {
    if (fs.existsSync(tmpPdfPath)) fs.unlinkSync(tmpPdfPath);
  }

  return { text: (nativeText + "\n" + ocrText).trim(), ocrUsed: true };
}

async function generateThumbnail(pdfBuffer) {
  const tmpPdfPath = path.join(os.tmpdir(), `thumb_${Date.now()}.pdf`);
  fs.writeFileSync(tmpPdfPath, pdfBuffer);
  try {
    const pdfToImg = await getPdfToImg();
    const doc = await pdfToImg(tmpPdfPath, { scale: 1.5 });
    for await (const imageBuffer of doc) {
      return imageBuffer; // first page only
    }
    return null;
  } catch (e) {
    logger.warn("Thumbnail generation failed", e.message);
    return null;
  } finally {
    if (fs.existsSync(tmpPdfPath)) fs.unlinkSync(tmpPdfPath);
  }
}

function sha256(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

// =========================================================================
// METADATA EXTRACTION VIA CLAUDE
// =========================================================================

const METADATA_PROMPT = (filename, text) => `You are helping organize a library of GCE (General Certificate of Education) \
past exam papers, notes, and assignments for a Cameroonian educational platform called Academia.

Below is text extracted from the first few pages of a document (it may be a past exam paper, \
marking scheme, lecture notes, or assignment). Some text may contain OCR errors from scanned pages \
— use context and best judgment.

Analyze the content and respond with ONLY a JSON object (no markdown fences, no preamble, no explanation) \
with these exact fields:

{
  "title": "string - a clear, human-readable title for this document",
  "subject": "string - e.g. Physics, Chemistry, Biology, Economics, Literature in English, Mathematics, etc.",
  "level": "string - one of: O-Level, A-Level, or Unknown if unclear",
  "examBoard": "string - e.g. GCE Board Cameroon, Cambridge, or Unknown",
  "docType": "string - one of: past_paper, marking_scheme, notes, assignment, other",
  "year": "string - 4-digit exam/document year if identifiable, else empty string",
  "paperNumber": "string - e.g. 'Paper 1', 'Paper 2' if identifiable, else empty string",
  "confidence": "string - one of: high, medium, low - your confidence in this classification"
}

Filename of this document (may contain hints): ${filename}

Extracted text:
---
${text.slice(0, MAX_TEXT_CHARS_FOR_CLAUDE) || "(no text could be extracted, even with OCR)"}
---

Respond with ONLY the JSON object.`;

async function classifyWithClaude(client, filename, text) {
  const response = await client.messages.create({
    model: CLAUDE_MODEL,
    max_tokens: 500,
    messages: [{ role: "user", content: METADATA_PROMPT(filename, text) }],
  });

  let raw = response.content
    .filter((b) => b.type === "text")
    .map((b) => b.text)
    .join("")
    .trim();

  if (raw.startsWith("```")) {
    raw = raw.replace(/```json/g, "").replace(/```/g, "").trim();
  }

  try {
    return JSON.parse(raw);
  } catch (e) {
    return {
      title: filename,
      subject: "Unknown",
      level: "Unknown",
      examBoard: "Unknown",
      docType: "other",
      year: "",
      paperNumber: "",
      confidence: "low",
      _parseError: raw.slice(0, 200),
    };
  }
}

// =========================================================================
// MAIN TRIGGER
// =========================================================================

exports.ingestPastPapers = onObjectFinalized(
  {
    secrets: [ANTHROPIC_API_KEY],
    memory: "2GiB",
    timeoutSeconds: 540,
    region: "us-east1", // must match your Storage bucket's region
  },
  async (event) => {
    const filePath = event.data.name;
    const bucketName = event.data.bucket;

    if (!filePath.startsWith(WATCH_FOLDER) || !filePath.toLowerCase().endsWith(".zip")) {
      logger.info(`Ignoring ${filePath} - not a watched ZIP upload`);
      return;
    }

    logger.info(`Starting ingestion for ${filePath}`);
    const bucket = admin.storage().bucket(bucketName);
    const db = admin.firestore();
    const claudeClient = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });

    // Create a report doc immediately so the app can show "processing..."
    const reportRef = db.collection(REPORTS_COLLECTION).doc();
    await reportRef.set({
      sourceFile: filePath,
      status: "processing",
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      results: [],
    });

    // --- Download and unzip ---
    const tmpZipPath = path.join(os.tmpdir(), path.basename(filePath));
    await bucket.file(filePath).download({ destination: tmpZipPath });

    const zip = new AdmZip(tmpZipPath);
    const entries = zip.getEntries().filter(
      (e) => !e.isDirectory && e.entryName.toLowerCase().endsWith(".pdf")
    );

    logger.info(`Found ${entries.length} PDFs in ${filePath}`);

    // Pre-fetch existing hashes for duplicate detection
    const existingHashes = new Set();
    const existingDocs = await db.collection(FIRESTORE_COLLECTION).select("fileHash").get();
    existingDocs.forEach((doc) => {
      const hash = doc.data().fileHash;
      if (hash) existingHashes.add(hash);
    });

    const results = [];
    const seenThisRun = new Set();

    for (const entry of entries) {
      const filename = path.basename(entry.entryName);
      logger.info(`Processing ${filename}`);

      try {
        const pdfBuffer = entry.getData();
        const hash = sha256(pdfBuffer);

        if (existingHashes.has(hash) || seenThisRun.has(hash)) {
          results.push({ filename, status: "duplicate", reason: "hash match" });
          continue;
        }
        seenThisRun.add(hash);

        const { text, ocrUsed } = await extractText(pdfBuffer);

        if (!text.trim()) {
          results.push({ filename, status: "needs_review", reason: "no extractable text" });
          continue;
        }

        const metadata = await classifyWithClaude(claudeClient, filename, text);

        if (metadata._parseError) {
          results.push({
            filename,
            status: "needs_review",
            reason: "metadata parse error",
            metadata,
          });
          continue;
        }

        const thumbBuffer = await generateThumbnail(pdfBuffer);

        // Upload PDF
        const safeName = filename.replace(/\.[^/.]+$/, "").replace(/\s+/g, "_");
        const timestamp = Date.now();
        const pdfStoragePath = `${STORAGE_PDF_PREFIX}/${safeName}_${timestamp}.pdf`;
        const pdfFile = bucket.file(pdfStoragePath);
        await pdfFile.save(pdfBuffer, { contentType: "application/pdf" });
        await pdfFile.makePublic();

        let thumbUrl = "";
        if (thumbBuffer) {
          const thumbStoragePath = `${STORAGE_THUMB_PREFIX}/${safeName}_${timestamp}.png`;
          const thumbFile = bucket.file(thumbStoragePath);
          await thumbFile.save(thumbBuffer, { contentType: "image/png" });
          await thumbFile.makePublic();
          thumbUrl = thumbFile.publicUrl();
        }

        const docData = {
          title: metadata.title || safeName,
          subject: metadata.subject || "Unknown",
          level: metadata.level || "Unknown",
          examBoard: metadata.examBoard || "Unknown",
          docType: metadata.docType || "other",
          year: metadata.year || "",
          paperNumber: metadata.paperNumber || "",
          classificationConfidence: metadata.confidence || "low",
          fileUrl: pdfFile.publicUrl(),
          thumbnailUrl: thumbUrl,
          fileHash: hash,
          originalFilename: filename,
          ocrUsed,
          uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
          uploadSource: "ingest_pipeline_v1",
        };

        const docRef = await db.collection(FIRESTORE_COLLECTION).add(docData);
        results.push({ filename, status: "uploaded", firestoreId: docRef.id, metadata });
        logger.info(`Uploaded ${filename} -> ${docRef.id}`);
      } catch (e) {
        logger.error(`Failed processing ${filename}`, e);
        results.push({ filename, status: "failed", reason: e.message });
      }
    }

    // --- Finalize report ---
    const summary = {
      total: results.length,
      uploaded: results.filter((r) => r.status === "uploaded").length,
      duplicates: results.filter((r) => r.status === "duplicate").length,
      needsReview: results.filter((r) => r.status === "needs_review").length,
      failed: results.filter((r) => r.status === "failed").length,
    };

    await reportRef.set({
      sourceFile: filePath,
      status: "complete",
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      summary,
      results,
    });

    logger.info(`Ingestion complete for ${filePath}`, summary);

    // Cleanup: remove the processed ZIP from the watched folder
    fs.unlinkSync(tmpZipPath);
    await bucket.file(filePath).delete().catch((e) =>
      logger.warn("Could not delete processed ZIP", e.message)
    );
  }
);

// =========================================================================
// SERVER-SIDE XP DAY-BOUNDARY ENFORCEMENT (production_plan.md §4.9)
// =========================================================================
// Deploy: firebase deploy --only functions:awardXpServer
//
// lib/repositories/xp_repository.dart's own file comment has flagged this
// exact gap since it was written: "the daily-cap 'is this a new day yet'
// check compares against the device's clock (DateTime.now()), not a
// server-anchored value... a motivated user changing their device clock
// could manipulate the reset timing." A Cloud Function's `Date.now()`
// reads THIS SERVER's clock, not the caller's phone -- it cannot be
// spoofed by changing a device's date/time settings the way the client
// path can.
//
// Scope of what this closes vs. what it doesn't (stated plainly, not
// implied): this enforces the DAY BOUNDARY / DAILY CAPS server-side.
// It does NOT yet re-derive `rawAmount` from first principles (re-reading
// the actual quiz question/points/difficulty and recomputing via the
// exact core/xp_rules.dart formula) -- the caller still supplies the
// already-computed amount, same trust level the client-side path has
// today for the AMOUNT itself. Full server-side recomputation of every
// XP formula (§4.2 quiz, §4.5 magazine) is real further work, not
// something to silently claim is covered by this function.
//
// NOT YET WIRED to any Flutter call site -- XpRepository.awardXp() is
// still what every screen calls today, and it still works correctly
// (with its own client-side transaction closing the read-then-write
// race, just not the device-clock gap). Deploying this function alone
// changes nothing until the client is switched over to call it via
// `cloud_functions` (already a pubspec dependency) instead of writing to
// Firestore directly -- a real, mechanical, lower-risk follow-up once
// this is deployed and confirmed working, deliberately not attempted
// blind in the same pass as writing it.

const XP_SOURCE_BASE_XP = {
  mcq: 15, structural: 30, ac: 55,
  paperUnlock: 0, magazineRead: 2, testCompletion: 0,
  streakDaily: 0, streakMilestone: 0,
  clubQuestion: 10, clubAnswer: 10, clubBestAnswer: 25,
};
const QUIZ_SOURCES = new Set(["mcq", "structural", "ac", "testCompletion"]);
const MAGAZINE_SOURCES = new Set(["magazineRead"]);

const XP_DAILY_CAP = 200;
const QUIZ_DAILY_CAP_BY_TIER = { juniorSecondary: 120, seniorSecondary: 160, advanced: 200 };
const QUIZ_OVERALL_DAILY_CAP = 280;
const MAGAZINE_DAILY_CAP = 100;

// Mirrors core/xp_rules.dart's academicTierFor() exactly -- keep the two
// in sync by hand if either changes; there's no code-sharing between the
// Dart app and this Functions runtime.
function academicTierFor(educationLevel) {
  switch (educationLevel) {
    case "Form 1": case "Form 2": case "Form 3":
      return "juniorSecondary";
    case "Form 4": case "Form 5":
      return "seniorSecondary";
    case "Lower Sixth Arts": case "Lower Sixth Science":
    case "Upper Sixth Arts": case "Upper Sixth Science":
    case "University": case "Professional / Working Adult":
    case "Independent Learner": case "Other":
      return "advanced";
    default:
      return "juniorSecondary";
  }
}

function isSameDay(a, b) {
  return a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate();
}

exports.awardXpServer = onCall({ region: "us-east1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const callerUid = request.auth.uid;
  const { targetUserId, source, rawAmount, articleId, refId } = request.data || {};

  if (typeof targetUserId !== "string" || !targetUserId) {
    throw new HttpsError("invalid-argument", "targetUserId is required.");
  }
  // A user can only award XP to themselves through this path -- exactly
  // matching the client-side rule's own `request.auth.uid == uid` self-
  // only constraint. A future "admin grant" path would be a distinct,
  // explicitly-audited function, not a parameter on this one.
  if (targetUserId !== callerUid) {
    throw new HttpsError("permission-denied", "Can only award XP to your own account.");
  }
  if (!Object.prototype.hasOwnProperty.call(XP_SOURCE_BASE_XP, source)) {
    throw new HttpsError("invalid-argument", `Unknown XP source: ${source}`);
  }
  const amount = Math.trunc(Number(rawAmount));
  if (!Number.isFinite(amount) || amount <= 0) {
    return { awarded: 0 };
  }

  const db = admin.firestore();
  const userRef = db.collection("users").doc(targetUserId);

  const awarded = await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) throw new HttpsError("not-found", "User not found.");
    const data = snap.data();
    const now = new Date(); // this function's OWN server clock -- not the caller's

    const storedDate = data.xpEarnedTodayDate ? data.xpEarnedTodayDate.toDate() : null;
    const isNewDay = !storedDate || !isSameDay(storedDate, now);
    const earnedToday = isNewDay ? 0 : Number(data.xpEarnedToday || 0);
    let room = XP_DAILY_CAP - earnedToday;

    const isQuiz = QUIZ_SOURCES.has(source);
    const isMagazine = MAGAZINE_SOURCES.has(source);
    let categoryField = null, dateField = null, categoryEarnedToday = 0;
    if (isQuiz) {
      categoryField = "quizXpEarnedToday"; dateField = "quizXpEarnedTodayDate";
      const tier = academicTierFor(data.educationLevel || "");
      const capForLevel = Math.min(QUIZ_DAILY_CAP_BY_TIER[tier], QUIZ_OVERALL_DAILY_CAP);
      const storedCatDate = data[dateField] ? data[dateField].toDate() : null;
      const catNewDay = !storedCatDate || !isSameDay(storedCatDate, now);
      categoryEarnedToday = catNewDay ? 0 : Number(data[categoryField] || 0);
      room = Math.min(room, capForLevel - categoryEarnedToday);
    } else if (isMagazine) {
      categoryField = "magazineXpEarnedToday"; dateField = "magazineXpEarnedTodayDate";
      const storedCatDate = data[dateField] ? data[dateField].toDate() : null;
      const catNewDay = !storedCatDate || !isSameDay(storedCatDate, now);
      categoryEarnedToday = catNewDay ? 0 : Number(data[categoryField] || 0);
      room = Math.min(room, MAGAZINE_DAILY_CAP - categoryEarnedToday);
    }

    const toAward = Math.max(0, Math.min(amount, room));
    if (toAward <= 0) return 0;

    const update = {
      xpBalance: admin.firestore.FieldValue.increment(toAward),
      lifetimeXP: admin.firestore.FieldValue.increment(toAward),
      xpEarnedToday: earnedToday + toAward,
      xpEarnedTodayDate: admin.firestore.Timestamp.fromDate(now),
    };
    if (categoryField) {
      update[categoryField] = categoryEarnedToday + toAward;
      update[dateField] = admin.firestore.Timestamp.fromDate(now);
    }
    tx.update(userRef, update);

    const txnRef = db.collection("xpTransactions").doc();
    tx.set(txnRef, {
      userId: targetUserId,
      type: "earn",
      source,
      amount: toAward,
      articleId: articleId || null,
      refId: refId || null,
      timestamp: admin.firestore.Timestamp.fromDate(now),
    });

    return toAward;
  });

  return { awarded };
});
