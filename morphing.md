# Academia — Morphing Engine Architecture Plan

## Purpose

This document is the build plan for turning Academia into a white-label,
multi-tenant "Education Operating System." One Flutter codebase, one
Firebase backend, one Play Store listing. The app never contains a line
that asks "is this St. Michael?" — it only ever asks "what organization
document is loaded, and what does it say to render?"

Read this whole file before writing any code. Build in the order given
in Section 7.

---

## 1. Firestore Schema

Two top-level collections.

### `organizations/{orgId}`

```
organizations/
  org_st_michael/
    identity: {
      name: "St. Michael College"
      shortName: "SMC"
      country: "CM"
    }
    branding: {
      logoUrl: "https://.../logo.png"
      bannerUrl: "https://.../banner.png"
      welcomeMessage: "Powered by Academia"
      primaryColor: "#1A3C6E"
      secondaryColor: "#3D7EFF"
      accentColor: "#FFC400"
    }
    modules: {
      attendance: true
      homework: true
      timetable: true
      announcements: true
      finance: false
      library: true
    }
    featureFlags: {
      aiTutor: false
      newDashboard: true
    }
    schemaVersion: 1
```

Notes:
- `modules` is a **map of booleans**, not an array. This gives O(1)
  lookups, simpler security rules, and easier per-module toggling later.
- `schemaVersion` lets old installed clients know whether to trust new
  fields or fall back to safe defaults if the schema shape changes.
- The "Independent Learner" default lives at `organizations/independent`
  (or is hardcoded as a static fallback in-app) — this is the only place
  "Academia" branding is allowed to be hardcoded.

### `serials/{serialId}`

Flat collection (not nested under each org — nesting makes cross-org
admin queries slow).

```
serials/
  SM4231Z9: {
    orgId: "org_st_michael"
    status: "unclaimed"      // unclaimed | claimed | revoked | expired
    claimedByUid: null
    claimedAt: null
    issuedAt: <timestamp>
    expiresAt: <timestamp | null>
    createdBy: "<admin uid>"
  }
```

Generate serials with a CSPRNG. If leaked-list risk matters, store a
hash of the serial instead of plaintext and compare hashes on claim.

---

## 2. Serial Claim Flow

This must be a **single atomic Firestore transaction**, not two
sequential writes — otherwise two students can race-claim the same seat.

Steps inside the transaction:
1. Read `serials/{serialId}`.
2. Verify `status == "unclaimed"` and not expired.
3. Write `status = "claimed"`, `claimedByUid = <uid>`, `claimedAt = now`.
4. Write/update the user's profile doc with `orgId = serials.orgId`.

If the transaction fails because another claim already landed, surface
a clean "this serial has already been used" error — never a generic
crash.

Implement as a **Cloud Function** (`claimSerial`), not client-side
Firestore writes, so the claim logic can't be bypassed or tampered
with from a modified client.

Also implement `generateSerials(orgId, count)` as a Cloud Function —
admin-only, writes N unclaimed serial docs in a batch.

---

## 3. Firestore Security Rules

- A signed-in user may only **read** `organizations/{orgId}` where
  `orgId` matches their own profile's `orgId` field, plus always read
  `organizations/independent`.
- **No client may ever write** to `organizations/*` — only Cloud
  Functions (admin-privileged) write org config.
- `serials/*` is **write-only via Cloud Function**; clients may not
  write status changes directly. Reads should be scoped to what's
  needed for claim verification only.
- This is what makes tenant isolation real rather than just a UI
  convention — enforce it at the rules layer, not just in app logic.

---

## 4. Client-Side Interpreter (build once, never touch per-school)

### Widget Registry

A fixed map from module key string → widget builder:

```
"attendance"    -> AttendanceWidget()
"homework"      -> HomeworkWidget()
"timetable"     -> TimetableWidget()
"announcements" -> AnnouncementsWidget()
"library"       -> LibraryWidget()
"finance"       -> FinanceWidget()
```

The homepage loops over `org.snapshotModules` (the `true` keys from
`modules`) and looks each one up in this registry. **Any module key
present in Firestore that isn't in the registry is silently skipped.**
This is what keeps older installed app versions safe when new module
types are added later — no crash, just a missing widget until the next
app update ships.

### Theme Engine

One function: `OrganizationPackage -> ThemeData`. Reads
`primaryColor` / `secondaryColor` / `accentColor` and builds a single
`ThemeData` object. Called once per org load. No per-school
conditional branches anywhere in this function.

### OrganizationProvider

- Holds the current `OrganizationPackage?` (null = independent mode).
- On app start: check cached `orgId` locally → fetch
  `organizations/{orgId}` from Firestore → parse into
  `OrganizationPackage` → expose `ThemeData` + module list to the rest
  of the app.
- If `orgId` is null, load the static `academiaDefault()` package.

---

## 5. Schema Versioning

Every org doc carries `schemaVersion`. When the shape of `branding` or
`modules` changes in the future, the client checks this field before
trusting new fields, and falls back to safe defaults otherwise. This is
what prevents "a newer school's config confuses an older installed
app" from becoming a silent crash or a broken UI.

---

## 6. Onboarding Runbook (per new school, steady state)

1. Admin creates the org document (`identity` / `branding` / `modules`)
   — via internal admin dashboard or a one-off script.
2. Run `generateSerials(orgId, seatCount)` Cloud Function → writes N
   unclaimed serial docs.
3. Export serials to CSV, hand to school admin for distribution as
   students pay fees.
4. Nothing else. No app rebuild. No Play Store submission. No code
   review.

This is the actual proof the architecture is correct: onboarding a new
tenant is a data operation, not a code change.

---

## 7. Build Order

1. Firestore schema + security rules
2. Cloud Functions: `generateSerials`, `claimSerial` (atomic transaction)
3. Client: `OrganizationProvider` (loads org doc, exposes `ThemeData` + module list)
4. Widget registry + dynamic homepage loop that renders `snapshotModules`
5. Serial-entry screen wired to `claimSerial`, with clean error states
   (already claimed / expired / invalid)
6. Admin tooling for generating/tracking serials — a Google Sheet +
   Apps Script is acceptable for v1; a real dashboard can come later

---

## 8. Known, Deliberate Limitation

The home-screen launcher icon and app name (before the app is even
opened) are compiled into the APK at build time and **cannot** be
changed by any runtime download — this is an OS-level constraint, not
a Flutter limitation. Everything *inside* the app (logo, name shown in
the header, colors, homepage modules, notifications, certificates)
morphs at runtime per this plan. If a school requires a different
launcher icon/app name too, that requires a second build with different
`pubspec.yaml` / Android config values — a separate Play Store listing
or side-loaded build, not part of this architecture.
