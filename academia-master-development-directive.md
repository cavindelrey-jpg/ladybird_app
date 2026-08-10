# ACADEMIA — MASTER DEVELOPMENT DIRECTIVE

## 1. Core Architecture — Establish This First

Academia is the main product.

There should be one central Academia ecosystem, consisting of:

### 1.1 Academia Mobile App

- iOS
- Android
- Primary student-facing application
- Courses
- Library
- Academia Magazine
- Messaging
- Reminders
- AI/compiler-assisted content creation
- Other study tools

### 1.2 Academia Website

- One central website
- Fully developed, not merely a landing page
- Connected to the same Academia backend and content ecosystem
- Students should be able to move naturally between the website and mobile application
- Links inside the app that currently lead users toward Firebase/backend destinations must instead lead to the Academia website or the appropriate Academia application experience

Do not create two competing websites or two disconnected Academia platforms.

The architecture should feel like:

> Academia Website ↔ Academia Backend ↔ Academia Mobile App

The website and app are two interfaces into the same product.

---

## 2. School-Specific Products Come Later

Academia itself is the main product.

When Academia eventually signs a school, the school can receive a branded/specialized application built on the Academia infrastructure.

For example:

> Academia → School-specific deployment

A school application can have:

- Its own homepage
- School branding
- Timetable
- School announcements
- School-specific modules
- Student information
- School resources
- Academia Library
- Academia Courses
- Academia Magazine
- Other Academia services

The school experience can therefore be substantially different from the public Academia homepage while still using the same underlying infrastructure.

Do not allow this school-specific architecture to distract from finishing the core Academia application.

For this development phase, focus on Academia itself.

---

## 3. Dark Mode — Complete System-Wide Implementation

Dark mode is currently incomplete.

This must be treated as a system-level UI problem, not a page-by-page cosmetic change.

**Currently:**

- Some pages are dark.
- Some pages remain light.
- Some dark pages contain white patches.
- Some components do not inherit the dark theme.
- Some backgrounds, cards, dialogs, loaders, inputs, sheets, and other elements remain inconsistent.

### Required Outcome

Implement a complete, uniform dark-mode system across the entire application.

**Audit:**

- Every screen
- Every route
- Every modal
- Every bottom sheet
- Every dialog
- Every card
- Every form
- Every input
- Every button
- Every navigation component
- Every loading state
- Every empty state
- Every error state
- Every library component
- PDF/video/audio viewers
- Messaging
- Reminders
- Courses
- Magazine
- Search
- Settings
- Authentication
- Guest mode
- Any hidden/deep-linked screens

There should be no accidental white rectangles, white backgrounds, white containers, or mismatched components when dark mode is enabled.

Do not solve this by manually changing isolated screens.

Create/use a central theme system so that components inherit the correct colors automatically.

The objective is:

> "If the user activates dark mode, the entire Academia experience becomes dark."

---

## 4. Messaging — Production-Quality

Messaging must not feel like an experimental feature.

The target quality should be comparable to the basic usability users expect from:

- WhatsApp
- Telegram

The objective is not to clone their UI. The objective is to achieve the same level of speed, responsiveness, reliability, and usability.

**Messaging should be:**

- Fast
- Responsive
- Smooth
- Reliable
- Properly synchronized
- Visually clean
- Optimized for mobile
- Compatible with dark mode

**Pay particular attention to:**

- Message loading
- Sending speed
- Conversation loading
- Scrolling
- Keyboard behavior
- Read/unread state
- Timestamps
- Message states
- Empty conversations
- Error handling
- Offline/poor-network behavior
- Media handling
- Loading indicators

Avoid unnecessary network requests and expensive rebuilds.

Messaging should feel instantaneous.

---

## 5. In-App Content Opening

Academia is a study application, so opening educational content must be extremely fast.

The application needs a good experience for opening:

- PDFs
- Videos
- Audio
- Other supported educational content

The principle is:

> "Student taps content → content opens immediately and predictably."

