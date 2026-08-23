/// Text sent to KotoLang from another app.
///
/// The whole material flow depends on getting a long AI reply out of a chat
/// app, and on a phone the clipboard is the weak link: selection handles will
/// not span ten thousand characters, and the block copy button is not always
/// there. Sharing sidesteps all of it — the assistant's own app hands the text
/// over directly.
///
/// Android only. iOS would need a separate share extension, so on every other
/// platform this is inert and the clipboard path stands unchanged.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ShareIntake {
  static const _channel = MethodChannel('kotolang/share');

  final _controller = StreamController<String>.broadcast();

  /// Text shared while the app was already running.
  Stream<String> get stream => _controller.stream;

  bool _started = false;

  /// Begins listening, and returns anything that arrived before Dart was ready
  /// — a share that cold-starts the app is delivered long before this runs.
  Future<String?> start() async {
    if (!_supported) return null;
    if (!_started) {
      _started = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'sharedText') {
          final text = call.arguments as String?;
          if (text != null && text.trim().isNotEmpty) _controller.add(text);
        }
        return null;
      });
    }
    return take();
  }

  /// Collects and clears whatever the platform is holding.
  Future<String?> take() async {
    if (!_supported) return null;
    try {
      final text = await _channel.invokeMethod<String>('takeSharedText');
      return (text != null && text.trim().isNotEmpty) ? text : null;
    } on MissingPluginException {
      return null; // running under a test harness, or on a build without it
    } on PlatformException {
      return null;
    }
  }

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void dispose() => _controller.close();
}
