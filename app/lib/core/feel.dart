/// What the phone does under the voice, and when an answer lands.
///
/// The vibration motor, in milliseconds: a short buzz for each word as it is
/// said and a longer one for a stressed word, one short for a right answer and
/// one long for a wrong one, and short runs for the moments between. The
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
const feelWord = [20];
const feelStress = [70];
const feelRight = [45];
const feelWrong = [420];
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

  /// One word as it is said.
  void word({required bool stressed}) => _buzz(stressed ? feelStress : feelWord);

  void right() => _buzz(feelRight);
  void wrong() => _buzz(feelWrong);

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
