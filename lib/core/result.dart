// lib/core/result.dart
// Lightweight Result type used throughout repositories.
import 'friendly_error.dart';

sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);

  T get data => value;
}

class Failure<T> extends Result<T> {
  final String message;
  final dynamic cause;
  const Failure(this.message, [this.cause]);

  /// Calm, actionable copy for end users. [message] is sometimes a raw
  /// `e.toString()` from a repository's catch block — never display it
  /// directly; display this instead.
  String get friendlyMessage => humanizeError(cause ?? message);
}
