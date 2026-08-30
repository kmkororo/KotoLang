/// Interface languages KotoLang can present itself in.
///
/// This is deliberately separate from the *learning* language. KotoLang teaches
/// English; the UI language is whatever the learner reads most comfortably. The
/// distinction matters beyond labels: the AI prompts ask for translations and
/// distractors in the UI language, so a Spanish speaker studying English gets
/// Spanish glosses rather than Japanese ones.
library;

import 'dart:ui' show Locale;

class UiLanguage {
  /// BCP-47 tag used for the Flutter locale and for addressing the AI.
  final String code;

  /// Endonym — always shown in the language's own script, so a speaker can find
  /// it without being able to read the current interface language.
  final String endonym;

  /// English name, used in prompts sent to the AI.
  final String englishName;

  final String flag;

  const UiLanguage({
    required this.code,
    required this.endonym,
    required this.englishName,
    required this.flag,
  });

  /// The subtag Flutter needs for `Locale(languageCode, countryCode)`.
  String get languageCode => code.split('-').first;
  String? get countryCode {
    final parts = code.split('-');
    return parts.length > 1 ? parts.last : null;
  }

  /// The locale handed to Flutter. Text rendering depends on this: it is the
  /// only signal the font engine gets about which script a run of CJK
  /// characters belongs to.
  Locale get locale => Locale(languageCode, countryCode);
}

const supportedLanguages = <UiLanguage>[
  UiLanguage(code: 'ja', endonym: '日本語', englishName: 'Japanese', flag: '🇯🇵'),
  UiLanguage(code: 'en', endonym: 'English', englishName: 'English', flag: '🇺🇸'),
  UiLanguage(code: 'es', endonym: 'Español', englishName: 'Spanish', flag: '🇪🇸'),
  UiLanguage(
      code: 'pt-BR',
      endonym: 'Português (Brasil)',
      englishName: 'Brazilian Portuguese',
      flag: '🇧🇷'),
  UiLanguage(code: 'fr', endonym: 'Français', englishName: 'French', flag: '🇫🇷'),
  UiLanguage(code: 'de', endonym: 'Deutsch', englishName: 'German', flag: '🇩🇪'),
  UiLanguage(code: 'ko', endonym: '한국어', englishName: 'Korean', flag: '🇰🇷'),
  UiLanguage(
      code: 'zh-CN',
      endonym: '简体中文',
      englishName: 'Simplified Chinese',
      flag: '🇨🇳'),
  UiLanguage(code: 'hi', endonym: 'हिन्दी', englishName: 'Hindi', flag: '🇮🇳'),
  UiLanguage(
      code: 'id',
      endonym: 'Bahasa Indonesia',
      englishName: 'Indonesian',
      flag: '🇮🇩'),
];

const fallbackLanguage = 'en';

UiLanguage languageFor(String code) => supportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => supportedLanguages.firstWhere((l) => l.code == fallbackLanguage),
    );

/// Best match for the device locale, used to preselect a row on the very first
/// screen. Falls back to English rather than guessing.
String resolveDeviceLanguage(String? languageCode, String? countryCode) {
  if (languageCode == null) return fallbackLanguage;
  final exact = '$languageCode${countryCode != null ? '-$countryCode' : ''}';
  for (final l in supportedLanguages) {
    if (l.code.toLowerCase() == exact.toLowerCase()) return l.code;
  }
  for (final l in supportedLanguages) {
    if (l.languageCode == languageCode) return l.code;
  }
  return fallbackLanguage;
}
