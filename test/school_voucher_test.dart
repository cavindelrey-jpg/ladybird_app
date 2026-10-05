// test/school_voucher_test.dart
// Covers the pure, testable surface of lib/models/school_voucher.dart --
// code generation format, normalization, and role mapping. Redemption
// atomicity (SchoolAccessRepository.redeemSchoolVoucher's transaction)
// needs a real/emulated Firestore and isn't testable as a pure unit test
// here -- that's the "NEEDS-LIVE-TEST" category this codebase has used
// honestly all session, not silently skipped.

import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/models/school_voucher.dart';
import 'package:academia_app/models/app_user.dart';

void main() {
  group('SchoolRoleX', () {
    test('code matches the documented prefix for every role', () {
      expect(SchoolRole.student.code, 'S');
      expect(SchoolRole.parent.code, 'P');
      expect(SchoolRole.teacher.code, 'T');
      expect(SchoolRole.classMaster.code, 'CM');
      expect(SchoolRole.admin.code, 'A');
    });

    test('contentRole never grants content-authoring privilege to a parent', () {
      expect(SchoolRole.parent.contentRole, UserRole.guest);
    });

    test('contentRole maps teacher and classMaster to lecturer', () {
      expect(SchoolRole.teacher.contentRole, UserRole.lecturer);
      expect(SchoolRole.classMaster.contentRole, UserRole.lecturer);
    });

    test('contentRole maps admin to schoolAdmin, not superAdmin', () {
      expect(SchoolRole.admin.contentRole, UserRole.schoolAdmin);
    });

    test('fromCode round-trips every role, case-insensitively', () {
      for (final role in SchoolRole.values) {
        expect(SchoolRoleX.fromCode(role.code), role);
        expect(SchoolRoleX.fromCode(role.code.toLowerCase()), role);
      }
    });

    test('fromCode returns null for an unknown code', () {
      expect(SchoolRoleX.fromCode('X'), isNull);
      expect(SchoolRoleX.fromCode(''), isNull);
    });

    test('fromName round-trips every role', () {
      for (final role in SchoolRole.values) {
        expect(SchoolRoleX.fromName(role.name), role);
      }
    });

    test('fromName returns null for an unknown name', () {
      expect(SchoolRoleX.fromName('principal'), isNull);
    });
  });

  group('SchoolVoucher.generateCode', () {
    test('starts with the uppercased school code and role code as delimited segments', () {
      final code = SchoolVoucher.generateCode(schoolCode: 'gh', role: SchoolRole.student);
      expect(code, startsWith('GH-S-'));
    });

    test('classMaster prefix uses the 2-letter CM code, not just C', () {
      final code = SchoolVoucher.generateCode(schoolCode: 'GH', role: SchoolRole.classMaster);
      expect(code, startsWith('GH-CM-'));
    });

    test('random segment is exactly 6 characters from the confusable-free alphabet, premium segment trails it', () {
      final code = SchoolVoucher.generateCode(
        schoolCode: 'GH',
        role: SchoolRole.admin,
        premiumTier: VoucherPremiumTier.gold,
      );
      final parts = code.split('-');
      expect(parts, ['GH', 'A', parts[2], 'G']);
      final random = parts[2];
      expect(random.length, 6);
      // Explicit alphabet list, not a letter range -- I/L/O are excluded
      // non-contiguously (A-H, J-K, M-N, P-Z), so a range like [A-Z]
      // minus a few letters can't be expressed as a simple regex range
      // without accidentally re-including one of them.
      expect(random, matches(RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ2-9]{6}$')));
      // Excluded confusables must never appear.
      expect(random.contains('O'), isFalse);
      expect(random.contains('I'), isFalse);
      expect(random.contains('L'), isFalse);
      expect(random.contains('0'), isFalse);
      expect(random.contains('1'), isFalse);
    });

    test('a null premiumTier encodes as the N (none) segment', () {
      final code = SchoolVoucher.generateCode(schoolCode: 'GH', role: SchoolRole.parent);
      expect(code.split('-').last, 'N');
    });

    test('1000 generated codes are all unique (CSPRNG sanity check)', () {
      final codes = {
        for (var i = 0; i < 1000; i++)
          SchoolVoucher.generateCode(schoolCode: 'GH', role: SchoolRole.student),
      };
      expect(codes.length, 1000);
    });
  });

  group('SchoolVoucher.normalizeCode / formatCode', () {
    test('normalizeCode uppercases and turns whitespace into a segment boundary', () {
      expect(SchoolVoucher.normalizeCode('gh-t x7m2q9-g'), 'GH-T-X7M2Q9-G');
    });

    test('normalizeCode keeps real letters even when excluded from the random alphabet', () {
      // O/I/L/0/1 are excluded from generateCode's RANDOM-segment alphabet
      // only -- the school prefix and role segments are real letters
      // chosen for meaning (Ladybird's "LB", itSupport's "I"), so
      // normalizeCode must NOT strip them (see c3bcc5d).
      expect(SchoolVoucher.normalizeCode('lb-i-a1b2c3-g'), 'LB-I-A1B2C3-G');
    });

    test('normalizeCode strips characters outside A-Z/0-9/dash', () {
      expect(SchoolVoucher.normalizeCode('GH-T-X@Y!Z#123-G'), 'GH-T-XYZ123-G');
    });

    test('normalizeCode collapses runs of dashes into one', () {
      expect(SchoolVoucher.normalizeCode('GH--T---X7M2Q9-G'), 'GH-T-X7M2Q9-G');
    });

    test('formatCode is the identity function -- the code IS the display form', () {
      expect(SchoolVoucher.formatCode('GH-T-X7M2Q9-G'), 'GH-T-X7M2Q9-G');
    });

    test('generateCode -> normalizeCode -> formatCode round-trips to the same shape', () {
      final code = SchoolVoucher.generateCode(schoolCode: 'GH', role: SchoolRole.teacher);
      final displayed = SchoolVoucher.formatCode(code);
      expect(SchoolVoucher.normalizeCode(displayed), code);
    });
  });

  group('SchoolVoucher.isPlausibleCode', () {
    test('a real generated code is plausible', () {
      final code = SchoolVoucher.generateCode(schoolCode: 'GH', role: SchoolRole.student);
      expect(SchoolVoucher.isPlausibleCode(code), isTrue);
    });

    test('an empty or undelimited string is not plausible', () {
      expect(SchoolVoucher.isPlausibleCode(''), isFalse);
      // No '-' delimiters at all -- parse() requires exactly 4 segments,
      // so a glued-together string never resolves regardless of content.
      expect(SchoolVoucher.isPlausibleCode('GHS1234'), isFalse);
    });
  });
}
