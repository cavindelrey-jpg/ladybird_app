// lib/core/friendly_error.dart
// Turns a raw exception/error into calm, actionable copy fit for end users.
// Never let a stack trace, error code, or raw exception type reach the UI —
// route every user-visible error string through humanizeError() instead of
// calling error.toString() directly.
import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

String humanizeError(Object error) {
  if (error is SocketException || error is TimeoutException) {
    return 'We couldn\'t connect to the internet. Please check your connection and try again.';
  }
  if (error is AuthException) {
    return _humanizeAuthMessage(error.message);
  }
  if (error is PostgrestException) {
    return _humanizePostgrestMessage(error.message, error.code);
  }

  final text = error.toString();
  if (_looksOffline(text)) {
    return "You're offline. Check your connection and try again.";
  }
  if (_looksLikeTimeout(text)) {
    return 'This is taking longer than expected. Check your connection and try again.';
  }
  if (_looksLikePermission(text)) {
    return "You don't have permission to do that.";
  }

  // This codebase's own services and repositories deliberately write
  // plain, already-calm, human-authored messages — a hand-written
  // Exception('...') (see e.g. AuthService.signIn/claimLinkedSeat) or a
  // Failure(message, cause) with no cause (a validation-style failure,
  // see e.g. SerialRepository.preview). Trust and surface those verbatim
  // instead of flattening them to the generic fallback below.
  if (error is String) return error;
  if (error is Exception) {
    final stripped = text.replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (stripped.isNotEmpty && stripped != text) return stripped;
  }

  return 'Something didn\'t quite work. Please try again in a moment.';
}

String _humanizeAuthMessage(String message) {
  final m = message.toLowerCase();
  if (m.contains('invalid login credentials') ||
      m.contains('invalid credentials')) {
    return 'Incorrect email or password. Give it another try, or reset your password below.';
  }
  if (m.contains('email not confirmed')) {
    return 'Please confirm your email address before signing in — check your inbox for the link.';
  }
  if (m.contains('user already registered') ||
      m.contains('already registered')) {
    return 'An account with that email already exists. Try signing in instead.';
  }
  if (m.contains('rate limit') || m.contains('too many requests')) {
    return 'Too many attempts. Please wait a moment before trying again.';
  }
  if (_looksOffline(m)) {
    return "You're offline. Check your connection and try again.";
  }
  return message;
}

String _humanizePostgrestMessage(String message, String? code) {
  if (code == '42501' || _looksLikePermission(message)) {
    return "You don't have permission to do that.";
  }
  if (code == 'PGRST116') {
    return "We couldn't find that — it may have been removed.";
  }
  if (_looksOffline(message)) {
    return "You're offline. Check your connection and try again.";
  }
  return 'Something didn\'t quite work. Please try again in a moment.';
}

bool _looksOffline(String text) {
  final t = text.toLowerCase();
  return t.contains('socketexception') ||
      t.contains('failed host lookup') ||
      t.contains('network is unreachable') ||
      t.contains('connection failed') ||
      t.contains('connection refused') ||
      t.contains('clientexception') ||
      t.contains('no internet') ||
      t.contains('failed to fetch');
}

bool _looksLikeTimeout(String text) {
  final t = text.toLowerCase();
  return t.contains('timeoutexception') || t.contains('timed out');
}

bool _looksLikePermission(String text) {
  final t = text.toLowerCase();
  return t.contains('permission denied') ||
      t.contains('row-level security') ||
      t.contains('not authorized') ||
      t.contains('unauthorized');
}
