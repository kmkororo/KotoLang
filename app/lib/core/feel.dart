/// What the phone does under the voice, and when an answer lands.
///
/// View haptics only, which need no permission: a light tap for each word as
/// it is said and a heavy one for a stressed word, the platform's own confirm
/// and reject for a verdict, and short runs of taps for the moments between.
/// The kinds are what the platform offers; lengths in milliseconds would need
/// the VIBRATE permission, and this app has none.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Feel {
  static const _channel = MethodChannel('kotolang/feel');

  /// Off when the learner has turned vibration off.
  bool enabled;
  Feel({this.enabled = true});

  Future<void> _tap(String kind) async {
    if (!enabled) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('feel', kind);
        return;
      } on MissingPluginException {
        // Under test, or a build without the channel: fall through.
      } catch (_) {
        return;
      }
    }
    try {
      await switch (kind) {
        'word' => HapticFeedback.selectionClick(),
        'stress' || 'reject' => HapticFeedback.heavyImpact(),
        'confirm' => HapticFeedback.mediumImpact(),
        _ => HapticFeedback.lightImpact(),
      };
    } catch (_) {}
  }

  /// One word as it is said.
  void word({required bool stressed}) => _tap(stressed ? 'stress' : 'word');

  void right() => _tap('confirm');
  void wrong() => _tap('reject');

  /// Three quick taps: the line is coming again, in other words.
  Future<void> restate() => _run(3, const Duration(milliseconds: 120));

  /// Five: the question is over.
  Future<void> finished() => _run(5, const Duration(milliseconds: 100));

  Future<void> _run(int n, Duration gap) async {
    for (var i = 0; i < n; i++) {
      if (i > 0) await Future<void>.delayed(gap);
      unawaited(_tap('tick'));
    }
  }
}

/// Tells the question screen when the listening has been cut short:
/// headphones pulled out, or the sound taken by something else. Held only
/// while a line is being heard or answered.
class AudioGuard {
  static const _channel = MethodChannel('kotolang/audio');
  final _cuts = StreamController<String>.broadcast();

  AudioGuard() {
    try {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'interrupted') _cuts.add('${call.arguments}');
      });
    } catch (_) {}
  }

  Stream<String> get cuts => _cuts.stream;

  Future<void> hold() => _call('hold');
  Future<void> release() => _call('release');

  Future<void> _call(String method) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod(method);
    } catch (_) {}
  }
}
