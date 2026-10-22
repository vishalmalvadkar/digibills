import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // FastAPI base URL (localhost for Windows desktop / Web; use 10.0.2.2 for Android emulator)
  static const String baseUrl = 'http://127.0.0.1:8000';
  static const String wsUrl = 'ws://127.0.0.1:8000';

  String? _token;
  Map<String, dynamic>? _currentUser;
  WebSocketChannel? _wsChannel;
  final StreamController<Map<String, dynamic>> _realtimeEventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get realtimeEvents => _realtimeEventsController.stream;

  String? get token => _token;
  Map<String, dynamic>? get currentUser => _currentUser;
  String get currentTenantId => _currentUser?['tenant_id'] ?? _currentUser?['uid'] ?? '';
  String get currentUserId => _currentUser?['uid'] ?? '';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('api_token');
    final userJson = prefs.getString('api_user');
    if (userJson != null) {
      try {
        _currentUser = jsonDecode(userJson);
        connectWebSocket();
      } catch (_) {}
    }
  }

  Future<void> saveSession(String token, Map<String, dynamic> user) async {
    _token = token;
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_token', token);
    await prefs.setString('api_user', jsonEncode(user));
    connectWebSocket();
  }

  Future<void> clearSession() async {
    _token = null;
    _currentUser = null;
    _wsChannel?.sink.close();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
    await prefs.remove('api_user');
  }

  void connectWebSocket() {
    if (currentTenantId.isEmpty) return;
    try {
      _wsChannel?.sink.close();
      final uri = Uri.parse('$wsUrl/ws/$currentTenantId');
      _wsChannel = WebSocketChannel.connect(uri);

      _wsChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message.toString());
            if (data is Map<String, dynamic>) {
              _realtimeEventsController.add(data);
            }
          } catch (e) {
            // ignore malformed ws message
          }
        },
        onError: (err) {
          // Reconnect logic if needed
          Future.delayed(const Duration(seconds: 3), () => connectWebSocket());
        },
        onDone: () {
          // Reconnect on disconnect
          Future.delayed(const Duration(seconds: 3), () => connectWebSocket());
        },
      );
    } catch (e) {
      // WebSocket connection attempt error
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    Uri uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final response = await http.get(uri, headers: _headers);
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.post(
      uri,
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.put(
      uri,
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.delete(uri, headers: _headers);
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      String msg = 'Request failed with status ${response.statusCode}';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err.containsKey('detail')) {
          msg = err['detail'];
        }
      } catch (_) {}
      throw Exception(msg);
    }
  }
}
