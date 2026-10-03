import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOffline = false;

  bool get isOffline => _isOffline;
  bool get isOnline => !_isOffline;

  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  void initialize() {
    _subscription = _connectivity.onConnectivityChanged.listen(_apply, onError: (_) {});
    // onConnectivityChanged only reports CHANGES -- without this initial
    // check an app launched with no network believed it was online.
    _connectivity.checkConnectivity().then(_apply).catchError((_) {});
  }

  void _apply(List<ConnectivityResult> results) {
    final isOfflineNow = results.isEmpty || results.every((result) => result == ConnectivityResult.none);
    if (_isOffline != isOfflineNow) {
      _isOffline = isOfflineNow;
      _connectionStatusController.add(_isOffline);
    }
  }

  /// Current status first, then every change.
  Stream<bool> watchOffline() async* {
    yield _isOffline;
    yield* _connectionStatusController.stream;
  }

  void dispose() {
    _subscription?.cancel();
    _connectionStatusController.close();
  }
}
