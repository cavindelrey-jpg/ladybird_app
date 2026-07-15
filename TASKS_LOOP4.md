# TASKS_LOOP4.md — Zero-intervention loop scope

Work through these four in order. Do not stop for input under any
circumstance — see the rules at the bottom.

## 1. Kill dead buttons
Audit the app for any button, icon, or tappable element whose onPressed/
onTap either does nothing, is missing entirely, or force-unwraps a
nullable value without a guard. For each one found:
- If it should navigate somewhere real, wire it.
- If it's genuinely not built yet, replace it with a disabled state or a
  honest "not available yet" response — never leave a silently-dead tap.
Known already-fixed tonight (don't redo): Top Writers "View All",
avatar taps across Home/Drawer/Messages/Courses/Library, Magazine and
Course Like/Bookmark/Share buttons. Look for OTHERS beyond these.

## 2. Enrich content creation (Magazine + Courses)
Both composers currently support: title, body via flutter_quill, single
cover image, category, publish/draft. Add, for both, using the same
repository/Result pattern already established:
- Tags (multi-select, in addition to the existing single category)
- Multiple images embedded inline in the body (flutter_quill already
  supports embeds — confirm the image-embed toolbar button is present
  and wired to actual upload, not just a stub)
- Draft auto-save (periodic save-as-draft while typing, not just on
  manual "Save Draft" tap)
Do NOT touch the Course data model to add Modules/Lessons/Quizzes —
that's out of scope for this loop, a separate future project.

## 3. Better chat rooms + link previews
Chat rooms (messaging feature) currently support text messages only.
Add:
- Link detection: when a message body contains a URL, detect it and
  render a real link-preview card below the message (title, description,
  image if available — fetch via an existing http client, cache the
  result so it's not refetched every rebuild).
- General chat polish: typing indicators if a clean way exists via
  existing Firestore structure, read receipts if the data model
  supports it, better message bubbles/spacing — but do not invent new
  Firestore collections without checking whether the existing
  MessagingRepository already supports what's needed.

## 4. In-app viewers
Confirm (don't rebuild if already working — verify first):
- Video files open and play in-app (chewie/video_player already in
  pubspec)
- PDF files open and render in-app (pdfx already in pubspec)
- Word documents (.docx) — currently NOT viewable in-app anywhere.
  Add a real in-app Word viewer or, if no reliable Flutter package
  exists for rendering .docx content faithfully, extract and display
  the text content at minimum (using the existing docx_parser.dart)
  rather than leaving no way to view them at all.

## Rules — read before starting
- Never stop and wait for input. If something needs a live device, a
  design decision, or credentials only the human has — skip it, write
  one line to REPORT.md (what it is, why it's blocked), and move to the
  next item immediately.
- After each of the 4 sections above, run `flutter analyze` and fix
  anything it flags before moving to the next section. Do not just
  reason statically that something works — the Quill localization bug
  earlier tonight was invisible to static reading and only showed up in
  a real compile/run. Prefer `flutter build apk --debug` as a final
  check after all 4 sections, not just analyze.
- Follow the existing repository pattern (Result<T>, Success/Failure)
  and existing UI conventions (C./Rad./AppText from theme/app_theme.dart)
  exactly — do not introduce a new pattern.
- Commit after each of the 4 sections completes and analyzes clean, not
  just once at the very end — four checkpoints, not one giant diff.
- When fully done, write a final summary to REPORT.md: what got built,
  what got skipped and why, and the final `flutter analyze` output.
