// lib/providers/institution_provider.dart
// Global ChangeNotifier that stores the active Institution and exposes
// runtime theme/branding switching and tenant-specific feature flags.
//
// Usage:
//   context.read<InstitutionProvider>().loadByCode('OXFRD')
//   context.watch<InstitutionProvider>().institution
//   context.read<InstitutionProvider>().hasFeature(InstitutionFeature.marks)

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/institution.dart';
import '../repositories/institution_repository.dart';
import '../core/result.dart';

/// Status of the institution loading lifecycle.
enum InstitutionStatus {
  idle,       // nothing attempted
  validating, // network call in flight
  loaded,     // institution available
  error,      // validation or network error
}

class InstitutionProvider extends ChangeNotifier {
  // ─── State ───────────────────────────────────────────────────────────────

  Institution? _institution;
  InstitutionStatus _status = InstitutionStatus.idle;
  String? _errorMessage;

  // Subscription for live Firestore config updates
  // ignore: cancel_subscriptions
  dynamic _watchSub;

  // ─── Public getters ───────────────────────────────────────────────────────

  Institution? get institution => _institution;
  InstitutionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoaded => _status == InstitutionStatus.loaded;
  bool get isValidating => _status == InstitutionStatus.validating;

  /// Returns the active institution or a sensible fallback.
  Institution get effectiveInstitution =>
      _institution ?? Institution.fallback;

  /// Convenience: check if a feature is enabled in the current institution.
  bool hasFeature(InstitutionFeature feature) {
    if (_institution == null) return false;
    return _institution!.hasFeature(feature);
  }

  /// Convenience: list of all enabled features.
  List<InstitutionFeature> get enabledFeatures =>
      _institution?.enabledFeatures ?? [];

  // ─── Actions ──────────────────────────────────────────────────────────────

  /// Validate a school code string locally before hitting Firestore.
  String? validateCodeLocally(String code) =>
      InstitutionRepository.validateCode(code);

  /// Validate a school code and load the institution.
  Future<bool> loadByCode(String code) async {
    // Local validation first (no round-trip)
    final localError = validateCodeLocally(code);
    if (localError != null) {
      _errorMessage = localError;
      _set(InstitutionStatus.error);
      return false;
    }
    _set(InstitutionStatus.validating);
    final result = await InstitutionRepository.instance.findByCode(code);
    return _handleResult(result);
  }

  /// Load an institution directly by its Firestore document ID.
  /// Used when a signed-in linked student's institution hasn't been
  /// loaded yet on this app session (e.g. sign-in without a prior
  /// restoreFromPrefs hit).
  Future<bool> loadById(String id) async {
    if (id.isEmpty) return false;
    _set(InstitutionStatus.validating);
    final result = await InstitutionRepository.instance.findById(id);
    return _handleResult(result);
  }

  /// Restore institution from a previously-stored ID (e.g. SharedPreferences).
  Future<bool> restoreFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(AppConstants.prefInstitutionId);
      final code = prefs.getString(AppConstants.prefSchoolCode);
      if (id == null || id.isEmpty) return false;

      _set(InstitutionStatus.validating);
      final result = await InstitutionRepository.instance.findById(id);
      if (result is Success<Institution>) {
        await _activate(result.value, code ?? '');
        return true;
      }
    } catch (_) {}
    _set(InstitutionStatus.idle);
    return false;
  }

  /// Activate an already-fetched Institution immediately — used by the
  /// serial-number entry screen so the app visibly re-brands (logo, name,
  /// colors) the moment a serial resolves, before the student has even
  /// personalized their seat. This is the actual "morph" moment: branding
  /// swap and account creation are two separate steps on purpose.
  Future<void> activate(Institution institution) => _activate(institution, institution.schoolCode);

  /// Log out of the current institution (go back to school code entry).
  Future<void> clear() async {
    _watchSub?.cancel();
    _watchSub = null;
    _institution = null;
    _errorMessage = null;
    _status = InstitutionStatus.idle;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefInstitutionId);
    await prefs.remove(AppConstants.prefSchoolCode);
    notifyListeners();
  }

  /// Runtime branding update — triggers live theme switch without restart.
  Future<void> updateBranding({
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
    String? fontFamily,
    String? tagline,
  }) async {
    if (_institution == null) return;
    await InstitutionRepository.instance.updateBranding(
      _institution!.institutionId,
      logoUrl: logoUrl,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      accentColor: accentColor,
      fontFamily: fontFamily,
      tagline: tagline,
    );
    // The live watch subscription will pick up the Firestore update and
    // call notifyListeners() — no manual state update needed here.
  }

  /// Enable a feature flag for the current institution.
  Future<Result<void>> enableFeature(InstitutionFeature feature) async {
    if (_institution == null) return const Failure('No institution loaded', null);
    return InstitutionRepository.instance
        .enableFeature(_institution!.institutionId, feature);
  }

  /// Disable a feature flag for the current institution.
  Future<Result<void>> disableFeature(InstitutionFeature feature) async {
    if (_institution == null) return const Failure('No institution loaded', null);
    return InstitutionRepository.instance
        .disableFeature(_institution!.institutionId, feature);
  }

  // ─── Internal ─────────────────────────────────────────────────────────────

  Future<bool> _handleResult(Result<Institution> result) async {
    if (result is Success<Institution>) {
      await _activate(result.value, result.value.schoolCode);
      return true;
    } else {
      _errorMessage = (result as Failure).message;
      _set(InstitutionStatus.error);
      return false;
    }
  }

  Future<void> _activate(Institution inst, String code) async {
    // Persist to prefs so next cold-start can restore without re-entering code
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefInstitutionId, inst.institutionId);
    await prefs.setString(AppConstants.prefSchoolCode, code);

    // Subscribe to live updates — theme changes propagate instantly.
    _watchSub?.cancel();
    _watchSub = InstitutionRepository.instance
        .watch(inst.institutionId)
        .listen((updated) {
      if (updated != null) {
        _institution = updated;
        notifyListeners();
      }
    });

    _institution = inst;
    _errorMessage = null;
    _set(InstitutionStatus.loaded);
  }

  void _set(InstitutionStatus s) {
    _status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    super.dispose();
  }
}