Do not create unnecessary intermediate screens.

**Optimize:**

- File loading
- Caching
- Streaming
- Thumbnail loading
- PDF rendering
- Video initialization
- Audio initialization
- Loading states
- Error recovery

Where appropriate, cache content so repeatedly opened educational material does not have to behave as though it is being downloaded for the first time.

---

## 6. Compiler / Automatic Course Creation

There is already a compiler/content-generation mechanism visible under Reminders.

Investigate the existing implementation rather than rebuilding blindly.

The objective is to turn this into an actual automated content pipeline.

The system should eventually be capable of taking educational source material and automatically generating structured Academia courses.

Conceptually:

> Source material → Compiler → Structured Course → Academia Course

**The generated course should be able to contain things such as:**

- Course title
- Description
- Sections/modules
- Lessons
- Explanations
- Key concepts
- Examples
- Images where appropriate
- Questions/quizzes where appropriate
- Metadata
- Difficulty/level information

The compiler should not merely generate text. It should generate Academia-compatible structured content that can be stored and displayed by the existing course system.

**Before implementing anything new:**

1. Locate the existing compiler.
2. Understand its current input/output.
3. Identify why it currently exists under Reminders.
4. Determine what is reusable.
5. Connect it to the actual course/content architecture.
6. Automate the process.
7. Add validation so malformed AI-generated courses do not enter production.

---

## 7. Library — Highest Priority

**THIS IS THE MOST IMPORTANT PART OF THIS DIRECTIVE.**

The Library has been problematic for a long time.

Do not treat this as a minor UI bug.

The Library needs a proper architectural review.

**The current Library is affected by:**

- Broken/incomplete Firebase indexes
- Cloud Firestore permission problems
- Poor tagging architecture
- Upload-related problems
- Potential scalability problems
- Content retrieval issues

The Library must become operational and scalable.

---

## 8. Library Tag System — Rebuild It

The existing tag system is fundamentally wrong.

**Current problem**

Suppose the user uploads:

> GCE Papers

The system creates a tag such as:

> GCE Papers

and places it in the tag area at the top.

Then the user uploads another file. The system creates another tag. Then another.

Eventually:

> Tag 1 | Tag 2 | Tag 3 | Tag 4 | Tag 5 | ...

If the user uploads 1,000 files, the application could effectively produce 1,000 tags.

**This is unacceptable.**

The number of uploaded documents must not determine the number of visible navigation tags.

---

## 9. Replace the Tagging Model

Do not merely patch the existing implementation.

If necessary, destroy the current tagging architecture and replace it with a proper classification/filtering system.

The Library should distinguish between:

**A. Document/File**
The actual uploaded resource.
Example: `GCE 2024 Physics Paper 1.pdf`

**B. Categories**
A controlled classification.
Example: Physics, Mathematics, Biology, History

**C. Level/Class**
Example: Form 4, Form 5, Lower Sixth, Upper Sixth

**D. Examination/Type**
Example: GCE, Mock, Past Paper, Notes, Textbook, Assignment

**E. Optional User/Content Tags**
Tags can exist, but they should be deliberately assigned and reusable.

---

## 10. Tags Must Be Reusable

If the user uploads:

- GCE Physics 2022
- GCE Physics 2023
- GCE Physics 2024
- GCE Mathematics 2024
- GCE Biology 2024

the system should not create five unrelated navigation tags simply because five files were uploaded.

Instead, the metadata can produce something like:

- **Exam:** GCE
- **Subject:** Physics / Mathematics / Biology
- **Type:** Past Papers

The user can then filter/search the Library.

---

## 11. Do Not Put 1,000 Tags at the Top of the Screen

The top of the Library should not become a database dump.

Use a proper scalable navigation/filtering model.

**Possible structure:**

- Search
- Filter
  - Subject
  - Level
  - Type
  - Examination
  - Year
  - Category

Then show the content.

If there are commonly used categories, they can appear as concise chips.

