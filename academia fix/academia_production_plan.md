# Academia — Final 7-Step Production Plan

This is the final production roadmap for Academia.

The work should be executed in phases. The core Academia platform must be stabilized before the school-management edition is exposed or expanded. The objective is to finish the normal learning ecosystem first, then add AI, then trim the consumer-facing application, and finally expose the school-management system as a protected administrative layer.

## 1. Finish the Main Academia App

### Library

- [ ] Fix the online/offline permission problem.
- [ ] Verify that the Library works correctly when connected to Firebase/Firestore.
- [ ] Verify that offline caching continues to work correctly.
- [ ] Test downloading, viewing, caching, and retrieving content after reconnecting.
- [ ] Remove obsolete or placeholder Library logic.

### Clubs + Messaging

- [ ] Replace/fix the current Club UI.
- [ ] Replace/fix the current Messaging UI.
- [ ] Verify sending messages.
- [ ] Verify receiving messages.
- [ ] Verify displaying conversations correctly.
- [ ] Verify unread/read states.
- [ ] Verify Firebase/Firestore synchronization.

### Academia Magazine

- [ ] Implement the new Magazine UI.
- [ ] Implement proper dark-mode support.
- [ ] Verify the feed.
- [ ] Verify posts.
- [ ] Verify authors.
- [ ] Verify post engagement.
- [ ] Ensure Magazine activity can participate in personalization and recommendations.

### Homepage / Recommendations

- [ ] Fix the broken "Recommended for You" section.
- [ ] Keep the Universal Homepage unchanged for now.
- [ ] Build the recommendation infrastructure so it can eventually use:
  - [ ] Subjects.
  - [ ] Authors followed.
  - [ ] Content viewed.
  - [ ] Content searched.
  - [ ] Courses accessed.
  - [ ] Quizzes attempted.
  - [ ] Quizzes completed.
  - [ ] Recent activity.
  - [ ] Academic level.

The homepage's "Recommended for You" system must remain separate from contextual recommendations used elsewhere in the application.

## 2. Course Creation

Fix and fully test the complete course-creation pipeline:

> Create → Edit → Publish → Display → Access

- [ ] Create courses from the administration side.
- [ ] Edit existing courses.
- [ ] Publish courses.
- [ ] Verify published courses appear correctly to users.
- [ ] Verify users can access published courses.
- [ ] Verify course metadata.
- [ ] Verify course content.
- [ ] Verify permissions.
- [ ] Verify course availability across supported account types.
- [ ] Test the entire pipeline end-to-end using the real Firebase backend.

A course created from the administration side must be reliably visible and usable from the normal Academia application.

## 3. Academia Quiz Engine

The Quiz Engine should become a proper automated assessment system.

### Quiz Type 1 — Multiple Choice

Each MCQ should contain:

- [ ] Question.
- [ ] Multiple choices.
- [ ] Correct answer.
- [ ] Automatic marking.
- [ ] Score calculation.
- [ ] XP calculation.

Base XP:

> MCQ = 15 XP

### Quiz Type 2 — Short Answer / Structural

The student enters an answer.

The system should:

- [ ] Store the student's answer.
- [ ] Compare it against the expected answer.
- [ ] Use expected answers/key points.
- [ ] Evaluate automatically where possible.
- [ ] Assign a score.
- [ ] Award XP based on performance.

Base XP:

> Structural = 30 XP

### Quiz Type 3 — Essay

The Essay Quiz is deliberately different.

Students should not be required to type an enormous essay inside the application.

Instead:

1. Present the essay question.
2. Identify the 7–9 essential points that a strong answer should contain.
3. Ask the student to identify or enter the important points.
4. Evaluate how many essential points the student captured.
5. Calculate the score from those points.
6. Award XP according to performance.

The principle is:

> Essay Quiz = demonstrate that you understand the structure and essential content of the essay, not reproduce a two-page essay inside the application.

Base XP:

> Essay = 55 XP

The Essay Quiz should be highly gamified even though the actual writing interface remains simple.

### Automated Quiz Generation

After the core quiz engine works:

- [ ] Generate quizzes automatically from course content.
- [ ] Generate quizzes from notes and educational documents.
- [ ] Generate appropriate MCQs.
- [ ] Generate structural/short-answer questions.
- [ ] Generate essay questions and their essential-point structures.
- [ ] Associate generated quizzes with their source content.
- [ ] Allow administrative review before automatically generated quizzes become public where appropriate.

## 4. Academia XP Economy

The XP Economy is one of the core systems of Academia.

