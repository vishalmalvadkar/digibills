import 'dart:async';
import 'package:universal_html/html.dart' as html;

class NetworkStatus {
  static bool get isOnline => html.window.navigator.onLine ?? true;

  static final StreamController<bool> _controller = StreamController<bool>.broadcast(
    onListen: () {
      _startListening();
    },
    onCancel: () {
      _stopListening();
    },
  );

  static StreamSubscription? _onlineSub;
  static StreamSubscription? _offlineSub;

  static void _startListening() {
    _onlineSub = html.window.onOnline.listen((_) => _controller.add(true));
    _offlineSub = html.window.onOffline.listen((_) => _controller.add(false));
  }

  static void _stopListening() {
    _onlineSub?.cancel();
    _offlineSub?.cancel();
  }

  static Stream<bool> get onChange => _controller.stream;
}
