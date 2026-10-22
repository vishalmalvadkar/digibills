import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class BeepHelper {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Short Beep Sound (WAV Base64)
  static const String _beepBase64 = "UklGRl9vT19XQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YTdvT197e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3v7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e3t7e4=";

  Future<void> playBeep() async {
    try {
      if (kIsWeb) {
        // Web Implementation using HTML Audio Element for reliability
        final audio = html.AudioElement();
        audio.src = "data:audio/wav;base64,$_beepBase64";
        audio.play();
      } else {
        // Mobile Implementation using AudioPlayers with BytesSource
        final Uint8List bytes = base64Decode(_beepBase64);
        await _audioPlayer.play(BytesSource(bytes));
      }
    } catch (e) {
      debugPrint("Error playing beep: $e");
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
