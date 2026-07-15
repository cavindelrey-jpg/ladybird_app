// lib/services/analytics_service.dart
// Analytics, audit logging, and crash reporting hooks.
// Designed as thin wrappers so you can swap providers without touching feature code.
// Logs to Firestore audit trail + console + real Firebase Analytics/Crashlytics.
// Requires firebase_analytics and firebase_crashlytics in pubspec.yaml.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../core/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Analytics Events
// ─────────────────────────────────────────────────────────────────────────────

/// All trackable events in Academia. Strongly typed — no raw strings in feature code.
enum AcademiaEvent {
  // Auth
  login, logout, sessionStart,
  // Content
  contentUploaded, contentViewed, contentDownloaded,
  // Marks
  markSaved, reportViewed,
  // Assignments
  assignmentCreated, assignmentSubmitted, assignmentGraded,
  // Attendance
  attendanceMarked,
  // Announcements
  announcementPosted,
  // Navigation
  tabChanged, pageViewed,
  // Admin
  userRoleChanged, userSuspended, seatCreated,
  // Institution
  institutionLoaded, featureToggled,
}

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _fa = FirebaseAnalytics.instance;

  AppUser? _currentUser;
  String? _institutionId;

  /// Call once after login to set user context on all subsequent events.
  void setUser(AppUser user, {String? institutionId}) {
    _currentUser = user;
    _institutionId = institutionId;
    _fa.setUserId(id: user.id);
    _fa.setUserProperty(name: 'role', value: user.role.name);
    debugPrint('[Analytics] User context set: ${user.id} (${user.role.name})');
  }

  void clearUser() {
    _currentUser = null;
    _institutionId = null;
    _fa.setUserId(id: null);
  }

  /// Track a named event with optional parameters.
  /// Firebase Analytics param values must be String/num/bool — non-string
  /// values are stringified so callers can pass anything without crashing.
  void track(AcademiaEvent event, {Map<String, dynamic>? params}) {
    final payload = {
      'event': event.name,
      'userId': _currentUser?.id,
      'role': _currentUser?.role.name,
      'institutionId': _institutionId,
      'timestamp': DateTime.now().toIso8601String(),
      ...?params,
    };

    debugPrint('[Analytics] ${event.name}: $payload');

    _fa.logEvent(
      name: event.name,
      parameters: params?.map((k, v) => MapEntry(k, v is num || v is bool ? v : v.toString())),
    );
  }

  /// Track screen/page view.
  void trackScreen(String screenName) {
    debugPrint('[Analytics] Screen: $screenName');
    _fa.logScreenView(screenName: screenName);
    track(AcademiaEvent.pageViewed, params: {'screen': screenName});
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audit Log — persisted to Firestore
// ─────────────────────────────────────────────────────────────────────────────

/// Severity level for audit entries.
enum AuditSeverity { info, warning, critical }

class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();

  final _db = FirebaseFirestore.instance;

  /// Write an audit entry to Firestore.
  /// Collection: `audit_logs/{institutionId}/{entryId}`
  /// Falls back silently on failure — never throws.
  Future<void> log({
    required String institutionId,
    required String actorId,
    required String actorRole,
    required String action,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? metadata,
    AuditSeverity severity = AuditSeverity.info,
  }) async {
    try {
      final entry = {
        'institutionId': institutionId,
        'actorId': actorId,
        'actorRole': actorRole,
        'action': action,
        'targetId': targetId,
        'targetType': targetType,
        'metadata': metadata,
        'severity': severity.name,
        'timestamp': FieldValue.serverTimestamp(),
        'timestampIso': DateTime.now().toIso8601String(),
      };

      await _db
          .collection(AppConstants.colAuditLogs)
          .doc(institutionId)
          .collection('entries')
          .add(entry);

      debugPrint('[Audit] $severity | $actorRole $actorId → $action'
          '${targetId != null ? " ($targetType: $targetId)" : ""}');
    } catch (e) {
      // Audit failures must never crash the app
      debugPrint('[Audit] Failed to write log: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Crash Reporting
// ─────────────────────────────────────────────────────────────────────────────

class CrashService {
  CrashService._();
  static final CrashService instance = CrashService._();

  final FirebaseCrashlytics _fc = FirebaseCrashlytics.instance;

  /// Record a non-fatal error.
  void recordError(dynamic error, StackTrace? stack, {String? context}) {
    debugPrint('[Crash] Non-fatal: $error\n  Context: $context\n  $stack');
    _fc.recordError(error, stack, reason: context, fatal: false);
  }

  /// Record a fatal error (app would crash without this).
  void recordFatal(dynamic error, StackTrace? stack) {
    debugPrint('[Crash] FATAL: $error\n$stack');
    _fc.recordError(error, stack, fatal: true);
  }

  /// Set user identifier for crash reports.
  void setUser(String userId) {
    _fc.setUserIdentifier(userId);
  }

  /// Add a breadcrumb string to the crash report.
  void log(String message) {
    debugPrint('[Crash] Breadcrumb: $message');
    _fc.log(message);
  }
}
