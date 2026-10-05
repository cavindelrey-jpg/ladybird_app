// test/club_scope_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/config/branding.dart';
import 'package:academia_app/core/club_scope.dart';
import 'package:academia_app/models/models.dart';

void main() {
  // Brand definitions for test environments
  const ladybirdBrand = Branding(
    brandId: 'ladybird',
    appName: 'Ladybird Group of Schools',
    tagline: 'High Moral Standards, Academic Excellence',
    primaryColor: Color(0xFF1E6FEB),
    secondaryColor: Color(0xFF0B1F4D),
    accentColor: Color(0xFFF4B400),
    logoAssetPath: 'assets/branding/ladybird_logo.jpg',
    splashAssetPath: 'assets/branding/ladybird_logo.jpg',
    voucherPrefix: 'LB',
    schoolId: 'ladybird',
  );

  const greenHillsBrand = Branding(
    brandId: 'green_hill',
    appName: 'Green Hills Academic Complex',
    tagline: 'Solid Foundation. Discipline. Success.',
    primaryColor: Color(0xFF0A7A3B),
    secondaryColor: Color(0xFF16A34A),
    accentColor: Color(0xFF86EFAC),
    logoAssetPath: 'assets/branding/green_hill_logo.png',
    splashAssetPath: 'assets/branding/green_hill_logo.png',
    voucherPrefix: 'GH',
    schoolId: 'green_hill',
  );

  const stStephenBrand = Branding(
    brandId: 'st_stephen',
    appName: 'St. Stephen College',
    tagline: 'Faith and Knowledge',
    primaryColor: Color(0xFF800000),
    secondaryColor: Color(0xFF4A0000),
    accentColor: Color(0xFFFFD700),
    logoAssetPath: 'assets/branding/st_stephen_logo.png',
    splashAssetPath: 'assets/branding/st_stephen_logo.png',
    voucherPrefix: 'SS',
    schoolId: 'st_stephen',
  );

  const academiaGeneralBrand = Branding(
    brandId: 'academia',
    appName: 'Academia',
    tagline: 'Your Complete Smart School Platform',
    primaryColor: Color(0xFF1A56DB),
    secondaryColor: Color(0xFF0A1F44),
    accentColor: Color(0xFFC9A227),
    logoAssetPath: 'assets/icon/academia_logo.png',
    splashAssetPath: 'assets/icon/academia_logo.png',
    voucherPrefix: 'AC',
    schoolId: null,
  );

  // Helper to make test users
  AppUser makeUser({
    required String id,
    required UserRole role,
    String? schoolId,
    SchoolRole? schoolRole,
    String? classMasterOfClass,
  }) {
    return AppUser(
      id: id,
      name: 'User $id',
      email: '$id@example.com',
      role: role,
      schoolId: schoolId,
      schoolRole: schoolRole,
      classMasterOfClass: classMasterOfClass,
      entitlement: const Entitlement.free(),
    );
  }

  // Sample clubs
  const ladybirdClub = Club(
    id: 'c-lb-1',
    name: 'Ladybird Science Club',
    emoji: '🔬',
    description: 'Science club at Ladybird',
    moderatorName: 'Teacher A',
    moderatorId: 't-1',
    schoolId: 'ladybird',
  );

  const greenHillsClub = Club(
    id: 'c-gh-1',
    name: 'Green Hills Debate Society',
    emoji: '🗣️',
    description: 'Debate society at Green Hills',
    moderatorName: 'Teacher B',
    moderatorId: 't-2',
    schoolId: 'green_hill',
  );

  const stStephenClub = Club(
    id: 'c-ss-1',
    name: 'St. Stephen Arts Guild',
    emoji: '🎨',
    description: 'Arts guild at St. Stephen',
    moderatorName: 'Teacher C',
    moderatorId: 't-3',
    schoolId: 'st_stephen',
  );

  const generalAcademiaClub = Club(
    id: 'c-ac-1',
    name: 'Academia Coding Club',
    emoji: '💻',
    description: 'General platform-wide club',
    moderatorName: 'Academia Team',
    moderatorId: 'admin-0',
    schoolId: 'academia',
  );

  const unscopedClub = Club(
    id: 'c-un-1',
    name: 'Legacy Unscoped Club',
    emoji: '📚',
    description: 'Club without explicit school ID',
    moderatorName: 'Old User',
    moderatorId: 'old-1',
    schoolId: null,
  );

  group('ClubScope - Core Test Matrix', () {
    test('Ladybird app + Student -> Ladybird only', () {
      final user = makeUser(id: 's1', role: UserRole.student, schoolId: 'ladybird', schoolRole: SchoolRole.student);
      expect(ClubScope.resolveSchoolId(user: user, branding: ladybirdBrand), 'ladybird');

      expect(ClubScope.canAccessClub(ladybirdClub, user: user, branding: ladybirdBrand), isTrue);
      expect(ClubScope.canAccessClub(greenHillsClub, user: user, branding: ladybirdBrand), isFalse);
      expect(ClubScope.canAccessClub(stStephenClub, user: user, branding: ladybirdBrand), isFalse);
      expect(ClubScope.canAccessClub(generalAcademiaClub, user: user, branding: ladybirdBrand), isFalse);
      expect(ClubScope.canAccessClub(unscopedClub, user: user, branding: ladybirdBrand), isFalse);
    });

    test('Ladybird app + Teacher -> Ladybird only', () {
      final user = makeUser(id: 't1', role: UserRole.lecturer, schoolId: 'ladybird', schoolRole: SchoolRole.teacher);
      expect(ClubScope.resolveSchoolId(user: user, branding: ladybirdBrand), 'ladybird');

      expect(ClubScope.canAccessClub(ladybirdClub, user: user, branding: ladybirdBrand), isTrue);
      expect(ClubScope.canAccessClub(greenHillsClub, user: user, branding: ladybirdBrand), isFalse);
      expect(ClubScope.canAccessClub(stStephenClub, user: user, branding: ladybirdBrand), isFalse);
      expect(ClubScope.canAccessClub(generalAcademiaClub, user: user, branding: ladybirdBrand), isFalse);
    });

    test('Ladybird app + Admin -> Ladybird only', () {
      final user = makeUser(id: 'a1', role: UserRole.schoolAdmin, schoolId: 'ladybird', schoolRole: SchoolRole.admin);
      expect(ClubScope.resolveSchoolId(user: user, branding: ladybirdBrand), 'ladybird');

      expect(ClubScope.canAccessClub(ladybirdClub, user: user, branding: ladybirdBrand), isTrue);
      expect(ClubScope.canAccessClub(greenHillsClub, user: user, branding: ladybirdBrand), isFalse);
    });

    test('Ladybird app + Class Master -> Ladybird only', () {
      final user = makeUser(
        id: 'cm1',
        role: UserRole.lecturer,
        schoolId: 'ladybird',
        schoolRole: SchoolRole.classMaster,
        classMasterOfClass: 'Form 5',
      );
      expect(ClubScope.resolveSchoolId(user: user, branding: ladybirdBrand), 'ladybird');

      expect(ClubScope.canAccessClub(ladybirdClub, user: user, branding: ladybirdBrand), isTrue);
      expect(ClubScope.canAccessClub(greenHillsClub, user: user, branding: ladybirdBrand), isFalse);
    });

    test('Ladybird app + Super Admin -> Ladybird only (no cross-school leak)', () {
      final user = makeUser(id: 'sa1', role: UserRole.superAdmin);
      // Super admin inside Ladybird app MUST be restricted to Ladybird
      expect(ClubScope.resolveSchoolId(user: user, branding: ladybirdBrand), 'ladybird');

      expect(ClubScope.canAccessClub(ladybirdClub, user: user, branding: ladybirdBrand), isTrue);
      expect(ClubScope.canAccessClub(greenHillsClub, user: user, branding: ladybirdBrand), isFalse);
      expect(ClubScope.canAccessClub(stStephenClub, user: user, branding: ladybirdBrand), isFalse);
      expect(ClubScope.canAccessClub(generalAcademiaClub, user: user, branding: ladybirdBrand), isFalse);
    });

    test('Green Hills app + Student -> Green Hills only', () {
      final user = makeUser(id: 'gh-s1', role: UserRole.student, schoolId: 'green_hill', schoolRole: SchoolRole.student);
      expect(ClubScope.resolveSchoolId(user: user, branding: greenHillsBrand), 'green_hill');

      expect(ClubScope.canAccessClub(greenHillsClub, user: user, branding: greenHillsBrand), isTrue);
      expect(ClubScope.canAccessClub(ladybirdClub, user: user, branding: greenHillsBrand), isFalse);
      expect(ClubScope.canAccessClub(stStephenClub, user: user, branding: greenHillsBrand), isFalse);
      expect(ClubScope.canAccessClub(generalAcademiaClub, user: user, branding: greenHillsBrand), isFalse);
    });

    test('Green Hills app + Teacher -> Green Hills only', () {
      final user = makeUser(id: 'gh-t1', role: UserRole.lecturer, schoolId: 'green_hill', schoolRole: SchoolRole.teacher);
      expect(ClubScope.resolveSchoolId(user: user, branding: greenHillsBrand), 'green_hill');

      expect(ClubScope.canAccessClub(greenHillsClub, user: user, branding: greenHillsBrand), isTrue);
      expect(ClubScope.canAccessClub(ladybirdClub, user: user, branding: greenHillsBrand), isFalse);
    });

    test('Green Hills app + Admin -> Green Hills only', () {
      final user = makeUser(id: 'gh-a1', role: UserRole.schoolAdmin, schoolId: 'green_hill', schoolRole: SchoolRole.admin);
      expect(ClubScope.resolveSchoolId(user: user, branding: greenHillsBrand), 'green_hill');

      expect(ClubScope.canAccessClub(greenHillsClub, user: user, branding: greenHillsBrand), isTrue);
      expect(ClubScope.canAccessClub(ladybirdClub, user: user, branding: greenHillsBrand), isFalse);
    });

    test('Green Hills app + Super Admin -> Green Hills only (no cross-school leak)', () {
      final user = makeUser(id: 'sa1', role: UserRole.superAdmin);
      expect(ClubScope.resolveSchoolId(user: user, branding: greenHillsBrand), 'green_hill');

      expect(ClubScope.canAccessClub(greenHillsClub, user: user, branding: greenHillsBrand), isTrue);
      expect(ClubScope.canAccessClub(ladybirdClub, user: user, branding: greenHillsBrand), isFalse);
      expect(ClubScope.canAccessClub(stStephenClub, user: user, branding: greenHillsBrand), isFalse);
    });

    test('Academia General app + Super Admin -> All permitted school clubs', () {
      final user = makeUser(id: 'sa1', role: UserRole.superAdmin);
      // In Academia General environment, super admin has unrestricted cross-school access
      expect(ClubScope.resolveSchoolId(user: user, branding: academiaGeneralBrand), isNull);

      expect(ClubScope.canAccessClub(ladybirdClub, user: user, branding: academiaGeneralBrand), isTrue);
      expect(ClubScope.canAccessClub(greenHillsClub, user: user, branding: academiaGeneralBrand), isTrue);
      expect(ClubScope.canAccessClub(stStephenClub, user: user, branding: academiaGeneralBrand), isTrue);
      expect(ClubScope.canAccessClub(generalAcademiaClub, user: user, branding: academiaGeneralBrand), isTrue);
      expect(ClubScope.canAccessClub(unscopedClub, user: user, branding: academiaGeneralBrand), isTrue);
    });

    test('Academia General app + Ordinary User -> Not all school clubs', () {
      final unlinkedUser = makeUser(id: 'ind-1', role: UserRole.student);
      expect(ClubScope.resolveSchoolId(user: unlinkedUser, branding: academiaGeneralBrand), 'academia');

      expect(ClubScope.canAccessClub(generalAcademiaClub, user: unlinkedUser, branding: academiaGeneralBrand), isTrue);
      expect(ClubScope.canAccessClub(ladybirdClub, user: unlinkedUser, branding: academiaGeneralBrand), isFalse);
      expect(ClubScope.canAccessClub(greenHillsClub, user: unlinkedUser, branding: academiaGeneralBrand), isFalse);

      final linkedUser = makeUser(id: 'link-1', role: UserRole.student, schoolId: 'st_stephen');
      expect(ClubScope.resolveSchoolId(user: linkedUser, branding: academiaGeneralBrand), 'st_stephen');
      expect(ClubScope.canAccessClub(stStephenClub, user: linkedUser, branding: academiaGeneralBrand), isTrue);
      expect(ClubScope.canAccessClub(ladybirdClub, user: linkedUser, branding: academiaGeneralBrand), isFalse);
      expect(ClubScope.canAccessClub(greenHillsClub, user: linkedUser, branding: academiaGeneralBrand), isFalse);
    });
  });

  group('Club Isolation Workflows', () {
    test('1-6. Create club in Ladybird -> visible in Ladybird, NOT in Green Hills, St. Stephen, or Academia General (ordinary)', () {
      final ladybirdTeacher = makeUser(id: 'lb-t', role: UserRole.lecturer, schoolId: 'ladybird');
      final newClubSchoolId = ClubScope.resolveSchoolId(user: ladybirdTeacher, branding: ladybirdBrand);
      expect(newClubSchoolId, 'ladybird');

      final createdClub = Club(
        id: 'new-lb-club',
        name: 'Ladybird Robotics',
        emoji: '🤖',
        description: 'New robotics club',
        moderatorName: ladybirdTeacher.name,
        moderatorId: ladybirdTeacher.id,
        schoolId: newClubSchoolId,
      );

      // Appears in Ladybird
      expect(ClubScope.canAccessClub(createdClub, user: ladybirdTeacher, branding: ladybirdBrand), isTrue);

      // Does NOT appear in Green Hills
      final ghUser = makeUser(id: 'gh-u', role: UserRole.student, schoolId: 'green_hill');
      expect(ClubScope.canAccessClub(createdClub, user: ghUser, branding: greenHillsBrand), isFalse);

      // Does NOT appear in St. Stephen
      final ssUser = makeUser(id: 'ss-u', role: UserRole.lecturer, schoolId: 'st_stephen');
      expect(ClubScope.canAccessClub(createdClub, user: ssUser, branding: stStephenBrand), isFalse);

      // Does NOT appear in Academia General for ordinary users
      final acUser = makeUser(id: 'ac-u', role: UserRole.student);
      expect(ClubScope.canAccessClub(createdClub, user: acUser, branding: academiaGeneralBrand), isFalse);

      // Super admin in Academia General CAN access it
      final superAdmin = makeUser(id: 'sa', role: UserRole.superAdmin);
      expect(ClubScope.canAccessClub(createdClub, user: superAdmin, branding: academiaGeneralBrand), isTrue);
    });

    test('7. Create Green Hills club -> isolated to Green Hills', () {
      final ghTeacher = makeUser(id: 'gh-t', role: UserRole.lecturer, schoolId: 'green_hill');
      final newClubSchoolId = ClubScope.resolveSchoolId(user: ghTeacher, branding: greenHillsBrand);
      expect(newClubSchoolId, 'green_hill');

      final createdClub = Club(
        id: 'new-gh-club',
        name: 'Green Hills Environmental Club',
        emoji: '🌱',
        description: 'Nature and environment club',
        moderatorName: ghTeacher.name,
        moderatorId: ghTeacher.id,
        schoolId: newClubSchoolId,
      );

      // Appears in Green Hills
      expect(ClubScope.canAccessClub(createdClub, user: ghTeacher, branding: greenHillsBrand), isTrue);

      // Does NOT appear in Ladybird
      final lbUser = makeUser(id: 'lb-u', role: UserRole.student, schoolId: 'ladybird');
      expect(ClubScope.canAccessClub(createdClub, user: lbUser, branding: ladybirdBrand), isFalse);
    });

    test('8. Search isolation: clubs from other schools are strictly filtered out', () {
      final pool = [ladybirdClub, greenHillsClub, stStephenClub, generalAcademiaClub];

      // Ladybird user search filter
      final lbUser = makeUser(id: 'u1', role: UserRole.student, schoolId: 'ladybird');
      final lbResults = pool.where((c) => ClubScope.canAccessClub(c, user: lbUser, branding: ladybirdBrand)).toList();
      expect(lbResults.length, 1);
      expect(lbResults.first.id, 'c-lb-1');

      // Green Hills user search filter
      final ghUser = makeUser(id: 'u2', role: UserRole.lecturer, schoolId: 'green_hill');
      final ghResults = pool.where((c) => ClubScope.canAccessClub(c, user: ghUser, branding: greenHillsBrand)).toList();
      expect(ghResults.length, 1);
      expect(ghResults.first.id, 'c-gh-1');
    });

    test('9. Direct club ID opening: access rejected when club belongs to another school', () {
      final lbUser = makeUser(id: 'lb-student', role: UserRole.student, schoolId: 'ladybird');
      // Opening a known Green Hills club ID from Ladybird
      final canAccess = ClubScope.canAccessClub(greenHillsClub, user: lbUser, branding: ladybirdBrand);
      expect(canAccess, isFalse);

      // Opening a known Ladybird club ID from Green Hills
      final ghUser = makeUser(id: 'gh-student', role: UserRole.student, schoolId: 'green_hill');
      final canAccessLbFromGh = ClubScope.canAccessClub(ladybirdClub, user: ghUser, branding: greenHillsBrand);
      expect(canAccessLbFromGh, isFalse);
    });

    test('10. Super Admin inside school app: cannot access other schools clubs', () {
      final superAdmin = makeUser(id: 'sa', role: UserRole.superAdmin);
      // Super admin inside Ladybird app
      expect(ClubScope.canAccessClub(ladybirdClub, user: superAdmin, branding: ladybirdBrand), isTrue);
      expect(ClubScope.canAccessClub(greenHillsClub, user: superAdmin, branding: ladybirdBrand), isFalse);
      expect(ClubScope.canAccessClub(stStephenClub, user: superAdmin, branding: ladybirdBrand), isFalse);

      // Super admin inside Green Hills app
      expect(ClubScope.canAccessClub(greenHillsClub, user: superAdmin, branding: greenHillsBrand), isTrue);
      expect(ClubScope.canAccessClub(ladybirdClub, user: superAdmin, branding: greenHillsBrand), isFalse);
    });

    test('11. Query-level scope resolution: always school-bound in school-branded apps', () {
      final roles = [UserRole.student, UserRole.lecturer, UserRole.schoolAdmin, UserRole.superAdmin];
      for (final role in roles) {
        final user = makeUser(id: 'u-${role.name}', role: role, schoolId: 'ladybird');
        expect(ClubScope.resolveSchoolId(user: user, branding: ladybirdBrand), 'ladybird');
      }

      for (final role in roles) {
        final user = makeUser(id: 'u-${role.name}', role: role, schoolId: 'green_hill');
        expect(ClubScope.resolveSchoolId(user: user, branding: greenHillsBrand), 'green_hill');
      }
    });

    test('12. Model serialization: writes both school_id and institution_id for database uniformity', () {
      final club = Club(
        id: 'c-test-1',
        name: 'Test Club',
        emoji: '🎯',
        description: 'Test description',
        moderatorName: 'Mod',
        moderatorId: 'm1',
        schoolId: 'ladybird',
      );
      final insertMap = club.toSupabase();
      expect(insertMap['school_id'], 'ladybird');
      expect(insertMap['institution_id'], 'ladybird');

      final updateMap = club.toUpdateMap();
      expect(updateMap['school_id'], 'ladybird');
      expect(updateMap['institution_id'], 'ladybird');

      // Deserialization prefers school_id then institution_id
      final deserialized = Club.fromSupabase({
        'id': 'c-test-1',
        'name': 'Test Club',
        'emoji': '🎯',
        'description': 'Test desc',
        'moderator_name': 'Mod',
        'moderator_id': 'm1',
        'school_id': 'green_hill',
        'institution_id': 'legacy_val',
      });
      expect(deserialized.schoolId, 'green_hill');
    });
  });
}