XP is earned through academic activity and spent primarily on past papers.

The XP system must be deterministic, abuse-resistant, and enforced server-side.

### 4.1 Daily Login XP

A user receives:

> +5 XP per calendar day.

The system must ensure that a user cannot repeatedly trigger the reward by logging in and out.

The daily login reward is awarded once per calendar day.

Future streak mechanics may be added separately.

### 4.2 Quiz XP

Each quiz has a Base XP value.

| Quiz Type | Base XP |
|---|---:|
| MCQ | 15 XP |
| Structural | 30 XP |
| Essay | 55 XP |

Academic level modifies the Base XP.

| Academic Level | Level Multiplier |
|---|---:|
| Junior Secondary | ×1.0 |
| Senior Secondary | ×1.6 |
| High School / Advanced | ×2.2 |

The standard XP formula is:

> Quiz XP = Base XP × Correct% × Level Multiplier

For example:

A Senior Secondary Structural quiz:

> 30 × 80% × 1.6 = 38.4 XP

The implementation must define how fractional XP is handled. Use a consistent server-side rounding rule.

### Minimum Completion Reward

A completed quiz must provide a minimum reward even when the student's score is very low.

Minimum completion reward:

> 25% of Base XP

The minimum reward applies to quiz completion, subject to the applicable attempt rules and daily caps.

The system must not allow the minimum completion reward to bypass XP cooldowns or daily limits.

### 4.3 Quiz Attempt Limits

The same quiz cannot be used as an unlimited XP farm.

For the same quiz:

> First eligible attempt → Full calculated XP

> Second attempt within 72 hours → 40% of calculated XP

> Third and later attempts within 72 hours → 0 XP

The 72-hour cooldown is attached to the individual quiz and learner.

The attempt system must therefore track at minimum:

- [ ] User ID.
- [ ] Quiz ID.
- [ ] Attempt number/window.
- [ ] Attempt timestamp.
- [ ] Score.
- [ ] XP calculated.
- [ ] XP actually awarded.

The attempt limit must be enforced server-side.

### 4.4 Daily Quiz XP Caps

Quiz XP has academic-level-specific daily caps.

| Academic Level | Daily Cap |
|---|---:|
| Junior Secondary | 120 XP |
| Senior Secondary | 160 XP |
| High School / Advanced | 200 XP |

There is also an overall quiz XP ceiling:

> Maximum total Quiz XP = 280 XP/day

The overall cap is authoritative even if a user's individual level calculation would otherwise permit more XP.

Therefore:

> Actual Quiz XP awarded = minimum of the applicable level allowance and the overall 280 XP/day ceiling.

The server must track daily awarded Quiz XP and reject or reduce additional XP once the applicable cap has been reached.

Daily caps must reset according to the system's defined calendar-day boundary.

### 4.5 Academia Magazine XP

Magazine XP is based on actual engagement rather than simply publishing.

The formula is:

> XP = (Views ÷ 50) + (Likes × 2) + (Comments × 5) + (Shares × 4)

Each post has a maximum reward of:

> 80 XP per post

Each user has a maximum Magazine XP allowance of:

> 100 XP per day

#### Engagement Calculation Timing

Magazine XP is not awarded immediately when the post is published.

The system calculates the XP:

> After the 24-hour engagement period.

This provides a defined measurement window and reduces opportunities for manipulation.

The system should therefore:

- [ ] Track views.
- [ ] Track likes.
- [ ] Track comments.
- [ ] Track shares.
- [ ] Calculate engagement after 24 hours.
- [ ] Apply the formula.
- [ ] Apply the 80 XP per-post maximum.
- [ ] Apply the user's 100 XP daily Magazine limit.
- [ ] Award the resulting XP server-side.

Anti-abuse protections should also prevent artificial engagement from becoming an unlimited XP source.

### 4.6 Past Paper XP Prices

A past paper is a past paper.

There is one fixed price for each learner level, regardless of:

- Question format.
- Number of questions.
- Content structure.
- Subject.
- Paper layout.

The fixed prices are:

| Learner Level | Past Paper Price |
|---|---:|
| Junior Secondary | 90 XP |
| Senior Secondary | 200 XP |
| High School / Advanced | 360 XP |

The price should be determined by the learner/academic level assigned to the past paper.

Do not create separate prices based on whether a paper contains MCQs, structural questions, essays, or other formats.

The objective is a predictable and understandable XP economy.

### 4.7 Past Paper Packs

A multi-paper pack costs:

