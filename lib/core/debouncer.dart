// lib/core/debouncer.dart
// Simple debouncer for delaying rapid callbacks (e.g., search queries).

import 'dart:async';
import 'package:flutter/foundation.dart' show VoidCallback;

class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({this.milliseconds = 500});

  /// Execute [callback] after [milliseconds] of inactivity.
  /// Resets the timer if called again before the delay completes.
  void run(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), callback);
  }

  /// Cancel any pending execution.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Cancel the timer to allow garbage collection.
  void dispose() => cancel();
}
