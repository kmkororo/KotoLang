/// What the phone does under the voice, and when an answer lands.
///
/// The vibration motor, in milliseconds: a buzz on each stressed word as it
/// is said, and a double buzz for a right answer. A wrong answer is not felt:
/// it is said on the screen, and a buzz for it read as a telling-off, and short runs for the moments between. The
/// screen's own haptics were tried first and needed no permission, but they
/// go silent wherever touch feedback is switched off — which on the phone
/// this was built on, it was — so the app asks for VIBRATE, its one
/// permission.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The patterns, on and off in milliseconds, as `navigator.vibrate` takes
/// them.
const feelStress = [70];
/// Two buzzes, the second longer. A single short one was evened out by the
/// phone into something too faint to notice.
const feelRight = [60, 70, 110];
const feelRestate = [60, 60, 60];
const feelFinished = [40, 60, 40, 60, 40];

class Feel {
  static const _channel = MethodChannel('kotolang/feel');

  /// Off when the learner has turned vibration off.
  bool enabled;
  Feel({this.enabled = true});

  Future<void> _buzz(List<int> pattern) async {
    if (!enabled) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('vibrate', pattern);
        return;
      } on MissingPluginException {
        // Under test, or a build without the channel: fall through.
      } catch (_) {
        return;
      }
    }
    // Elsewhere, the nearest the platform offers.
    try {
      final long = pattern.length == 1 && pattern.first >= 70;
      await (long ? HapticFeedback.heavyImpact() : HapticFeedback.selectionClick());
    } catch (_) {}
  }

  /// One word as it is said. Only the stressed ones are felt: a buzz on
  /// every word and a longer one on the stressed was tried on a phone, and the
  /// two could not be told apart — the phone evens short buzzes out to one
  /// length of its own. The rhythm of the stresses alone is what comes through.
  void word({required bool stressed}) {
    if (stressed) _buzz(feelStress);
  }

  void right() => _buzz(feelRight);

  /// The line is coming again, in other words.
  Future<void> restate() => _buzz(feelRestate);

  /// The question is over.
  Future<void> finished() => _buzz(feelFinished);
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
