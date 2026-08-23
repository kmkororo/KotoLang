/// The string catalogue is hand-maintained, so these tests are the contract:
/// every supported language must define every key, with no leftovers, no empty
/// values, and no placeholder drift between locales.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/core/l10n/languages.dart';
import 'package:kotolang/core/l10n/strings.dart';

void main() {
  test('every supported language has an entry', () {
    for (final lang in supportedLanguages) {
      final s = S(lang.code);
      expect(s.code, lang.code, reason: '${lang.code} is missing a catalogue');
      // If the catalogue were absent it would silently fall back to English.
      expect(s.t('continueLabel'), isNotEmpty);
    }
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
    final out = s.t('freezeBannerBody', {'n': 2, 'streak': 9});
    expect(out.contains('2'), isTrue);
    expect(out.contains('9'), isTrue);
    expect(out.contains('{'), isFalse, reason: 'a placeholder was left unfilled');
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
}