But the interface must remain usable whether there are 20 files or 20,000 files.

---

## 12. Library Search and Filtering

The Library should be designed around the assumption that the content database will become very large.

**Users should be able to find content through:**

- Search
- Subject
- Level
- Type
- Year
- Examination
- Category
- Tags where appropriate

Search should search the appropriate metadata fields and document information.

Do not require users to scroll through an enormous list.

---

## 13. Firebase — Fix the Actual Backend

The Library is currently not operational because of Firebase problems.

**Specifically investigate:**

### Firestore Indexes

Errors such as:

> `failed-precondition: The query requires an index`

must be resolved by identifying the actual queries being executed and creating the required indexes.

Do not simply suppress the error.

### Firestore Permissions

Errors such as:

> `permission-denied`

must be traced to the actual Firestore security rules and authentication state.

**Determine:**

- Which operation is failing?
- Which user is performing it?
- Which document/collection is being accessed?
- What rule should permit/deny the operation?
- Whether the current security model matches the intended Academia architecture.

Do not make the entire database publicly writable just to make the error disappear.

Security rules must remain properly scoped.

---

## 14. Library Testing Requirement

After fixing the Library, test it with realistic volume.

Do not test only with three files.

**Test scenarios such as:**

- 10 files
- 100 files
- 1,000 files
- Multiple subjects
- Multiple levels
- Multiple years
- Duplicate metadata
- Duplicate tags
- Large PDFs
- Videos
- Audio
- Deleted content
- Updated content
- Search
- Filtering
- Opening content
- Permissions
- Empty library
- Failed uploads
- Interrupted uploads

The Library must remain usable as content grows.

---

## 15. Development Priority

Do not spend the next development cycle polishing random cosmetic details while the Library remains broken.

**Priority should be:**

### PRIORITY 1 — Library
- Fix Firestore indexes
- Fix permissions
- Rework tagging/classification
- Fix upload pipeline
- Fix retrieval
- Fix search/filtering
- Fix content opening
- Test scalability

### PRIORITY 2 — Dark Mode
Complete system-wide dark mode.

### PRIORITY 3 — Content Opening
Fast PDFs, videos, audio and other educational resources.

### PRIORITY 4 — Messaging
Bring messaging to production-quality reliability and responsiveness.

### PRIORITY 5 — Compiler
Connect the existing compiler to automated course creation.

### PRIORITY 6 — Website
Develop the complete Academia website and connect it properly to the Academia ecosystem.

---

## 16. Important Development Rule

Do not keep patching symptoms.

When a feature is architecturally wrong, replace the architecture.

**This particularly applies to:**

- Library tags
- Theme handling
- Firebase queries
- Content retrieval
- Course generation

The goal is not:

> "Make the current implementation stop showing an error."

The goal is:

> "Build the Academia architecture so that it continues working when Academia becomes large."

---

## 17. Final Product Vision

Academia should ultimately feel like a serious educational platform, not a collection of Firebase screens.

**The core experience is:**

```
Academia Website
       ↕
Academia Backend
       ↕
Academia Mobile App
```

**Inside Academia:**

| Component | Purpose |
|---|---|
| Library | Educational resources |
| Courses | Structured learning |
| Academia Magazine | Educational/cultural content |
| Messaging | Communication |
| Compiler | Automated educational-content production |
| Dark Mode | Consistent system-wide experience |
| Content Viewer | Fast PDFs, video and audio |

Every component should reinforce the same product.

The immediate objective is not to add endless features. It is to make the existing core stable, fast, scalable, coherent, and genuinely usable.

---

## NON-NEGOTIABLE

**THE LIBRARY MUST BE FIXED.**

- The tagging system must be redesigned.
- Firebase indexes and permissions must be fixed correctly.
- The Library must work with large quantities of content.
- No more one-tag-per-upload behavior.
- No more broken queries.
- No more permission errors.
- No more treating the Library as a secondary feature.

The Library is a core pillar of Academia and receives the highest priority in this development cycle.
