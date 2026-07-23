// lib/repositories/hero_slide_repository.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/hero_slide.dart';
import '../core/result.dart';

class HeroSlideRepository {
  HeroSlideRepository._();
  static final HeroSlideRepository instance = HeroSlideRepository._();

  final _col = FirebaseFirestore.instance.collection('heroSlides');

  Stream<List<HeroSlide>> watchActive() => _col
      .where('active', isEqualTo: true)
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map(HeroSlide.fromFirestore).toList());

  /// All slides including inactive ones — for the admin manager UI.
  Stream<List<HeroSlide>> watchAll() => _col
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map(HeroSlide.fromFirestore).toList());

  Future<Result<void>> delete(String id) async {
    try {
      await _col.doc(id).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete slide', e);
    }
  }

  /// Persists a new manual order for the manager's drag-to-reorder list.
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

  Future<Result<String>> uploadImage({required String slideId, required File imageFile}) async {
    try {
      final ref = FirebaseStorage.instance.ref('hero_slides/$slideId.jpg');
      await ref.putFile(imageFile);
      return Success(await ref.getDownloadURL());
    } catch (e) {
      return Failure('Failed to upload slide image', e);
    }
  }
}
