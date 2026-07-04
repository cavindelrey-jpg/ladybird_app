// lib/repositories/hero_slide_repository.dart
// Backs the Home banner carousel and its in-app image manager. Writes
// should be locked to superAdmin/schoolAdmin via Firestore rules (see
// firestore_rules_additions.txt).

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/hero_slide.dart';
import '../core/result.dart';

class HeroSlideRepository {
  HeroSlideRepository._();
  static final HeroSlideRepository instance = HeroSlideRepository._();

  final _col = FirebaseFirestore.instance.collection('heroSlides');

  /// Live stream for the Home carousel — active slides only, manual order.
  Stream<List<HeroSlide>> watchActive() => _col
      .where('active', isEqualTo: true)
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map(HeroSlide.fromFirestore).toList());

  /// Full list (incl. inactive) for the manager UI.
  Stream<List<HeroSlide>> watchAll() =>
      _col.orderBy('order').snapshots().map((s) => s.docs.map(HeroSlide.fromFirestore).toList());

  Future<Result<String>> create(HeroSlide slide) async {
    try {
      final ref = await _col.add(slide.toFirestore());
      return Success(ref.id);
    } catch (e) {
      return Failure('Failed to create slide', e);
    }
  }

  Future<Result<void>> update(HeroSlide slide) async {
    try {
      await _col.doc(slide.id).set(slide.toFirestore(), SetOptions(merge: true));
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update slide', e);
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      await _col.doc(id).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete slide', e);
    }
  }

  Future<Result<void>> reorder(List<HeroSlide> inNewOrder) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var i = 0; i < inNewOrder.length; i++) {
        batch.update(_col.doc(inNewOrder[i].id), {'order': i});
      }
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to reorder slides', e);
    }
  }

  /// Uploads a picked image for [slideId], returns the download URL.
  /// Caller should then call update() with imageUrl set.
  Future<Result<String>> uploadImage({
    required String slideId,
    required File imageFile,
  }) async {
    try {
      final ref = FirebaseStorage.instance.ref('hero_slides/$slideId.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      return Success(url);
    } catch (e) {
      return Failure('Failed to upload slide image', e);
    }
  }
}
