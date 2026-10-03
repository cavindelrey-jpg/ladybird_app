import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../core/supabase_config.dart';

/// "Offline" = no network interface OR the backend can't actually be
/// reached. Interface state alone isn't enough: with an exhausted data
/// bundle or a captive Wi-Fi portal the phone reports a live connection
/// while every request fails -- connectivity_plus calls that online.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _probeTimer;
  bool _interfaceDown = false;
  bool _unreachable = false;
  bool _isOffline = false;

  bool get isOffline => _isOffline;
  bool get isOnline => !_isOffline;

  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  /// Current status first, then every change.
  Stream<bool> watchOffline() async* {
    yield _isOffline;
    yield* _connectionStatusController.stream;
  }

  void initialize() {
    _subscription = _connectivity.onConnectivityChanged.listen(_applyInterfaces, onError: (_) {});
    // onConnectivityChanged only reports CHANGES -- without this initial
    // check an app launched with no network believed it was online.
    _connectivity.checkConnectivity().then(_applyInterfaces).catchError((_) {});
    _probe();
  }

  void _applyInterfaces(List<ConnectivityResult> results) {
    _interfaceDown = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    _publish();
    _probe(); // re-check reachability right away on any change
  }

  Future<void> _probe() async {
    _probeTimer?.cancel();
    var reachable = false;
    if (!_interfaceDown) {
      try {
        final res = await http
            .get(Uri.parse('${SupabaseConfig.url}/auth/v1/health'), headers: {'apikey': SupabaseConfig.anonKey})
            .timeout(const Duration(seconds: 5));
        reachable = res.statusCode < 500;
      } catch (_) {}
    }
    _unreachable = !reachable;
    _publish();
    // Cheap while things work; quicker to notice recovery while offline.
    _probeTimer = Timer(Duration(seconds: _isOffline ? 30 : 120), _probe);
  }

  /// Lets screens report a failed request so the banner appears without
  /// waiting for the next probe.
  void reportRequestFailed() {
    if (!_isOffline) _probe();
  }

  void _publish() {
    final offline = _interfaceDown || _unreachable;
    if (offline != _isOffline) {
      _isOffline = offline;
      _connectionStatusController.add(_isOffline);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _probeTimer?.cancel();
    _connectionStatusController.close();
  }
}
