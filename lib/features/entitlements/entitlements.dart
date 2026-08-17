// lib/features/entitlements/entitlements.dart
// Barrel for the entitlements feature (production_plan.md §8/§9).
//
// production_plan.md §10 names Entitlements as one of the three top-level
// layers of the final architecture ("Free + Premium + Gifted Premium +
// Future Sponsored/School/Promotional Access"), deliberately decoupled
// from both Academia (the learning platform) and School Management. It
// gets its own feature folder for that reason rather than being buried in
// features/admin/ — the sales desk happens to be admin-gated, but the
// entitlement layer as a whole is not an administration concern.
export 'redeem_voucher_page.dart';
export 'sales_desk_page.dart';
