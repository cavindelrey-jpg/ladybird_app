// lib/repositories/club_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../core/constants.dart';
import '../core/result.dart';

class ClubRepository {
  ClubRepository._();
  static final ClubRepository instance = ClubRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Discovery ──────────────────────────────────────────

  Stream<List<Club>> watchClubs({String? schoolId}) {
    Query<Map<String, dynamic>> q = _db.collection(AppConstants.colClubs);
    if (schoolId != null) q = q.where('schoolId', isEqualTo: schoolId);
    return q.snapshots()
        .map((snap) => snap.docs.map(Club.fromFirestore).toList());
  }

  Future<List<Club>> searchClubs(String query, {String? category}) async {
    Query<Map<String, dynamic>> q = _db.collection(AppConstants.colClubs);
    if (category != null && category != 'All') {
      q = q.where('category', isEqualTo: category);
    }
    final snap = await q.get();
    final lower = query.toLowerCase();
    return snap.docs
        .map(Club.fromFirestore)
        .where((c) => query.isEmpty || c.name.toLowerCase().contains(lower))
        .toList();
  }

  // ── Membership ─────────────────────────────────────────

  Stream<ClubRole> watchUserRole(String clubId, String userId) {
    return _db
        .collection(AppConstants.colClubs)
        .doc(clubId)
        .collection(AppConstants.colMembers)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return ClubRole.visitor;
      final roleStr = doc.data()?['role'] as String?;
      return ClubRole.values.firstWhere(
        (r) => r.name == roleStr, orElse: () => ClubRole.member);
    });
  }

  Future<Result<void>> joinClub(String clubId, String userId) async {
    try {
      final batch = _db.batch();
      final memberRef = _db
          .collection(AppConstants.colClubs)
          .doc(clubId)
          .collection(AppConstants.colMembers)
          .doc(userId);
      batch.set(memberRef, {'role': ClubRole.member.name, 'joinedAt': FieldValue.serverTimestamp()});
      batch.update(
        _db.collection(AppConstants.colClubs).doc(clubId),
        {'memberCount': FieldValue.increment(1)},
      );
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to join club', e);
    }
  }

  Future<Result<void>> leaveClub(String clubId, String userId) async {
    try {
      final batch = _db.batch();
      batch.delete(_db
          .collection(AppConstants.colClubs)
          .doc(clubId)
          .collection(AppConstants.colMembers)
          .doc(userId));
      batch.update(
        _db.collection(AppConstants.colClubs).doc(clubId),
        {'memberCount': FieldValue.increment(-1)},
      );
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to leave club', e);
    }
  }

  // ── Chat ───────────────────────────────────────────────

  Stream<List<ClubMessage>> watchMessages(String clubId) {
    return _db
        .collection(AppConstants.colClubs)
        .doc(clubId)
        .collection(AppConstants.colMessages)
        .orderBy('time', descending: false)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(ClubMessage.fromFirestore).toList());
  }

  Future<Result<void>> sendMessage(String clubId, ClubMessage message) async {
    try {
      await _db
          .collection(AppConstants.colClubs)
          .doc(clubId)
          .collection(AppConstants.colMessages)
          .add(message.toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to send message', e);
    }
  }

  // ── Create ─────────────────────────────────────────────

  Future<Result<String>> createClub(Club club, String founderId) async {
    try {
      final docRef = _db.collection(AppConstants.colClubs).doc();
      final batch = _db.batch();
      batch.set(docRef, club.toFirestore());
      batch.set(
        docRef.collection(AppConstants.colMembers).doc(founderId),
        {'role': ClubRole.admin.name, 'joinedAt': FieldValue.serverTimestamp()},
      );
      await batch.commit();
      return Success(docRef.id);
    } catch (e) {
      return Failure('Failed to create club', e);
    }
  }
}
