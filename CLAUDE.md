# Academia — Project Context for Claude Code

## What this is
Flutter/Firebase educational platform for Cameroonian students (GCE curriculum, FCFA pricing).
Two layers: school/institutional (multi-tenant, scoped by `schoolId`) and independent student layer.

## Stack & conventions (do not deviate without asking)
- Flutter + Firebase (Firestore, Auth, Storage, Analytics)
- Repository pattern: all repo methods return `Result<T>` (Success/Failure) — never throw raw exceptions up to UI
- Singleton repositories via `.instance`
- Provider for state management
- All Firestore writes/reads must be scoped by `schoolId` where applicable
- `AppRouter` uses `StreamBuilder` on `authStateChanges` for navigation — never add `pushReplacementNamed` dead calls
- Role gating via `hasMinRole()` across 6 tiers: guest, student, lecturer, departmentAdmin, schoolAdmin, superAdmin
- No fabricated/hardcoded data or fake stats — live Firestore data only. If a screen needs data that doesn't exist yet, flag it, don't fake it.

## Design system
- Colors: Navy `#0A1F44`, Gold `#C9A227`, Primary Blue `#1A56DB`, border `#E2E8F0`
- Fonts: `GoogleFonts.sora` (headings), `GoogleFonts.inter` (body)
- Card radius 14–16px
- Shared components: `ACard`, `EmptyState`, `ShimmerCard`, `ErrorView`, `GradientCard` — reuse these, don't create one-off variants

## Known infrastructure issue
Firebase CLI on this machine has historically had a broken install ("Pkg: Error reading from file"). If any task involves `firebase deploy`, check the CLI actually runs first — don't assume it works.

## Rules for this loop specifically
- Never run `git push` or `firebase deploy` automatically — stop and report instead.
- Never delete or overwrite files outside `lib/` structure without explaining why first.
- When fixing analyze/build errors, prefer the smallest change that fixes the root cause over restructuring working code.
- If the same error persists after 2 attempts, stop and describe what's blocking it instead of continuing to guess.
