import 'dart:async';

/// Caches and shares a single source Stream subscription among multiple listeners.
/// When the last listener unsubscribes, the underlying source stream is cancelled
/// after a short delay, preventing thrashing if listeners briefly drop to 0.
class StreamCache {
  final Map<String, Stream<dynamic>> _cache = {};

  Stream<T> watch<T>(String key, Stream<T> Function() sourceBuilder) {
    if (_cache.containsKey(key)) {
      return _cache[key]! as Stream<T>;
    }

    StreamController<T>? controller;
    StreamSubscription<T>? subscription;

    void startSubscription() {
      subscription = sourceBuilder().listen(
        (data) => controller?.add(data),
        onError: (e, st) => controller?.addError(e, st),
        onDone: () => controller?.close(),
      );
    }

    controller = StreamController<T>.broadcast(
      onListen: () {
        if (subscription == null) {
          startSubscription();
        } else if (subscription!.isPaused) {
          subscription!.resume();
        }
      },
      onCancel: () {
        // Delay cancellation to prevent thrashing on rapid UI rebuilds.
        Timer(const Duration(seconds: 1), () {
          if (controller != null && !controller!.hasListener) {
            subscription?.cancel();
            subscription = null;
            _cache.remove(key);
            controller?.close();
          }
        });
      },
    );

    final stream = controller.stream;
    _cache[key] = stream;
    return stream;
  }
  
  void clear() => _cache.clear();
}
