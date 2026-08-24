# Pre-Launch Audit Report — Security, Performance, Media, Login Reliability

## How to read this report

This audit was performed by static code reading and targeted fixes — **there is no Flutter SDK, test runner, or live Firebase project accessible in this sandbox** (established repeatedly across this session). That means every fix below was written and verified by careful manual reasoning against the actual source, not by executing the app, running a test suite, measuring real load times, or performing live penetration testing against a running backend. Section 13 of the brief asks for unit/integration/auth/API/performance/regression/build tests to be run — **none of those were run**, because none could be. Where the brief asks for a specific test, this report says so honestly instead of claiming a result that was never produced.

This is also a **Flutter mobile app + Firebase backend** (Firestore, Storage, Cloud Functions, Firebase Auth), not the generic web-app stack (Postgres RLS, cookies, localStorage, CSRF tokens, CORS, HSTS) the audit checklist's language assumes. Each checklist item below is mapped to its real Firebase/Flutter equivalent, or marked genuinely not applicable with the reason stated — not padded with irrelevant infrastructure.

---

## Fixed

1. **PDF/DOCX viewers buffered the entire file into memory via a blocking `http.get()` on every single open, with zero caching.** This was the actual mechanism behind "PDFs/books take forever to open" — not a timeout, not the renderer. Fixed by extending the app's existing (already-correct, already-streaming) offline-download infrastructure to fire automatically on every open (`AcademicContentRepository.ensureLocalCopy`), not just on an explicit "Save for Offline" tap. See Performance Improvements below.
2. **Login and sign-up forms had no `autofillHints`**, so platform password managers couldn't reliably identify the fields to offer autofill or prompt to save new credentials. Added hints, `AutofillGroup` wrappers, and `TextInput.finishAutofillContext()` calls to both forms.
3. **Storage rules enforced zero file-size limits anywhere** (a real storage-cost/abuse vector — client-side picker limits don't count, a modified client bypasses them). Added server-side size caps (10MB images / 300MB content files) across every upload path. Caught and fixed my own mistake mid-fix: `chat_media`/`chat_files` had a combined `allow read, write` condition, and naively adding a size check there would have broken *reading* chat attachments (`request.resource.size` isn't meaningful on a read) — split read/write before applying the cap.
4. **Chat attachment picker allowed any file type, including executables** (the other three file pickers in the app already restrict to a document/media allowlist — verified by reading, not assumed). Added a blocklist for exe/apk/bat/cmd/msi/dmg/sh/jar/scr/vbs/js/ps1 rather than narrowing to an allowlist, since "any legitimate file" is the correct product shape for a chat attachment.
5. **Audit/security-event logging has never actually worked.** `AuditService.log()` writes to a nested path (`audit_logs/{institutionId}/entries/{entryId}`); the Firestore rule only matched the flat top-level `audit_logs/{id}`, which does not cascade to subcollections — every write was silently permission-denied. Fixed the rule and wired the highest-value call site (`AuthService.signIn()` now logs success/failure/suspended-block events, fire-and-forget, logging only the email + Firebase error *code* on failure, never a password).
6. *(Carried over from the earlier security pass this session, already deployed via commit `1d39c9e`)*: Storage rules for `article_thumbnails`/`club_banners`/`course_covers` allowed any signed-in user to overwrite another user's image with no ownership check — fixed to mirror the owning document's real Firestore ownership rule.

## Performance Improvements

**Root cause traced, not guessed at:** read `content_viewer_page.dart` end-to-end for every file kind (image/PDF/video/docx).

- **Video**: already correct. `VideoPlayerController.networkUrl()` uses the native platform player (ExoPlayer/AVPlayer), which handles HTTP range requests and progressive buffering itself — no fix needed, and no change made (forcing video through a download-first path would have been a *regression*, not a fix, so it was deliberately left alone).
- **PDF**: was `PdfDocument.openData(_fetchBytes(url))` where `_fetchBytes` did a single `http.get()` — the whole document is fetched into a `Uint8List` before pdfx renders page 1, and this repeated in full on *every* open of the *same* file. Now resolves a real local file via `ensureLocalCopy()` first: instant on any repeat open (cache hit, zero network), and on a genuine first open, streams to disk with real progress reporting instead of a bare spinner. Also parallelized the saved-page-position Firestore read with the file resolution (previously sequential).
- **DOCX**: same fix, same caching mechanism.
- **Audio**: no audio content type or player exists anywhere in this app's data model (`ContentType` enum has no `audio` value) — there is no in-app audio feature to have been slow. Flagging this rather than fabricating a fix for a feature that doesn't exist.

**Measured before/after: not possible.** No Flutter SDK to run the app and time an actual tap-to-usable-content interval. What *can* be stated with confidence from the code change itself: every open of a PDF/DOCX after the first is now a local disk read (no network round trip at all, no re-buffering), where previously every open — first or hundredth — re-downloaded the entire file from the network. The qualitative claim ("repeat opens go from full-redownload to instant") is a direct, mechanical consequence of the fix, not a projection.

