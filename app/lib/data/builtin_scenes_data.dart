/// The built-in scenes as data, one list per interface language.
///
/// Ids are fixed across languages ("builtin_w1" is the same scene in every
/// language), because results and reviews are keyed by them. Filled in by
/// the built-in content step; until then there is nothing here, and the app
/// simply has no samples.
library;

/// The scene lists by language code. English is the fallback.
const Map<String, List<Map<String, dynamic>>> _byLanguage = {};

/// Which kind of life a built-in scene belongs to — 'work', 'travel',
/// 'school', 'daily' — by its id prefix.
String kindOf(String id) {
  if (id.startsWith('builtin_w')) return 'work';
  if (id.startsWith('builtin_t')) return 'travel';
  if (id.startsWith('builtin_s')) return 'school';
  if (id.startsWith('builtin_d')) return 'daily';
  return '';
}

List<Map<String, dynamic>> scenesFor(String lang) =>
    _byLanguage[lang] ?? _byLanguage['en'] ?? const [];