> 1.8 × the fixed price of one paper at the same learner level.

Therefore:

| Learner Level | Single Paper | Multi-Paper Pack |
|---|---:|---:|
| Junior Secondary | 90 XP | 162 XP |
| Senior Secondary | 200 XP | 360 XP |
| High School / Advanced | 360 XP | 648 XP |

The pack price is based on the same fixed learner-level price and does not change according to the individual formats of the papers contained within it.

### 4.8 Core XP Rule

The fundamental economic loop is:

> Academic Activity → Earn XP → Spend XP → Unlock Past Papers

XP should primarily reward genuine academic engagement.

The system should make past papers feel earned without creating an excessive grind that discourages students from using Academia.

### 4.9 Server-Side Enforcement

This is a critical security requirement.

All of the following must be enforced server-side:

- [ ] XP calculations.
- [ ] XP multipliers.
- [ ] Correct percentage calculations.
- [ ] Minimum completion rewards.
- [ ] Quiz cooldowns.
- [ ] Quiz attempt limits.
- [ ] Daily quiz caps.
- [ ] Magazine XP calculations.
- [ ] Magazine engagement windows.
- [ ] Magazine per-post limits.
- [ ] Magazine daily limits.
- [ ] Past-paper prices.
- [ ] Past-paper pack prices.
- [ ] XP deductions.
- [ ] XP balances.
- [ ] XP transaction history.

The client application must never be trusted to determine how much XP a user receives or spends.

Every XP change should ideally produce an immutable transaction record containing:

- User ID.
- Transaction type.
- Source/activity ID.
- Amount.
- Previous balance.
- New balance.
- Timestamp.
- Relevant metadata.

This creates an auditable XP ledger.

## 5. Personalization

Personalization belongs primarily in the user's profile and settings.

Users should be able to specify:

- [ ] Favorite subjects.
- [ ] Authors they follow.
- [ ] Academic level/class.
- [ ] School timetable.
- [ ] Personal study timetable.

The backend should track relevant usage.

For example:

> Mathematics + Physics → follows Physics authors → frequently completes Physics quizzes

The recommendation system can use this information to surface:

- [ ] Relevant notes.
- [ ] Courses.
- [ ] Quizzes.
- [ ] Magazine posts.
- [ ] Authors.
- [ ] Eventually, past papers.

### Timetable System

Academia should have two distinct timetable concepts.

#### School Timetable

Example:

> Monday: Mathematics → Physics → English

#### Personal Study Timetable

Example:

> Monday evening: Mathematics revision

> Tuesday evening: Physics quiz

The notification engine can generate:

> Today's Study Program  
> Mathematics — 30 min  
> Physics Quiz — 15 min  
> Read: Mechanics — 20 min

This transforms Academia from merely a content library into a genuine study companion.

## 6. Academia AI

Academia AI should come after the core application works.

Do not build the AI on unstable infrastructure.

Before Academia AI begins, the following systems should be functional:

- [ ] Library.
- [ ] Courses.
- [ ] Quizzes.
- [ ] XP.
- [ ] Personalization.
- [ ] Recommendations.

Academia AI should connect to the existing educational ecosystem rather than becoming an isolated chatbot.

The AI should eventually operate within Academia's:

- [ ] Courses.
- [ ] Library.
- [ ] Notes.
- [ ] Quizzes.
- [ ] User academic profile.
- [ ] Study timetable.
- [ ] Recommendations.
- [ ] Magazine.
- [ ] Academic activity.

## 7. Trim → School Edition → Website

This is the final production sequence.

### 7A. Trim the Normal Academia App

Create a clean production copy of the main Academia application.

The normal Academia application contains:

- [ ] Academia Library.
- [ ] Academia Courses.
- [ ] Academia Quizzes.
- [ ] Academia Magazine.
- [ ] Messaging.
- [ ] Club/social functionality.
- [ ] Personalization.
- [ ] XP.
- [ ] Academia AI.

The normal application should not expose school-management infrastructure.

Remove from the ordinary user-facing interface:

- [ ] School dashboard.
- [ ] School administration.
- [ ] Teacher management.
- [ ] Attendance.
- [ ] Marks/grades management.
- [ ] Registrar functionality.
- [ ] School-specific administration.
- [ ] School login/interface.
- [ ] School-management navigation.

Do not necessarily delete the underlying school-management functionality.

The objective is to separate the products architecturally while preserving the school-management system for the School Edition.

### 7B. Replace App Banners with AI Content Recommendations

Remove the admin-controlled banner system from normal Academia.

