/// The string catalogue is hand-maintained, so these tests are the contract:
/// every supported language must define every key, with no leftovers, no empty
/// values, and no placeholder drift between locales.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/core/l10n/languages.dart';
import 'package:kotolang/core/l10n/strings.dart';
import 'package:kotolang/domain/field.dart';
import 'package:kotolang/domain/ladder.dart';
import 'package:kotolang/domain/progress_service.dart';
import 'package:kotolang/domain/tree.dart';

void main() {
  test('every supported language has an entry', () {
    for (final lang in supportedLanguages) {
      final s = S(lang.code);
      expect(s.code, lang.code, reason: '${lang.code} is missing a catalogue');
      // If the catalogue were absent it would silently fall back to English.
      expect(s.t('continueLabel'), isNotEmpty);
    }
  });

  test('every key the code asks for exists in the catalogue', () {
    // The catalogue falls back to English, and a key that is in no catalogue
    // at all falls back to itself — so a typo shows up on screen as a raw
    // identifier like "close" rather than as a crash. This is the only thing
    // that catches it.
    final asked = <String, List<String>>{};
    // Everything up to the first comma of a t() call — the key argument. A
    // key is often chosen there rather than written out, as
    // `t(x ? 'a' : 'b')`, and one that matched only a bare `t('a')` walked
    // straight past both arms: the screen showed "sceneListening" where a
    // word belongs, and nothing failed. Stopping at the comma keeps the
    // placeholder names out of it.
    final call = RegExp(r"""\.t\(\s*([^,)]*)""");
    final literal = RegExp(r"""'([A-Za-z_][A-Za-z0-9_]*)'""");
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final m in call.allMatches(file.readAsStringSync())) {
        for (final k in literal.allMatches(m.group(1)!)) {
          (asked[k.group(1)!] ??= []).add(file.path);
        }
      }
    }
    expect(asked, isNotEmpty, reason: 'the scan found nothing to check');

    final unknown = {
      for (final e in asked.entries)
        if (!S.keys.contains(e.key)) e.key: e.value.toSet().toList()
    };
    expect(unknown, isEmpty, reason: 'keys with no catalogue entry: $unknown');
  });

  test('every language defines every key, non-empty', () {
    final missing = <String, List<String>>{};
    final blank = <String, List<String>>{};

    for (final lang in supportedLanguages) {
      final s = S(lang.code);
      for (final key in S.keys) {
        // t() falls back to English, so compare against a deliberately absent
        // key to detect a genuinely missing entry.
        final value = s.t(key);
        if (value == key) {
          (missing[lang.code] ??= []).add(key);
        } else if (value.trim().isEmpty) {
          (blank[lang.code] ??= []).add(key);
        }
      }
    }

    expect(missing, isEmpty, reason: 'keys resolving to their own name: $missing');
    expect(blank, isEmpty, reason: 'empty values: $blank');
  });

  test('every language actually carries every key, not just English', () {
    // The test above cannot see this: t() falls back to English, so a key
    // nobody translated still returns a real sentence — in the wrong language,
    // on a screen that otherwise reads correctly. Only the catalogue itself
    // knows the difference.
    final untranslated = <String, int>{};
    for (final lang in supportedLanguages) {
      final have = S.debugKeysFor(lang.code);
      final gaps = S.keys.where((k) => !have.contains(k)).toList();
      if (gaps.isNotEmpty) untranslated[lang.code] = gaps.length;
    }
    expect(untranslated, isEmpty,
        reason: 'keys falling back to English: $untranslated');
  });

  test('no language carries keys the app never asks for', () {
    // Guards against typos that would silently never render.
    final known = S.keys.toSet();
    for (final lang in supportedLanguages) {
      final extra = S.debugKeysFor(lang.code).difference(known);
      expect(extra, isEmpty, reason: '${lang.code} has unused keys: $extra');
    }
  });

  test('placeholders match English in every language', () {
    final placeholder = RegExp(r'\{(\w+)\}');
    Set<String> varsOf(String s) =>
        placeholder.allMatches(s).map((m) => m.group(1)!).toSet();

    final en = S('en');
    final problems = <String>[];

    for (final lang in supportedLanguages.where((l) => l.code != 'en')) {
      final s = S(lang.code);
      for (final key in S.keys) {
        final want = varsOf(en.t(key));
        final got = varsOf(s.t(key));
        if (want.difference(got).isNotEmpty || got.difference(want).isNotEmpty) {
          problems.add('${lang.code}/$key: expected $want, found $got');
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('substitution fills every placeholder', () {
    final s = S('en');
    final out = s.t('sceneResultBreakdown', {'g': 2, 'r': 3, 'n': 4});
    expect(out.contains('2'), isTrue);
    expect(out.contains('3'), isTrue);
    expect(out.contains('4'), isTrue);
    expect(out.contains('{'), isFalse, reason: 'a placeholder was left unfilled');
  });

  test('substitution accepts a value whose type is only known at runtime', () {
    // Screens hold the catalogue in a `dynamic`, so `s.t(...)` returns dynamic
    // and a literal built from one infers Map<String, dynamic>. That used to
    // fail the cast inside t() and take the quiz screen down mid-session.
    final dynamic s = S('en');
    final out = s.t('stageUpBody', {'stage': s.t('stageSprout')});
    expect(out.contains('{'), isFalse, reason: 'a placeholder was left unfilled');
    expect(out.contains(S('en').t('stageSprout')), isTrue);
  });

  test('an unknown language falls back to English rather than breaking', () {
    final s = S('xx-YY');
    expect(s.t('continueLabel'), S('en').t('continueLabel'));
  });

  group('device locale resolution', () {
    test('exact and partial matches', () {
      expect(resolveDeviceLanguage('ja', 'JP'), 'ja');
      expect(resolveDeviceLanguage('pt', 'BR'), 'pt-BR');
      expect(resolveDeviceLanguage('pt', 'PT'), 'pt-BR', reason: 'nearest supported');
      expect(resolveDeviceLanguage('zh', 'CN'), 'zh-CN');
      expect(resolveDeviceLanguage('zh', 'TW'), 'zh-CN', reason: 'nearest supported');
      expect(resolveDeviceLanguage('de', null), 'de');
    });

    test('unsupported locales fall back to English', () {
      expect(resolveDeviceLanguage('sv', 'SE'), 'en');
      expect(resolveDeviceLanguage(null, null), 'en');
    });
  });

  test('language metadata is well formed', () {
    final codes = <String>{};
    for (final l in supportedLanguages) {
      expect(codes.add(l.code), isTrue, reason: 'duplicate code ${l.code}');
      expect(l.endonym, isNotEmpty);
      expect(l.englishName, isNotEmpty);
      expect(l.flag, isNotEmpty);
      // The endonym is what a speaker scans for, so it must not be English
      // unless the language itself is English.
      if (l.code != 'en') {
        expect(l.endonym, isNot(l.englishName),
            reason: '${l.code} should be shown in its own script');
      }
    }
    expect(supportedLanguages.length, 10);
  });

  test('every key built from a name has an entry', () {
    // The scan above only sees a key written out in full. These four families
    // are put together where they are used — 'axis_$name', 'treeStage$n' — so
    // a gap in one of them reaches the screen as a raw identifier with
    // nothing to catch it. Each family is small and countable, so it is
    // counted.
    final built = <String>[
      for (final a in LadderAxis.values) 'axis_${a.name}',
      for (var n = 0; n < treeNames; n++) 'treeStage$n',
      for (final id in builtinFieldIds) 'interest_$id',
      for (final b in ageBands) 'age_${b.replaceAll('+', 'plus')}',
      'window_short', 'window_normal', 'window_long', 'window_longest',
    ];
    final unknown = built.toSet().where((k) => !S.keys.contains(k)).toList();
    expect(unknown, isEmpty, reason: 'built keys with no entry: $unknown');
  });
}
