import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class PwaUpdateService {
  static final PwaUpdateService _instance = PwaUpdateService._internal();

  factory PwaUpdateService() {
    return _instance;
  }

  PwaUpdateService._internal();

  final ValueNotifier<bool> updateAvailable = ValueNotifier<bool>(false);
  html.ServiceWorker? _waitingWorker;

  void init() {
    if (!kIsWeb) return;

    // Check if serviceWorker is supported
    if (html.window.navigator.serviceWorker == null) return;

    html.window.navigator.serviceWorker!.getRegistration().then((registration) {
      if (registration != null) {
        // 1. Check if there's already a waiting worker
        if (registration.waiting != null) {
          _waitingWorker = registration.waiting;
          updateAvailable.value = true;
        }

        // 2. Listen for new updates
        registration.addEventListener('updatefound', (event) {
          final newWorker = registration.installing;
          if (newWorker != null) {
            newWorker.addEventListener('statechange', (event) {
              if (newWorker.state == 'installed' &&
                  html.window.navigator.serviceWorker!.controller != null) {
                _waitingWorker = newWorker;
                updateAvailable.value = true;
              }
            });
          }
        });
      }
    });
  }

  void reloadApp() {
    if (_waitingWorker != null) {
      // Send skipWaiting message to the waiting worker
      _waitingWorker!.postMessage({'type': 'SKIP_WAITING'});
    }
    
    // Force reload to pick up the new version
    // We give it a tiny delay to ensure the message is processed if needed, 
    // though typically the controller change will trigger behavior.
    
    // Note: Standard PWA logic often listens to 'controllerchange' to reload, 
    // but a manual reload is also safe and explicit here.
    html.window.location.reload();
  }
}
