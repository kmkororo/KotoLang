/// Shared primitives ported from the web app's `util.js`.
///
/// Two rules matter here and are relied on everywhere else:
///  * A "day" is a local calendar day, never a timestamp. Streaks and review
///    schedules must agree with the date the learner sees on their phone.
///  * Date arithmetic happens in UTC on a date-only value, so a daylight-saving
///    transition can never make an interval land a day early or late.
library;

import 'dart:math';

// ---------------------------------------------------------------- dates

/// `YYYY-MM-DD` for the given local time (defaults to now).
String dayKey([DateTime? at]) {
  final d = at ?? DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Parses a day key into a UTC midnight instant, purely for arithmetic.
DateTime _parseDay(String key) {
  final p = key.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Whole days from [fromKey] to [toKey]; negative when [toKey] is earlier.
int daysBetween(String fromKey, String toKey) =>
    _parseDay(toKey).difference(_parseDay(fromKey)).inDays;

/// Shifts a day key by [n] days. The maths runs on the UTC date value, so it
/// cannot drift across a daylight-saving boundary.
String addDays(String key, int n) => dayKey(_parseDay(key).add(Duration(days: n)));

String today() => dayKey();

// ---------------------------------------------------------------- text

/// Collapses whitespace and trims. Applied to every string that arrives from
/// an AI response before it is stored.
String clean(Object? s) {
  if (s is! String) return '';
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Comparison key for duplicate detection: case, spacing and punctuation are
/// all ignored, so `Repair Policy` and `repair  policy` collapse together.
String normKey(Object? s) => clean(s)
    .toLowerCase()
    .replaceAll(RegExp(r'[‘’]'), "'")
    .replaceAll(RegExp(r'[“”]'), '"')
    .replaceAll(RegExp(r'''[.,!?;:"()\[\]]'''), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Answer comparison for dictation: forgiving about case, spacing, quotes and
/// hyphenation, but still strict about spelling.
String answerKey(Object? s) => normKey(s)
    .replaceAll(RegExp(r'[-‐-―]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Word-boundary aware containment, tolerant of case and punctuation.
bool containsPhrase(String sentence, String phrase) {
  final p = normKey(phrase);
  if (p.isEmpty) return false;
  return ' ${normKey(sentence)} '.contains(' $p ');
}

// ---------------------------------------------------------------- ids

/// FNV-1a, 32 bit. Enough to key local records; not a security hash.
String hash32(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h + ((h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24))) & 0xffffffff;
  }
  return h.toRadixString(36);
}

/// Content-derived id, so re-importing the same material cannot create a
/// second record under a different key.
String slugId(String prefix, String text) => '${prefix}_${hash32(text)}';

// ---------------------------------------------------------------- collections

final _rng = Random();

List<T> shuffled<T>(Iterable<T> items, [Random? rng]) {
  final list = items.toList();
  final r = rng ?? _rng;
  for (var i = list.length - 1; i > 0; i--) {
    final j = r.nextInt(i + 1);
    final t = list[i];
    list[i] = list[j];
    list[j] = t;
  }
  return list;
}

T? sample<T>(List<T> items, [Random? rng]) =>
    items.isEmpty ? null : items[(rng ?? _rng).nextInt(items.length)];

List<T> take<T>(List<T> items, int n) =>
    items.sublist(0, n < 0 ? 0 : (n > items.length ? items.length : n));

/// Keeps the first occurrence of each key, preserving order.
List<T> uniqueBy<T>(Iterable<T> items, String Function(T) key) {
  final seen = <String>{};
  final out = <T>[];
  for (final x in items) {
    if (seen.add(key(x))) out.add(x);
  }
  return out;
}

Map<K, List<T>> groupBy<T, K>(Iterable<T> items, K Function(T) key) {
  final out = <K, List<T>>{};
  for (final x in items) {
    (out[key(x)] ??= <T>[]).add(x);
  }
  return out;
}

int clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

double clampDouble(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Weighted random pick. Entries with a larger weight come up proportionally
/// more often.
T weightedPick<T>(List<T> items, double Function(T) weight, [Random? rng]) {
  final total = items.fold<double>(0, (a, b) => a + weight(b));
  var r = (rng ?? _rng).nextDouble() * total;
  for (final x in items) {
    r -= weight(x);
    if (r <= 0) return x;
  }
  return items.last;
}

int percent(int ok, int n) => n > 0 ? ((ok / n) * 100).round() : 0;

var _uidCounter = 0;

/// Unique id for records that have no natural content key (import batches,
/// sessions). Content-derived ids use [slugId] instead.
String uid(String prefix) {
  _uidCounter += 1;
  return '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '_${_uidCounter.toRadixString(36)}';
}
