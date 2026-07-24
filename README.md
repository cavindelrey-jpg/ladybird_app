# Academia Ingest Pipeline — Cloud Function version

Fully automatic: an admin uploads a ZIP into Firebase Storage (either through
a future admin screen in the app, or manually via the Firebase Console for
now) and this Function does everything else — no local script, no PC needed.

## How it works

1. Admin uploads a ZIP of PDFs to Storage path: `admin_uploads/whatever.zip`
2. This triggers `ingestPastPapers` automatically
3. For each PDF inside:
   - Checks file hash against everything already in Firestore → skips duplicates
   - Extracts text (native first, Cloud Vision OCR fallback for scanned pages)
   - Sends text to Claude → gets back title/subject/level/year/docType/etc.
   - Generates a thumbnail from page 1
   - Uploads PDF + thumbnail to Storage, creates a Firestore doc in `papers`
4. Writes a report to the `ingestReports` collection (one doc per batch) with
   a live status (`processing` → `complete`) and per-file results — you can
   build a simple admin screen later that just listens to this collection
5. Deletes the processed ZIP from `admin_uploads/` when done

---

## One-time setup

### 1. Upgrade to Blaze plan
Firebase Console → your project → bottom-left "Upgrade" → Blaze (pay-as-you-go).
Required because this Function calls external APIs (Anthropic). Free tier
limits still apply on top of Blaze — you won't be charged at low volume.

### 2. Enable the Cloud Vision API
Google Cloud Console → APIs & Services → Library → search "Cloud Vision API" → Enable.
(Same project: academia-b1705)

### 3. Install Firebase CLI (if not already)
```powershell
npm install -g firebase-tools
firebase login
```

### 4. Place these files in your Flutter project
Put the `functions/` folder, `firebase.json`, and `.firebaserc` at the **root**
of `academia_cameroon` (as a sibling to `academia_app`, not inside it), e.g.:

```
C:\Users\12406\academia_cameroon\
  ├── academia_app\          (existing Flutter app)
  ├── firebase.json          (new)
  ├── .firebaserc             (new)
  └── functions\              (new)
      ├── index.js
      └── package.json
```

If you already have a `firebase.json`/`.firebaserc` from when you ran
`firebase deploy --only firestore:rules`, merge the `functions` section into
your existing `firebase.json` instead of overwriting it.

### 5. Install function dependencies
```powershell
cd C:\Users\12406\academia_cameroon\functions
npm install
```

### 6. Set your Anthropic API key as a secret
This keeps it out of your code entirely — Google Secret Manager stores it,
the Function reads it at runtime.
```powershell
firebase functions:secrets:set ANTHROPIC_API_KEY
```
Paste your key (starts `sk-ant-...`) when prompted.

### 7. Deploy
```powershell
cd C:\Users\12406\academia_cameroon
firebase deploy --only functions:ingestPastPapers
```

First deploy takes a few minutes. You'll get a confirmation once it's live.

---

## Testing it

**For now, before the in-app admin upload screen exists:**

1. Firebase Console → Storage → create folder `admin_uploads` if it doesn't exist
2. Upload a test ZIP (start with 3-5 papers, not 60, to verify everything works)
3. Watch it process: Firebase Console → Functions → `ingestPastPapers` → Logs
4. Check Firestore → `ingestReports` collection for the summary
5. Check Firestore → `papers` collection for the new documents
6. Check Storage → `papers/` and `thumbnails/` for the uploaded files

Once you confirm this works end-to-end with a small batch, scale up to your
full 40-60 paper ZIPs.

---

## Building the in-app upload screen (next step, when ready)

The Function is already wired to trigger on anything landing in
`admin_uploads/*.zip` — so the Flutter side just needs:
1. A superAdmin-only screen with a file picker restricted to `.zip`
2. Upload the picked file to `admin_uploads/{filename}.zip` via
   `FirebaseStorage.instance.ref(...)`
3. Listen to the `ingestReports` collection (ordered by `startedAt` desc,
   limit 1) with a `StreamBuilder` to show live progress and the final
   summary — no polling needed, Firestore pushes updates automatically

Tell me when you want this screen built and I'll write the Flutter side to
match your existing admin UI patterns (you already have `AdminAccountsPage`
and similar as reference).

---

## Cost awareness

Rough cost per 50-paper batch:
- Claude API: ~50 calls × ~2K input tokens × Sonnet pricing = a few cents
- Cloud Vision OCR: only runs on scanned pages, ~$1.50 per 1,000 pages
- Cloud Functions/Storage/Firestore: negligible at this volume, well within
  Blaze free tier

This is not going to generate a meaningful bill unless you're processing
thousands of scanned pages per month.

---

## Known limitations (same as the local script had)

- Only reads/OCRs the first few pages per PDF for classification
- Duplicate detection is exact file-hash only — a rescanned copy of the same
  paper won't be caught
- `makePublic()` is used for simplicity — if you'd rather lock file access
  behind your existing Firestore security rules, tell me and I'll switch to
  signed URLs instead
- Function timeout is set to 540s (9 min) — for very large batches
  (100+ scanned PDFs needing OCR), you may need to split into smaller ZIPs
  or I can restructure this as a queued/chunked job