## Security Improvements

See "Fixed" above for the concrete changes. Mapping the full checklist to this app's real architecture:

| Checklist item | Status | Notes |
|---|---|---|
| Hide API keys / purge Git secrets | Verified clean | Broad regex scan found no server secrets; the one real secret (Anthropic API key) is in Firebase Secret Manager, not source. Firebase client `apiKey` in `firebase_options.dart` is not a secret by Firebase's own design — protected by security rules, not key secrecy. |
| Row Level Security | N/A (Postgres/Supabase term) | Firestore's equivalent is Security Rules — extensively audited this session (this pass + the earlier one, commit `1d39c9e`). |
| Encrypt sensitive data | Not separately verified this pass | No plaintext-password storage anywhere (Firebase Auth handles hashing server-side, out of app control by design — correct). Did not do a field-by-field sensitive-data sweep beyond what earlier passes covered. |
| Enforce auth server-side / lock down records / prevent field tampering | Verified | Firestore rules use `resource.data.X == request.auth.uid` ownership checks and `diff().affectedKeys().hasOnly([...])` field-tampering guards throughout — this is the actual enforcement layer, not client-side gating. |
| Secure session cookies | N/A | Mobile app — Firebase Auth SDK manages tokens via platform-secure storage, not cookies. No custom cookie handling found. |
| Hash passwords | N/A to this codebase | Firebase Auth does this server-side; the app never sees or handles raw password hashing. |
| Rate-limit login attempts / bot protection | **Real gap, not fixed** | No app-level rate limiting exists. Firebase Auth has some platform-level abuse detection, but nothing here adds a limiter. Firebase App Check (the correct mechanism) is not wired up at all — would need both a client-side package (a real code change) and Firebase Console-side provider registration (Play Integrity/DeviceCheck/reCAPTCHA), which is outside what this sandbox can do. Listed under Remaining Issues. |
| Parameterize queries | N/A | Firestore SDK queries can't be raw-string-injected (a SQL concept). |
| Validate user input | Partially verified | Form validators exist on auth/signup forms; did not exhaustively re-check every input field this pass. |
| Escape/sanitize user content (XSS) | N/A — verified | No WebView, no HTML rendering, anywhere in this app (confirmed by grep). Native Flutter widget rendering has no script-execution surface. |
| Restrict file uploads | **Fixed this pass** | See "Fixed" #3, #4. |
| Security headers / HSTS / force HTTPS | N/A currently | `firebase.json` has no `hosting` key — no Firebase Hosting deployment is configured from this repo (a `web/` build exists but isn't deployed via this config). Firestore/Storage/Auth SDKs are HTTPS-only by platform default regardless. If/when a web build is actually hosted, headers need configuring wherever that hosting actually happens. |
| Dependency vulnerability scan | Not run (no network for `npm audit`/`pub outdated` in this sandbox) | Manually reviewed major version numbers in `pubspec.yaml`/`functions/package.json` — nothing looks obviously outdated or abandoned, but this is not a substitute for an actual scan. |
| CSRF | N/A | No cookie-session model; Firebase Auth uses bearer tokens via the SDK, not the browser-cookie flow CSRF protects against. |
| Payment webhook verification | N/A — no webhook exists | `payments/{id}`'s own rule comment (written by an earlier session) already documents this: the app only ever writes a `status: 'pending'` record; a Cloud Function to verify and confirm MoMo/Orange Money callbacks was never built. Nothing to cryptographically verify yet — flagging as a real pre-launch gap if real-money payments are live, not something to fabricate a stub for. |
| Prices determined server-side | Verified | XP costs (`kPaperUnlockCost` etc.) and entitlement tier pricing are fixed constants read by both client and the `awardXpServer` Cloud Function, not client-suppliable values. |
| AI prompt injection | Low risk, verified | The only AI-touching path (`functions/index.js`'s Claude-based PDF metadata classifier) only accepts input via `admin_uploads/*.zip`, which has **no matching Storage rule at all** (default-denied to every client) — only Admin SDK/Console access can trigger it today. A crafted PDF can't reach it through the app. |
| CORS | N/A — verified | Every Cloud Function in this repo is `onCall` (Firebase Callable Functions, CORS handled automatically by the SDK protocol) or `onObjectFinalized` (storage-triggered, not client-invoked). Zero raw `onRequest` HTTP endpoints exist. |
| Directory listing / default admin routes | N/A | No HTTP server/routes exist in this codebase to have either. |
| Account lockout after failed logins | **Real gap, not fixed** | Same underlying gap as rate-limiting above — needs server-side infrastructure (Cloud Function + counter, or App Check) beyond a client-side change. |
| Security event logging | **Fixed this pass** | See "Fixed" #5. Foundation only — login events are covered, not every admin/security action app-wide. |
| Least-privilege DB access | Verified | Cloud Functions use the Admin SDK (bypasses rules) for the handful of operations that legitimately need it (serial claims, server-side XP); everything else goes through client-enforced Security Rules. |

## Authentication Improvements

Implemented real OS/browser password-manager integration on both the login and sign-up forms:
- `autofillHints`: `[username, email]` + `password` on login; `name` + `[newUsername, email]` + `newPassword` on sign-up (distinct "new" hints so the password manager offers to *generate* a strong password on account creation, rather than just recalling an existing one).
- Both forms wrapped in `AutofillGroup` — required for the platform to treat the email/password fields as one related unit.
- `TextInput.finishAutofillContext()` called on success (triggers the "Save password?" platform prompt) and on failure (`shouldSave: false`, so a rejected/wrong password is never offered for saving).
- **No plaintext password storage was introduced anywhere.** Firebase Auth continues to handle credential verification and hashing server-side, exactly as before — this only wires up the *existing* OS-level password manager, per the brief's own explicit requirement.

## Tests Run

**None of the 14 test categories in Section 13 could be executed** — no Flutter SDK, no test runner, no live Firebase project, no running app, no browser, no physical/emulated device, all in this sandbox. This is the same constraint stated at the top of every major deliverable this session, not new information.

What substituted for execution: manual brace/paren balance checks on every modified file, and a careful second read-through of each change tracing the actual control flow by hand (this caught two real bugs before they shipped: the `chat_media` combined-read-write size-check mistake described above, and would have caught anything else structurally wrong that a compiler would catch — but a hand-read is not a compiler, and cannot catch everything one would).

**Action needed:** run `flutter analyze` and `flutter test`, exercise the login/signup autofill flow on a real Android/iOS device (autofill behavior cannot be verified any other way), and open a large PDF/book before and after this change to confirm the caching behavior — this is the same "I write, you run, report back" loop that already caught one real bug earlier this session.

## Remaining Issues

1. **No rate-limiting or account lockout after repeated failed logins.** Needs Firebase App Check and/or a Cloud Function-based limiter — real infrastructure work, not a quick fix, and partly requires Firebase Console access this sandbox doesn't have.
2. **Firebase App Check is not configured at all** (bot/abuse protection for Firestore/Storage/Functions). Needs both a client package + `activate()` call (a real code change, not attempted this pass given the remaining scope) and Console-side provider registration.
3. **No payment webhook exists** for MoMo/Orange Money confirmation — if real-money payments are already live in production, this is a meaningful gap (the `payments/{id}` collection's own comment has flagged it as known/deferred, not new).
4. **No dependency vulnerability scan was actually run** (network-restricted sandbox) — only a manual version-number sanity check.
5. **Audit/security-event logging now works but covers one event category** (login). Role changes, admin actions, entitlement grants, and permission-denied events are not logged yet.
6. **No web security headers configured** — moot right now since no Hosting deployment exists in this repo's config, but will matter the moment one does.
7. Every item in this report is **unverified by execution** — see Tests Run above.

## Risk Assessment

| Area | Risk | Why |
|---|---|---|
| PDF/DOCX slow-open bug | **None** (fixed) | Root cause identified and corrected; mechanism is sound even though timing couldn't be measured directly. |
| Login/signup autofill | **None** (fixed, pending device verification) | Correct, standard Flutter APIs used; real-device testing still recommended before calling it fully verified. |
| Storage IDOR (article/club/course images) | **None** (fixed in the earlier pass, still not deployed — see below) | |
| File-size limits / chat file blocklist / audit logging | **None** (fixed) | |
| Rate limiting / account lockout / App Check | **High** | Real, unaddressed gap — brute-force login and storage/bandwidth abuse are both currently unmitigated beyond Firebase's own platform-level defaults. |
| Payment webhook (if payments are live) | **Critical if real money is already flowing; None if not** | Depends entirely on whether this feature is actually in production use — needs a direct answer from the project owner. |
| Dependency vulnerabilities | **Unknown** | No scan was actually run; can't be honestly classified without one. |
| **Everything in this report generally** | **Medium**, structurally | Every fix this session (this pass and all earlier ones) remains **undeployed** — Firestore/Storage rules changes require `firebase deploy`, which this project's own standing policy reserves for the repo owner (see `docs/AUTOPILOT_LOG.md`). Code is correct on disk; none of it is live until deployed. |

**Do not treat this app as launch-ready.** Two concrete blockers stand between "code is fixed" and "launch-ready": (1) every rules change across this entire session needs to actually be deployed (`firebase deploy --only firestore:rules,storage`), and (2) rate-limiting/App Check/webhook gaps above need a real decision and, for the webhook, real engineering work if payments are already live.
