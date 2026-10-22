import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class PwaUpdateHelper {
  static final StreamController<bool> _updateAvailableCtrl = StreamController<bool>.broadcast();
  static Stream<bool> get onUpdateAvailable => _updateAvailableCtrl.stream;

  static void init() {
    if (!kIsWeb) return;

    try {
      // Use dynamic to bypass strict typing issues with universal_html/service workers
      final nav = html.window.navigator as dynamic;
      final sw = nav.serviceWorker;
      
      if (sw != null) {
        sw.ready.then((registration) {
           final reg = registration as dynamic;
           // Force check for update immediately
           reg.update(); 
           
           reg.onUpdateFound.listen((event) {
             final newWorker = reg.installing;
             if (newWorker != null) {
               newWorker.onStateChange.listen((stateEvent) {
                  if (newWorker.state == 'installed' && sw.controller != null) {
                     // New content is available; please refresh.
                     if (!_updateAvailableCtrl.isClosed) {
                        _updateAvailableCtrl.add(true);
                     }
                  }
               });
             }
           });
        });
      }
    } catch (e) {
      debugPrint('PWA Update Helper Error: $e');
    }
  }

  static void reload() {
    if (kIsWeb) {
      html.window.location.reload();
    }
  }
}
