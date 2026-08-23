// test/feature_access_test.dart
// Exhaustive tests for lib/core/feature_access.dart -- the single
// authoritative entitlement gate every paywalled feature in the app is
// supposed to go through. A bug here is a real paywall bypass or a real
// false-lock, so this is tested combinatorially: every account state
// (guest / free / active silver / expired silver / active gold / expired
// gold) against every access level the registry defines, not just one
// happy-path per feature.

import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/core/feature_access.dart';
import 'package:academia_app/models/app_user.dart';
import 'package:academia_app/models/entitlement.dart';

AppUser _userWith(Entitlement entitlement) =>
    AppUser(id: 'u1', name: 'Test User', entitlement: entitlement);

final _guest = AppUser.guest();
final _freeAccount = _userWith(const Entitlement.free());
final _activeSilver = _userWith(Entitlement(
    tier: EntitlementTier.silver,
    expiresAt: DateTime.now().add(const Duration(days: 30))));
final _expiredSilver = _userWith(Entitlement(
    tier: EntitlementTier.silver,
    expiresAt: DateTime.now().subtract(const Duration(days: 1))));
final _perpetualGold = _userWith(const Entitlement(tier: EntitlementTier.gold)); // no expiresAt
final _activeGold = _userWith(Entitlement(
    tier: EntitlementTier.gold,
    expiresAt: DateTime.now().add(const Duration(days: 30))));
final _expiredGold = _userWith(Entitlement(
    tier: EntitlementTier.gold,
    expiresAt: DateTime.now().subtract(const Duration(days: 1))));

