# Academia Content Compiler — Autonomous Publishing Process

This document is written so an AI agent with local file + terminal access
(e.g. Claude Code) can run the entire pipeline unattended: **write content →
compile → validate → publish → verify it appears in the app.**

---

## 0. Prerequisites (check before starting)

1. `node --version` returns something (Node.js installed).
2. `academia_compiler/compile-course.js` exists (the compiler script).
3. `academia_compiler/node_modules/markdown-it` and `gray-matter` exist
   (run `npm install markdown-it gray-matter` if not).
4. For the publish step only: a Firebase service account JSON key exists
   locally (e.g. `serviceAccountKey.json`) and `firebase-admin` is
   installed (`npm install firebase-admin`). If this key is missing,
   STOP after Step 3 (compile + validate) and ask the human for it —
   never invent or request it be pasted into chat/logs.

---

## Step 1 — Write the source Markdown

Every course is one `.md` file. Structure:

```markdown
---
title: <internal reference title, not shown in app>
category: <e.g. Sciences, Social Studies>
subject: <e.g. Mathematics, Economics, Computer Science>
level: <e.g. GCE Advanced Level>
topic: <the specific curriculum topic — groups lessons together>
difficulty: <Beginner | Intermediate | Advanced>
creatorId: ai-import
creatorName: <attribution shown in app>
tags: [tag1, tag2]
---

## Lesson Title One

Body text. **Bold** and *italic* work. Bullet lists:

- point one
- point two

![Optional caption](https://example.com/image.jpg)

[IMAGE: description of an image that should go here if none exists yet]

### A subheading inside this same lesson

More content. Subheadings (###) stay INSIDE the lesson above them —
they do not create a new lesson.

## Lesson Title Two

A new "## " heading starts a brand-new lesson (separate document),
placed right after the previous one in the same topic sequence.
```

**Rules that matter:**
- `category`/`subject`/`level`/`topic` must match existing strings
  *exactly* (case, spacing) if this content should join an existing
  curriculum branch instead of creating a new one. Check the app or an
  existing Firestore doc before writing these fields.
- One `##` = one Firestore document = one "page" in the app.
- `###` and deeper = subheadings inside that page, not new pages.
- `[IMAGE: ...]` is a flag for a human/future image-gen step, not a
  real image — use it sparingly and only where it adds real value.

---

## Step 2 — Compile (dry run first, always)

```bash
node compile-course.js <file>.md
```

Check the terminal output and `output/*.json`:
- Lesson count and titles look right.
- `bodyDelta` field is non-empty valid JSON for each lesson.
- `manifest.json` — note any flagged image placeholders.

**Do not proceed to Step 3 if the dry run errors or produces zero
lessons.** Fix the Markdown and re-run.

---

## Step 3 — Validate before publishing

Quick checklist an agent can verify programmatically from the compiled
JSON in `output/`:
- [ ] Every doc has a non-empty `title`.
- [ ] Every doc has `category`, `subject`, `level`, `topic` set (unless
      intentionally omitted — those show only in the flat feed, not the
      browse tree).
- [ ] `order` values are ascending and unique within the file.
- [ ] `bodyDelta` parses as valid JSON (`JSON.parse` should not throw).
- [ ] No unresolved `__PENDING_UPLOAD__` markers remain unexplained —
      confirm each corresponds to a real local image file that exists
      on disk (check `manifest.json` → `imagesToUpload`).

---

## Step 4 — Publish

```bash
node compile-course.js <file>.md --write \
  --serviceAccount ./serviceAccountKey.json \
  --bucket <your-project>.appspot.com
```

This uploads any local images, then batch-writes all lessons in the
file to the `public_courses` Firestore collection with
`published: true` and a real `createdAt` timestamp.

---

## Step 5 — Verify it will actually show in the app

1. Confirm in Firebase Console → Firestore → `public_courses` that the
   new docs exist with `published: true`.
2. If this is the **first** course under a new
   `category/subject/level/topic` combination, the app's curriculum
   queries (`topicSequence`, `watchByCategory`) may need a Firestore
   composite index. Open the app (or run its queries) once — Firestore
   will log a console error containing a direct "create index" link if
   one is missing. Click it, wait ~1–2 minutes for the index to build.
3. Restart/hot-restart the Flutter app and check:
   - The "Latest" feed (needs only `published: true`).
   - Browse → Category → Subject → Level → Topic (needs exact string
     match + the index above).

---

## Step 6 — Report back

Summarize for the human: how many lessons were compiled, how many
published, any image placeholders still needing real images, and the
exact category/subject/level/topic path to find each course in the app.
