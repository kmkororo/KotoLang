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
  /// Region first, then quality: a learner who never chose a voice should
  /// hear American or British English, not whichever regional voice the
  /// phone happens to list first.
  int _score(Voice v) {
    final n = v.name.toLowerCase();
    final l = v.locale.toLowerCase().replaceAll('_', '-');
    var s = 0;
    if (l.startsWith('en-us')) s += 200;
    if (l.startsWith('en-gb')) s += 150;
    if (n.contains('neural') || n.contains('natural')) s += 45;
    if (n.contains('google')) s += 35;
    if (n.contains('enhanced') || n.contains('premium')) s += 30;
    if (n.contains('network')) s += 20;
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
    _applied = v;
    await _applyVoice(v);
  }

  /// The voice currently applied on the engine, which may be a scene's rather
  /// than the chosen one. Tracked so the chosen voice is put back before the
  /// next ordinary utterance without an extra platform call every time.
  Voice? _applied;

  /// A voice for one scene, picked deterministically from the English voices
  /// on the device so the same scene always sounds like the same person and
  /// two scenes sound like two. With one voice, or none, this is the chosen
  /// voice — the caller need not care.
  Voice? voiceFor(int seed) {
    final chosen = _chosen;
    if (_voices.isEmpty || chosen == null) return chosen;
    // Only voices from the chosen voice's region: a scene may sound like a
    // different person, never like a different country.
    final region = chosen.locale.toLowerCase().replaceAll('_', '-');
    final pool = _voices
        .where((v) => v.locale.toLowerCase().replaceAll('_', '-') == region)
        .toList();
    if (pool.length <= 1) return chosen;
    return pool[seed.abs() % pool.length];
  }

  /// [rate] is the app's own 0.6–1.2 scale, mapped onto the platform range.
  /// [voice] speaks this line in another of the device's voices; the chosen
  /// voice is restored for the next line spoken without one.
  Future<void> speak(String text, {double rate = 1.0, Voice? voice}) async {
    if (!available || text.trim().isEmpty) return;
    try {
      await _tts.stop();
      final want = voice ?? _chosen;
      if (want != null && want.name != _applied?.name) {
        await _applyVoice(want);
        _applied = want;
      }
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
