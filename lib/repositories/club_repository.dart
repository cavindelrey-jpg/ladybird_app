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

  // ── Join requests (approval-gated clubs only) ─────────────
  // Open clubs skip all of this and call joinClub() directly — these
  // methods only matter when Club.requiresApproval is true.

  CollectionReference<Map<String, dynamic>> get _joinRequests =>
      _db.collection(AppConstants.colClubJoinRequests);

  Future<Result<void>> requestToJoin({
    required String clubId, required String clubName,
    required String userId, required String userName, String? userPhotoUrl,
  }) async {
    try {
      final existing = await _joinRequests
          .where('clubId', isEqualTo: clubId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return const Failure('Request already pending', null);

      await _joinRequests.add(ClubJoinRequest(
        id: '', clubId: clubId, clubName: clubName,
        userId: userId, userName: userName, userPhotoUrl: userPhotoUrl,
        createdAt: DateTime.now(),
      ).toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to send join request', e);
    }
  }

  /// Pending/approved/declined status of this user's most recent request
  /// for this club — drives the "Pending" badge on My Clubs.
  Stream<ClubJoinRequestStatus?> watchMyRequestStatus(String clubId, String userId) => _joinRequests
      .where('clubId', isEqualTo: clubId)
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : ClubJoinRequest.fromFirestore(s.docs.first).status);

  /// Pending requests for a club — for its admins/moderators to review.
  Stream<List<ClubJoinRequest>> watchPendingRequests(String clubId) => _joinRequests
      .where('clubId', isEqualTo: clubId)
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ClubJoinRequest.fromFirestore).toList());

  Future<Result<void>> approveJoinRequest(ClubJoinRequest req) async {
    try {
      final batch = _db.batch();
      batch.update(_joinRequests.doc(req.id), {'status': 'approved'});
      final memberRef = _db.collection(AppConstants.colClubs).doc(req.clubId)
          .collection(AppConstants.colMembers).doc(req.userId);
      batch.set(memberRef, {
        'name': req.userName, 'photoUrl': req.userPhotoUrl,
        'role': ClubRole.member.name, 'joinedAt': FieldValue.serverTimestamp(),
      });
      batch.update(_db.collection(AppConstants.colClubs).doc(req.clubId),
          {'memberCount': FieldValue.increment(1)});
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to approve request', e);
    }
  }

  Future<Result<void>> declineJoinRequest(String requestId) async {
    try {
      await _joinRequests.doc(requestId).update({'status': 'declined'});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to decline request', e);
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

  /// Soft-delete -- same reasoning as MessagingRepository.deleteMessage:
  /// keeps the doc so the thread shows a placeholder instead of a gap,
  /// sender-only both here and in firestore.rules.
  Future<Result<void>> deleteMessage(String clubId, String messageId, String userId) async {
    try {
      final ref = _db.collection(AppConstants.colClubs).doc(clubId)
          .collection(AppConstants.colMessages).doc(messageId);
      final doc = await ref.get();
      if (!doc.exists || doc.data()?['senderId'] != userId) {
        return const Failure('You can only delete your own messages', null);
      }
      await ref.update({'deleted': true, 'text': ''});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete message', e);
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

  /// Founder or school staff only (mirrors firestore.rules' clubs delete
  /// rule) -- the club settings page is the only caller.
  Future<Result<void>> deleteClub(String clubId) async {
    try {
      await _db.collection(AppConstants.colClubs).doc(clubId).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete club', e);
    }
  }
}