- [ ] Admins should no longer configure ordinary application banners.
- [ ] Remove banner configuration from the normal administrative UI.
- [ ] Remove obsolete banner fields where they are no longer required.
- [ ] Remove obsolete banner backend logic where appropriate.
- [ ] Replace banners with automatically selected content recommendations.

Contextual recommendations should exist throughout Academia.

Examples:

> Library → recommends Library content.

> Courses → recommends relevant Courses.

> Magazine → recommends relevant Articles.

> Past Papers → recommends relevant Past Papers.

Recommendations should use signals such as:

- [ ] Views.
- [ ] Searches.
- [ ] Quiz attempts.
- [ ] Completed content.
- [ ] Subjects.
- [ ] Courses.
- [ ] Recent activity.
- [ ] Academic level.
- [ ] Followed authors.

The recommendation system must be context-aware.

Keep the Universal Homepage unchanged for now.

Keep the existing "Recommended for You" section on the homepage.

Do not merge the homepage recommendation system with contextual recommendations.

New and inactive users must still receive useful recommendations.

Implement fallback logic based on:

- [ ] Popular content.
- [ ] Recently published content.
- [ ] Academic level.
- [ ] Selected subjects.
- [ ] General relevance.

### 7C. Hidden School Management

The school-management system should remain intact but hidden from the normal Academia interface.

Create a separate protected route/page for:

- [ ] Attendance.
- [ ] Marks.
- [ ] Results.
- [ ] Student follow-up.
- [ ] Classes.
- [ ] Teachers.
- [ ] Student records.
- [ ] Performance tracking.
- [ ] Reports.
- [ ] School administration.

For example:

`/school-management`

The exact route can be changed during implementation.

The route must not be secured merely by hiding its URL.

It must require an authorized school-admin account and appropriate backend authorization.

## 8. Normal Academia Authentication

The normal Academia login should become significantly simpler.

The ordinary user authenticates as an individual.

The conceptual account structure should be:

> User → Account → Entitlements

Possible entitlement states include:

- Free.
- Premium.
- Gifted Premium.

Premium/Gifted should not become completely different permanent account types.

Instead, Premium should be an entitlement attached to the individual account.

A user could therefore have:

> Free account + Premium entitlement

or:

> Free account + Gifted Premium entitlement

depending on how Premium access was obtained.

## 9. Gifted Premium / Physical Sales

A Gifted Premium entitlement represents Premium access paid for by someone else.

Example:

> Parent → pays Academia physically → receives voucher/code → child redeems voucher → child's account receives Premium.

The child does not need to know anything about the underlying transaction.

The system should distinguish the transaction from the entitlement.

### Purchase

Store information such as:

- [ ] Purchase ID.
- [ ] Amount.
- [ ] Payment method.
- [ ] Package.
- [ ] Voucher/code generated.
- [ ] Date.
- [ ] Sales agent.
- [ ] Purchase source.
- [ ] Transaction status.

### User / Account

Store:

- [ ] User.
- [ ] Account.
- [ ] Premium status.
- [ ] Entitlement source.
- [ ] Entitlement start date.
- [ ] Entitlement expiration date where applicable.

### Gift / Voucher

Store:

- [ ] Voucher/code.
- [ ] Source purchase.
- [ ] Recipient account after redemption.
- [ ] Duration.
- [ ] Status.
- [ ] Creation date.
- [ ] Redemption date.
- [ ] Revocation/expiration state.

Possible voucher states:

> Unused → Redeemed → Active → Expired/Revoked

The architectural principle is:

> Gifted Premium is not necessarily a different account. It is a Premium entitlement whose source is another person's purchase.

This allows the same entitlement architecture to eventually support:

- Parents.
- Teachers.
- Schools.
- Sponsors.
- Organizations.
- Promotions.
- Scholarships.

## 10. Final Architecture Principle

The final system should conceptually separate three layers.

### Academia

The individual learning platform:

> Library + Courses + Quizzes + Magazine + Messaging + Clubs + Personalization + XP + AI

### School Management

The protected institutional administration layer:

> Students + Classes + Teachers + Attendance + Marks + Results + Reports + School Administration

### Entitlements

The access/monetization layer:

> Free + Premium + Gifted Premium + Future Sponsored/School/Promotional Access

These layers should interact where necessary but should not be unnecessarily coupled.

The normal student should experience Academia as a clean individual learning platform.

The school administrator should access School Management through authorized administrative interfaces.

