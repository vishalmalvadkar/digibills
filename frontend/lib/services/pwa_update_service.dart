import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class PwaUpdateService {
  static final PwaUpdateService _instance = PwaUpdateService._internal();

  factory PwaUpdateService() {
    return _instance;
  }

  PwaUpdateService._internal();

  final ValueNotifier<bool> updateAvailable = ValueNotifier<bool>(false);
  dynamic _waitingWorker;

  void init() {
    if (!kIsWeb) return;

    runZonedGuarded(() {
      try {
        final nav = html.window.navigator;
        final sw = nav.serviceWorker;
        if (sw == null) return;

        Future.delayed(const Duration(seconds: 1), () async {
          try {
            final dynamic reg = await sw.getRegistration().catchError((_) => null);
            if (reg == null) return;

            if (reg is html.ServiceWorkerRegistration) {
              if (reg.waiting != null) {
                _waitingWorker = reg.waiting;
                updateAvailable.value = true;
              }
              reg.addEventListener('updatefound', (event) {
                final newWorker = reg.installing;
                if (newWorker != null) {
                  newWorker.addEventListener('statechange', (event) {
                    if (newWorker.state == 'installed' && sw.controller != null) {
                      _waitingWorker = newWorker;
                      updateAvailable.value = true;
                    }
                  });
                }
              });
            }
          } catch (_) {
            // Dev web / localhost service worker registration absence is normal
          }
        });
      } catch (_) {
        // Ignore unsupported web environments
      }
    }, (error, stack) {
      // Discard silent PWA registration errors
    });
  }

  void reloadApp() {
    if (_waitingWorker != null) {
      try {
        _waitingWorker.postMessage({'type': 'SKIP_WAITING'});
      } catch (_) {}
    }
    try {
      html.window.location.reload();
    } catch (_) {}
  }
}
