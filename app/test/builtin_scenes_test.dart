/// The scenes that ship with the app, in every interface language: each one
/// must be a sound scene by the importer's own rules, every language must
/// carry the same ids as English, and the shuffle that places the right
/// answer must be spread out and agree across languages.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:kotolang/core/l10n/languages.dart';
import 'package:kotolang/data/builtin_scenes.dart';
import 'package:kotolang/data/builtin_scenes_data.dart' as data;
import 'package:kotolang/domain/scene.dart';
import 'package:kotolang/domain/scene_import.dart';

void main() {
  final codes = [for (final l in supportedLanguages) l.code];

  test('every language has scenes, and each passes the importer', () {
    for (final code in codes) {
      final raw = data.scenesFor(code);
      expect(raw, isNotEmpty, reason: code);
      final out = normaliseScenes({'scenes': raw});
      expect(out.rejected, isEmpty,
          reason: '$code: ${out.rejected.map((r) => '${r.topic} (${r.reason})').join('; ')}');
      expect(out.scenes.length, raw.length, reason: code);
      // The normaliser derives ids from the topic; the app keeps the fixed
      // built-in ids, so the per-scene checks run on what the app sees.
      for (final s in builtinScenes(code)) {
        expect(s.source, SceneSource.builtin, reason: '$code ${s.id}');
        expect(data.kindOf(s.id), isNotEmpty, reason: '$code ${s.id}');
        expect(s.topicNative.isNotEmpty || code == 'en', isTrue, reason: '$code ${s.id}');
        expect(s.settingNative, isNotEmpty, reason: '$code ${s.id}');
        for (final x in s.exchanges) {
          expect(x.lineNative.isNotEmpty || code == 'en', isTrue, reason: '$code ${s.id}');
          for (final o in x.reply.options) {
            expect(o.why, isNotEmpty, reason: '$code ${s.id}: ${o.text}');
            expect(o.native.isNotEmpty || code == 'en', isTrue,
                reason: '$code ${s.id}: ${o.text}');
          }
        }
      }
    }
  });

  test('English and Japanese carry thirty; the others ten, all drawn from the thirty', () {
    final en = {for (final s in builtinScenes('en')) s.id};
    expect(en.length, 30);
    expect(builtinScenes('ja').length, 30);
    for (final code in codes.where((c) => c != 'en' && c != 'ja')) {
      final ids = {for (final s in builtinScenes(code)) s.id};
      expect(ids.length, 10, reason: code);
      expect(en.containsAll(ids), isTrue, reason: code);
    }
    expect(en.where((id) => data.kindOf(id) == 'work').length, 10);
    expect(en.where((id) => data.kindOf(id) == 'travel').length, 10);
    expect(en.where((id) => data.kindOf(id) == 'school').length, 5);
    expect(en.where((id) => data.kindOf(id) == 'daily').length, 5);
  });

  test('the right answer sits in every position, and in the same one everywhere', () {
    final en = {for (final s in builtinScenes('en')) s.id: s};
    final seen = <int>{};
    for (final s in en.values) {
      for (final x in s.exchanges) {
        seen.add(x.gist.answer);
        seen.add(x.reply.answer);
      }
    }
    expect(seen, {0, 1, 2});

    for (final code in codes) {
      for (final s in builtinScenes(code)) {
        final ref = en[s.id]!;
        for (var i = 0; i < s.exchanges.length; i++) {
          expect(s.exchanges[i].gist.answer, ref.exchanges[i].gist.answer,
              reason: '$code ${s.id} $i');
          expect(s.exchanges[i].reply.answer, ref.exchanges[i].reply.answer,
              reason: '$code ${s.id} $i');
          // The English of the replies is the same text in every language.
          expect([for (final o in s.exchanges[i].reply.options) o.text],
              [for (final o in ref.exchanges[i].reply.options) o.text],
              reason: '$code ${s.id} $i');
        }
      }
    }
  });

  test('the lines stay short and never name anyone', () {
    final titles = RegExp(r'\b(Mr|Mrs|Ms|Dr|Sir|Madam)\b');
    for (final s in builtinScenes('en')) {
      for (final x in s.exchanges) {
        expect(x.line.split(' ').length, lessThanOrEqualTo(40), reason: '${s.id}: ${x.line}');
        expect(titles.hasMatch(x.line), isFalse, reason: '${s.id}: ${x.line}');
        for (final o in x.reply.options) {
          expect(o.text.split(' ').length, lessThanOrEqualTo(24), reason: '${s.id}: ${o.text}');
        }
      }
    }
  });

  test('interests put the chosen kinds first; the tutorial is a work scene', () {
    final travelFirst = builtinScenes('ja', interests: ['travel', 'work']);
    expect(data.kindOf(travelFirst.first.id), 'travel');
    expect(data.kindOf(travelFirst[10].id), 'work');
    expect(data.kindOf(travelFirst.last.id), isIn(['school', 'daily']));

    expect(tutorialScene('ja')!.id, 'builtin_w1');
    expect(tutorialScene('hi')!.id, 'builtin_w1');
    expect(builtinTopics().length, 30);
  });
}
