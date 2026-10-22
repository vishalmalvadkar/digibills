import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectionStatus { online, offline }

class ConnectivityService {
  // Singleton instance
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<ConnectionStatus>.broadcast();
  Timer? _backendCheckTimer;
  ConnectionStatus _currentStatus = ConnectionStatus.online;

  Stream<ConnectionStatus> get statusStream => _controller.stream;
  ConnectionStatus get currentStatus => _currentStatus;

  void initialize() {
    // Check initial status
    _connectivity.checkConnectivity().then(_updateConnectivityStatus);

    // Listen for changes
    _connectivity.onConnectivityChanged.listen(_updateConnectivityStatus);
  }

  void _updateConnectivityStatus(List<ConnectivityResult> results) {
    bool hasLocalConnection = results.any((result) => result != ConnectivityResult.none);
    
    if (!hasLocalConnection) {
      _setStatus(ConnectionStatus.offline);
    } else {
      _setStatus(ConnectionStatus.online);
    }
  }

  Future<void> _checkBackendAvailability() async {
    // Backend availability check is no longer used to set global offline status.
    // We rely on local connectivity to avoid false positives.
  }

  void _setStatus(ConnectionStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _controller.add(status);
    }
  }

  Future<bool> get isLocalConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
    
  void dispose() {
    _backendCheckTimer?.cancel();
    _controller.close();
  }
}