The entitlement system should determine what additional capabilities a user can access without forcing the user into a completely different account architecture.

## 11. Production Testing Gate

Before declaring Academia production-ready:

- [ ] Firebase/Firestore integration verified.
- [ ] Authentication verified.
- [ ] Library online mode verified.
- [ ] Library offline mode verified.
- [ ] Course creation verified.
- [ ] Course publishing verified.
- [ ] Course access verified.
- [ ] Quiz Engine verified.
- [ ] Automatic scoring verified.
- [ ] XP calculations verified.
- [ ] XP anti-farming controls verified.
- [ ] XP server-side enforcement verified.
- [ ] XP transaction ledger verified.
- [ ] Daily login XP verified.
- [ ] Quiz XP caps verified.
- [ ] Quiz cooldowns verified.
- [ ] Magazine XP verified.
- [ ] Magazine 24-hour calculation verified.
- [ ] Past-paper XP prices verified.
- [ ] Past-paper pack pricing verified.
- [ ] Past-paper XP purchasing verified.
- [ ] Personalization verified.
- [ ] Recommendation engine verified.
- [ ] Contextual content recommendations verified.
- [ ] Magazine verified.
- [ ] Messaging verified.
- [ ] Clubs verified.
- [ ] AI integration verified.
- [ ] Premium entitlement verified.
- [ ] Gifted Premium verified.
- [ ] Voucher generation verified.
- [ ] Voucher redemption verified.
- [ ] Voucher expiration/revocation verified.
- [ ] School-management routes verified.
- [ ] School-admin authorization verified.
- [ ] Normal users cannot access school-management functions.
- [ ] Obsolete banner administration removed.
- [ ] Obsolete school navigation removed from normal Academia.
- [ ] Dark mode verified.
- [ ] Offline behavior verified.
- [ ] Error states verified.
- [ ] Loading states verified.
- [ ] Empty states verified.
- [ ] Security rules verified.
- [ ] Production build verified.

## 12. Academia Fix — Mockup Implementation Instructions

This production plan is located inside the `academia_fix` subfolder of the Academia project.

The `academia_fix` folder contains this Markdown specification and the three UI mockups that must be used as the visual references for the corresponding Academia features.

```text
academia_fix/
├── academia_production_plan.md
├── clubs_mockup.png
├── magazine_mockup.png
└── messaging_mockup.png
```

The mockups in this folder are not merely inspiration. They are the visual design references that the AI/developer must inspect and use when implementing the corresponding features.

### Clubs Mockup

Use:

`academia_fix/clubs_mockup.png`

The Clubs implementation must include both:

- [ ] Frontend/UI implementation based on the mockup.
- [ ] Backend implementation required to make the UI functional.

The AI should inspect the mockup before modifying the existing Clubs interface.

The implementation should reproduce the intended:

- [ ] Screen structure.
- [ ] Navigation.
- [ ] Search.
- [ ] Club discovery.
- [ ] Recommended clubs.
- [ ] Popular clubs.
- [ ] Club cards.
- [ ] Academic/community categorization.
- [ ] Relevant interactions.
- [ ] Loading states.
- [ ] Empty states.
- [ ] Error states.

The backend must support the functionality represented by the UI rather than leaving the mockup as a static screen.

### Academia Magazine Mockup

Use:

`academia_fix/magazine_mockup.png`

The Magazine implementation must include both:

- [ ] Frontend/UI implementation based on the mockup.
- [ ] Backend implementation required to make the UI functional.

The AI should inspect the mockup before modifying the existing Magazine interface.

The implementation should reproduce the intended:

- [ ] Feed structure.
- [ ] Post cards.
- [ ] Authors.
- [ ] Post content.
- [ ] Engagement.
- [ ] Navigation.
- [ ] Relevant filtering/discovery.
- [ ] Dark mode.
- [ ] Loading states.
- [ ] Empty states.
- [ ] Error states.

The backend must support:

- [ ] Posts.
- [ ] Authors.
- [ ] Views.
- [ ] Likes.
- [ ] Comments.
- [ ] Shares.
- [ ] Engagement tracking.
- [ ] Magazine XP calculation.
- [ ] 24-hour engagement calculation.
- [ ] Recommendation signals.

### Messaging Mockup

Use:

`academia_fix/messaging_mockup.png`

The Messaging implementation must include both:

- [ ] Frontend/UI implementation based on the mockup.
- [ ] Backend implementation required to make the UI functional.

The AI should inspect the mockup before modifying the existing Messaging interface.

The implementation should reproduce the intended:

