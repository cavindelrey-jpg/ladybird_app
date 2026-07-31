import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/organization.dart';

/// Single source of truth for "what app am I right now". Every screen
/// reads `organization.theme` / `organization.snapshotModules` /
/// `organization.navTabs` from this provider — nothing else should
/// branch on "am I St. Michael?" anywhere in the UI.
class OrganizationProvider extends ChangeNotifier {
  Organization _organization = Organization.independent();
  bool _isLoading = false;
  String? _error;

  Organization get organization => _organization;
  OrganizationTheme get theme => _organization.theme;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Call at login / app start with the user's `organizationId` field
  /// from their AppUser doc. Pass null for independent (schoolless) users.
  Future<void> loadForUser({required String? organizationId}) async {
    if (organizationId == null) {
      _organization = Organization.independent();
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationId)
          .get();

      if (doc.exists && doc.data() != null) {
        _organization = Organization.fromFirestore(doc.id, doc.data()!);
      } else {
        _organization = Organization.independent();
      }
    } catch (e) {
      _error = 'Failed to load organization theme: $e';
      _organization = Organization.independent();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _organization = Organization.independent();
    notifyListeners();
  }
}
