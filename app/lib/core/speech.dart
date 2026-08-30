/// Text to speech. Playback only — KotoLang never records audio, so the app
/// needs no microphone permission.
///
/// Everything here degrades quietly: a device with no English voice must still
/// be fully usable by reading, so nothing throws and the caller is simply told
/// whether audio is available.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class Voice {
  final String name;
  final String locale;
  const Voice(this.name, this.locale);
}

class SpeechService {
  final FlutterTts _tts = FlutterTts();

  List<Voice> _voices = const [];
  Voice? _chosen;
  bool _ready = false;
  bool _supported = true;

  List<Voice> get voices => _voices;
  Voice? get chosen => _chosen;
  bool get available => _supported && _voices.isNotEmpty;
  bool get supported => _supported;

  Future<void> init({String? preferredVoice}) async {
    if (_ready) return;
    _ready = true;
    try {
      await _iosAudioSession();
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5); // flutter_tts scale, adjusted per call
      await _tts.awaitSpeakCompletion(true);

      // Some engines never answer this; give up rather than hang.
      final raw = await _tts.getVoices.timeout(const Duration(seconds: 5));
      final list = <Voice>[];
      if (raw is List) {
        for (final v in raw) {
          if (v is Map) {
            final name = '${v['name'] ?? ''}';
            final locale = '${v['locale'] ?? ''}';
            if (name.isEmpty) continue;
            // Only English voices: a Japanese engine reading English is what
            // produces the katakana-sounding output learners complain about.
            if (!RegExp(r'^en[-_]', caseSensitive: false).hasMatch(locale)) continue;
            list.add(Voice(name, locale));
          }
        }
      }
      list.sort((a, b) => _score(b).compareTo(_score(a)));
      _voices = list;

      if (preferredVoice != null) {
        _chosen = list.where((v) => v.name == preferredVoice).firstOrNull;
      }
      _chosen ??= list.firstOrNull;
      if (_chosen != null) await _applyVoice(_chosen!);
    } catch (e) {
      _supported = false;
      debugPrint('[KotoLang] speech unavailable: $e');
    }
  }


  /// Puts iOS into the audio category this app actually needs.
  ///
  /// Without it the reading is governed by the ring/silent switch: a learner
  /// with the switch down hears nothing at all and is given no reason why,
  /// which for a listening app is the whole thing broken. `playback` keeps the
  /// speech audible with the switch down and the screen locked, and ducking
  /// means a podcast in the background drops instead of being cut off.
  ///
  /// Android needs none of this, and the methods do not exist there.
  Future<void> _iosAudioSession() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowAirPlay,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    } catch (e) {
      // A session we could not configure still speaks, just under whatever
      // category the system picked. Not worth failing the whole service for.
      debugPrint('[KotoLang] iOS audio session not configured: $e');
    }
  }

  /// Ranks by the markers that correlate with natural-sounding output.
  int _score(Voice v) {
    final n = v.name.toLowerCase();
    var s = 0;
    if (n.contains('neural') || n.contains('natural')) s += 45;
    if (n.contains('google')) s += 35;
    if (n.contains('enhanced') || n.contains('premium')) s += 30;
    if (n.contains('network')) s += 20;
    if (v.locale.toLowerCase().startsWith('en-us')) s += 6;
    if (v.locale.toLowerCase().startsWith('en-gb')) s += 4;
    return s;
  }

  Future<void> _applyVoice(Voice v) async {
    try {
      await _tts.setVoice({'name': v.name, 'locale': v.locale});
    } catch (e) {
      debugPrint('[KotoLang] could not set voice: $e');
    }
  }

  Future<void> setVoice(String name) async {
    final v = _voices.where((x) => x.name == name).firstOrNull;
    if (v == null) return;
    _chosen = v;
    await _applyVoice(v);
  }

  /// [rate] is the app's own 0.6–1.2 scale, mapped onto the platform range.
  Future<void> speak(String text, {double rate = 1.0}) async {
    if (!available || text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.setSpeechRate((rate * 0.5).clamp(0.1, 1.0));
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[KotoLang] speak failed: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