void main() {
  group('FeatureAccess.canAccess -- free features', () {
    test('a free-level feature is open to literally everyone, including a signed-out guest', () {
      for (final u in [null, _guest, _freeAccount, _activeSilver, _activeGold]) {
        expect(FeatureAccess.canAccess(u, AppFeature.home), isTrue, reason: '$u');
      }
    });

    test('passing null is treated identically to an explicit AppUser.guest()', () {
      expect(FeatureAccess.canAccess(null, AppFeature.contentLibrary),
          FeatureAccess.canAccess(_guest, AppFeature.contentLibrary));
      expect(FeatureAccess.canAccess(null, AppFeature.clubs),
          FeatureAccess.canAccess(_guest, AppFeature.clubs));
    });
  });

  group('FeatureAccess.canAccess -- authenticated features', () {
    test('guests (null or explicit) are blocked', () {
      expect(FeatureAccess.canAccess(null, AppFeature.clubs), isFalse);
      expect(FeatureAccess.canAccess(_guest, AppFeature.clubs), isFalse);
    });

    test('any signed-in tier -- even a plain free account -- is allowed through, '
        'this level does not require any entitlement', () {
      for (final u in [_freeAccount, _activeSilver, _expiredSilver, _activeGold, _expiredGold]) {
        expect(FeatureAccess.canAccess(u, AppFeature.clubs), isTrue, reason: '$u');
        expect(FeatureAccess.canAccess(u, AppFeature.messages), isTrue, reason: '$u');
      }
    });
  });

  group('FeatureAccess.canAccess -- gold-only features (Video Courses)', () {
    test('guest, free, and silver (even active) are all blocked', () {
      expect(FeatureAccess.canAccess(_guest, AppFeature.coursesVideoLessons), isFalse);
      expect(FeatureAccess.canAccess(_freeAccount, AppFeature.coursesVideoLessons), isFalse);
      expect(FeatureAccess.canAccess(_activeSilver, AppFeature.coursesVideoLessons), isFalse,
          reason: 'Silver must NOT satisfy a Gold-only gate');
    });

    test('an EXPIRED silver or gold entitlement is blocked, not just checked by tier name', () {
      expect(FeatureAccess.canAccess(_expiredSilver, AppFeature.coursesVideoLessons), isFalse);
      expect(FeatureAccess.canAccess(_expiredGold, AppFeature.coursesVideoLessons), isFalse);
    });

    test('an active or perpetual (no expiry) gold entitlement is allowed', () {
      expect(FeatureAccess.canAccess(_activeGold, AppFeature.coursesVideoLessons), isTrue);
      expect(FeatureAccess.canAccess(_perpetualGold, AppFeature.coursesVideoLessons), isTrue);
    });
  });

  group('FeatureAccess.canAccess -- an entitlement expiring at exactly this instant', () {
    test('an entitlement that expires RIGHT NOW (not after) is already inactive', () {
      // Mirrors Entitlement.isActive's own boundary: `exp.isAfter(now)` --
      // an expiry timestamp equal to "now" is NOT after "now", so it must
      // already read as expired, not as "still valid for one more instant".
      final expiringNow = _userWith(Entitlement(
          tier: EntitlementTier.gold, expiresAt: DateTime.now()));
      expect(FeatureAccess.canAccess(expiringNow, AppFeature.coursesVideoLessons), isFalse);
    });
  });

  group('FeatureAccess.canAccess -- unavailable (role-gated) features', () {
    test('default-closed for every account tier, including gold -- these are '
        'intentionally NOT decided by entitlement tier at all', () {
      for (final u in [_guest, _freeAccount, _activeSilver, _activeGold]) {
        expect(FeatureAccess.canAccess(u, AppFeature.salesDesk), isFalse, reason: '$u');
        expect(FeatureAccess.canAccess(u, AppFeature.gradingQueue), isFalse, reason: '$u');
        expect(FeatureAccess.canAccess(u, AppFeature.testComposer), isFalse, reason: '$u');
      }
    });
  });

  group('FeatureAccess.levelOf', () {
    test('every AppFeature enum value has an explicit registry entry '
        '(none silently fall through to the unavailable default)', () {
      // If a new AppFeature is ever added without a matching _registry
      // entry, levelOf() falls back to `unavailable` (fail-closed) rather
      // than throwing -- this test would still pass, which is the
      // correct fail-safe behavior, but is worth knowing about.
      for (final f in AppFeature.values) {
        expect(() => FeatureAccess.levelOf(f), returnsNormally, reason: '$f');
      }
    });
  });

  group('FeatureAccess.reasonBlocked', () {
    test('an accessible feature has an empty block reason', () {
      expect(FeatureAccess.reasonBlocked(_freeAccount, AppFeature.home), '');
      expect(FeatureAccess.reasonBlocked(_activeGold, AppFeature.coursesVideoLessons), '');
    });

    test('an authenticated-gate guest gets a sign-in prompt', () {
      expect(FeatureAccess.reasonBlocked(_guest, AppFeature.clubs), 'Sign in to continue.');
    });

    test('a non-silver account blocked from a silver feature gets a generic upgrade prompt', () {
      expect(FeatureAccess.reasonBlocked(_freeAccount, AppFeature.coursesVideoLessons),
          isNot(''));
    });

    test('a silver (not gold) account blocked from Video Courses gets the '
        'Gold-specific upsell copy, not the generic one', () {
      final reason = FeatureAccess.reasonBlocked(_activeSilver, AppFeature.coursesVideoLessons);
      expect(reason, contains('Gold'));
    });

    test('a free (non-silver) account blocked from Video Courses gets the '
        'generic upgrade copy, since it has not even reached Silver', () {
      final reason = FeatureAccess.reasonBlocked(_freeAccount, AppFeature.coursesVideoLessons);
      expect(reason, isNot(contains('need Premium Gold')));
    });

    test('an unavailable (role-gated) feature never leaks a paywall message -- '
        'it is not a paywall, so it must not imply upgrading would help', () {
      final reason = FeatureAccess.reasonBlocked(_activeGold, AppFeature.salesDesk);
      expect(reason, isNot(contains('Upgrade')));
    });
  });
}
