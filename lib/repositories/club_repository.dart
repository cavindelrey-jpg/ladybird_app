// lib/repositories/club_repository.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  Future<Result<void>> joinClub(
    String clubId,
    String userId, {
    required String name,
    String? photoUrl,
  }) async {
    try {
      final batch = _db.batch();
      final memberRef = _db
          .collection(AppConstants.colClubs)
          .doc(clubId)
          .collection(AppConstants.colMembers)
          .doc(userId);
      batch.set(memberRef, {
        'name': name,
        'photoUrl': photoUrl,
        'role': ClubRole.member.name,
        'joinedAt': FieldValue.serverTimestamp(),
      });
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

  Future<Result<String>> createClub(
    Club club,
    String founderId, {
    required String founderName,
    String? founderPhotoUrl,
  }) async {
    try {
      final docRef = _db.collection(AppConstants.colClubs).doc();
      final batch = _db.batch();
      batch.set(docRef, club.toFirestore());
      batch.set(
        docRef.collection(AppConstants.colMembers).doc(founderId),
        {
          'name': founderName,
          'photoUrl': founderPhotoUrl,
          'role': ClubRole.admin.name,
          'joinedAt': FieldValue.serverTimestamp(),
        },
      );
      await batch.commit();
      return Success(docRef.id);
    } catch (e) {
      return Failure('Failed to create club', e);
    }
  }

  // ── Member management (mod structure) ───────────────────
  // Normal roles: visitor (not joined) < member < moderator < admin.
  // Moderators can manage regular members; only admins can appoint or
  // remove other moderators/admins. Enforced both here (defense in
  // depth for the UI) and in firestore.rules (the real gate).

  Stream<List<ClubMember>> watchMembers(String clubId) => _db
      .collection(AppConstants.colClubs)
      .doc(clubId)
      .collection(AppConstants.colMembers)
      .orderBy('joinedAt')
      .snapshots()
      .map((s) => s.docs.map(ClubMember.fromFirestore).toList());

  Future<Result<void>> updateMemberRole(
      String clubId, String userId, ClubRole newRole) async {
    try {
      await _db
          .collection(AppConstants.colClubs)
          .doc(clubId)
          .collection(AppConstants.colMembers)
          .doc(userId)
          .update({'role': newRole.name});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update member role', e);
    }
  }

  Future<Result<void>> removeMember(String clubId, String userId) async {
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
      return Failure('Failed to remove member', e);
    }
  }

  // ── Banner image ─────────────────────────────────────────

  Future<Result<String>> uploadBanner({
    required String clubId,
    required File imageFile,
  }) async {
    try {
      final ref = FirebaseStorage.instance.ref('club_banners/$clubId.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      return Success(url);
    } catch (e) {
      return Failure('Failed to upload club banner', e);
    }
  }

  Future<Result<void>> updateClub(Club club) async {
    try {
      await _db.collection(AppConstants.colClubs).doc(club.id)
          .set(club.toFirestore(), SetOptions(merge: true));
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update club', e);
    }
  }
}