- [ ] Conversation list.
- [ ] Search.
- [ ] User avatars.
- [ ] Student/teacher/user identification where applicable.
- [ ] Message screen.
- [ ] Message composition.
- [ ] Sending.
- [ ] Receiving.
- [ ] Read/unread states.
- [ ] Conversation updates.
- [ ] Loading states.
- [ ] Empty states.
- [ ] Error states.

The backend must support reliable real-time messaging, message persistence, conversation retrieval, and appropriate Firebase/Firestore security rules.

### Mockup Implementation Rule

Before implementing Clubs, Magazine, or Messaging, the AI must:

1. Locate the `academia_fix` folder.
2. Locate this Markdown file.
3. Locate all three mockup images.
4. Inspect the relevant mockup.
5. Inspect the existing implementation.
6. Compare the existing implementation against the mockup.
7. Identify what must be changed in the UI.
8. Identify what backend functionality is required to support the new UI.
9. Implement the frontend and backend together.
10. Test the complete feature.
11. Verify that the implementation corresponds to the mockup.
12. Remove obsolete UI/backend logic where appropriate.

Do not implement the mockups as isolated visual screens.

The objective is:

> Mockup → UI architecture → Backend architecture → Functional feature → Testing → Production implementation

The mockup is therefore the design reference, while the existing application architecture and this production plan determine how the feature should actually be implemented.

### Important

Do not replace functional backend systems merely for the sake of changing the UI.

Where the existing backend is sound, preserve and adapt it.

Where the existing backend is incomplete, broken, obsolete, or incompatible with the new mockup, fix or replace it.

The final result must be a fully functional production feature, not a visual imitation of the mockup.

This same rule applies to all three:

> Clubs + Magazine + Messaging = UI redesign + backend implementation/fix + integration + testing

The three mockups inside `academia_fix` are the authoritative visual references for these features.

## 13. Final AI Development Workflow

The AI should not simply modify files randomly.

The production workflow should be:

> Inspect → Plan → Implement → Test → Debug → Verify → Clean → Git Add → Git Commit → Git Push

For each phase, the AI should:

1. Inspect the existing implementation before changing it.
2. Identify relevant files, architecture, models, services, repositories, Firebase configuration, and UI.
3. Determine dependencies and potential regressions.
4. Make the required implementation changes.
5. Run relevant tests and analysis.
6. Build the application where appropriate.
7. Fix errors discovered during testing.
8. Re-run validation.
9. Review the final diff.
10. Remove obsolete code created by the old implementation.
11. Confirm unrelated functionality has not been broken.
12. Stage the completed work.
13. Commit the completed phase with a meaningful commit message.
14. Push the commit to the configured GitHub repository.

The AI must not consider a task complete merely because the code has been edited.

A task is complete only when:

> Implementation → Validation → Clean-up → Git Commit → GitHub Push

has succeeded.

### Final Git Operations

At the end of the production workflow, the AI should execute the equivalent of:

```bash
git status
git add .
git commit -m "Complete Academia production implementation"
git push
```

Before committing, the AI must verify the diff and ensure that secrets, credentials, API keys, generated artifacts, local configuration, and unrelated files are not being committed.

If the repository uses a different branch or remote workflow, the AI should inspect the repository configuration and push to the correct configured branch rather than assuming `main`.

The final state of every completed production phase should therefore be:

> Code implemented → Tests passed → Build verified → Repository cleaned → Changes committed → Changes pushed to GitHub.

## Final Production Sequence

```text
1. Main Academia App
        ↓
2. Course Creation
        ↓
3. Quiz Engine
        ↓
4. XP Economy
        ↓
5. Personalization + Recommendations
        ↓
6. Academia AI
        ↓
7. Trim Normal Academia
        ↓
8. Replace App Banners with Contextual AI Recommendations
        ↓
9. Preserve + Hide School Management
        ↓
10. Simplify Normal Academia Login
        ↓
11. Implement Premium Entitlements
        ↓
12. Implement Gifted Premium / Voucher System
        ↓
13. Production Testing
        ↓
14. Clean Repository
        ↓
15. Git Add
        ↓
16. Git Commit
        ↓
17. Git Push
        ↓
18. Academia Production Repository on GitHub
```

The core principle is:

> Build the learning platform first. Stabilize the infrastructure second. Add intelligence third. Separate the consumer and institutional layers fourth. Finalize monetization and deployment fifth.

The production process does not end when the AI finishes writing code.

It ends when the verified implementation has been committed and successfully pushed to GitHub.
