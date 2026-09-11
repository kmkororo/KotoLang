/// Turns a pasted AI reply into stored material.
///
/// Raw text -> extract -> parse -> validate -> normalise -> dedupe -> records.
/// Each stage is separate so a failure can be reported precisely, and nothing
/// here may throw on bad input: an AI that returns prose, truncated JSON or the
/// wrong shape must produce a readable message, never a crash.
library;

import 'dart:convert';
import 'dart:math';

import '../core/util.dart';
import 'scene_import.dart';
import 'models.dart';

/// 1.0 is profile / material / audit; 2.0 added the debate pack. Both are
/// accepted for ever — a learner's old material must keep importing.
const supportedSchemas = ['1.0', '4.0'];
const _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

// ---------------------------------------------------------------- 1. extract

class ExtractResult {
  final Map<String, dynamic>? data;
  final String? failure; // 'empty' | 'parse'
  final String? detail;

  /// True when the text was cut off and had to be closed artificially. The
  /// data is real but incomplete, and the learner is told so.
  final bool repaired;

  const ExtractResult.ok(this.data, {this.repaired = false})
      : failure = null,
        detail = null;
  const ExtractResult.fail(this.failure, [this.detail])
      : data = null,
        repaired = false;
  bool get ok => data != null;
}

/// AI replies routinely wrap JSON in prose or fences, so this tries
/// progressively looser strategies rather than demanding a clean response.
ExtractResult extractJson(String? raw) {
  if (raw == null) return const ExtractResult.fail('empty');
  final text = raw.replaceFirst('﻿', '').trim();
  if (text.isEmpty) return const ExtractResult.fail('empty');

  // The reply as a whole, and the code blocks it may be wrapped in.
  final whole = <String>[text];

  // Fenced blocks, ```json ... ``` or plain ``` ... ```
  for (final m in RegExp(r'```[a-zA-Z]*\s*([\s\S]*?)```').allMatches(text)) {
    final inner = m.group(1)?.trim();
    if (inner != null && inner.isNotEmpty) whole.add(inner);
  }

  // A fence that was opened but never closed — the usual shape of a reply
  // whose tail never arrived.
  final fence = RegExp(r'```[a-zA-Z]*\s*').firstMatch(text);
  if (fence != null && !text.substring(fence.end).contains('```')) {
    whole.add(text.substring(fence.end));
  }

  // Every balanced {...} region, longest first. In a truncated reply these are
  // the individual entries, which parse perfectly but say almost nothing, so
  // they rank below a rescued whole.
  final fragments = _balancedObjects(text);

  String? firstError;
  Map<String, dynamic>? parse(String c) {
    try {
      final parsed = jsonDecode(c);
      return parsed is Map<String, dynamic> ? parsed : null;
    } catch (e) {
      firstError ??= e.toString();
      return null;
    }
  }

  // 1. A clean parse of the reply, or of a block inside it.
  for (final c in whole) {
    final m = parse(c);
    if (m != null && _looksLikePayload(m)) return ExtractResult.ok(m);
  }

  // 2. A clean parse of an embedded object that is itself a whole payload.
  for (final c in fragments) {
    final m = parse(c);
    if (m != null && _looksLikePayload(m)) return ExtractResult.ok(m);
  }

  // 3. The reply is valid JSON that simply stops in the middle: close what is
  //    open and keep everything before the cut.
  for (final c in whole) {
    final mended = repairJson(c);
    if (mended == null) continue;
    final m = parse(mended);
    if (m != null && _looksLikePayload(m)) {
      return ExtractResult.ok(m, repaired: true);
    }
  }

  // 4. Anything at all that decodes to an object. Validation downstream will
  //    say what is wrong with it far more precisely than this could.
  for (final c in [...whole, ...fragments]) {
    final m = parse(c);
    if (m != null) return ExtractResult.ok(m);
  }

  return ExtractResult.fail('parse', firstError);
}

/// Whether a decoded object is a reply rather than one entry lifted out of one.
bool _looksLikePayload(Map<String, dynamic> m) =>
    m.containsKey('schema_version') ||
    m.containsKey('sentences') ||
    m.containsKey('learning_items') ||
    m.containsKey('domains') ||
    m.containsKey('results') ||
    m.containsKey('debates') ||
    m.containsKey('chunks') ||
    m.containsKey('critiques') ||
    m.containsKey('scenes');

// ------------------------------------------------------- truncation rescue

class _Frame {
  final String kind; // '{' or '['
  bool sawColon = false;
  _Frame(this.kind);
}

/// Rebuilds a JSON object that stops part-way through.
///
/// This is the common failure on a phone: a long reply is copied by dragging
/// selection handles and the tail never makes it, or the assistant itself ran
/// out of room. Throwing the whole paste away would also throw away the fifty
/// sentences that arrived intact, so this rolls back to the last complete
/// value and closes whatever is still open. Anything half-written is dropped
/// by the normalisers further down.
///
/// Returns null when there is nothing worth keeping.
String? repairJson(String raw) {
  final start = raw.indexOf('{');
  if (start < 0) return null;

  final open = <_Frame>[];
  var safeEnd = -1;
  var safeStack = '';

  // A position is safe when a complete value has just been read and at least
  // one container is still open — that is exactly where a `,` or a closing
  // bracket could legally follow.
  void markSafe(int end) {
    if (open.isEmpty) return;
    safeEnd = end;
    safeStack = open.map((f) => f.kind).join();
  }

  var i = start;
  while (i < raw.length) {
    final c = raw[i];

    if (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
      i++;
      continue;
    }

    if (c == '{' || c == '[') {
      open.add(_Frame(c));
      i++;
      continue;
    }

    if (c == '}' || c == ']') {
      if (open.isEmpty) break;
      open.removeLast();
      i++;
      // A complete top-level object needs no repair at all.
      if (open.isEmpty) return raw.substring(start, i);
      open.last.sawColon = false;
      markSafe(i);
      continue;
    }

    if (c == ':') {
      if (open.isNotEmpty) open.last.sawColon = true;
      i++;
      continue;
    }

    if (c == ',') {
      if (open.isNotEmpty) open.last.sawColon = false;
      i++;
      continue;
    }

    if (open.isEmpty) break;

    if (c == '"') {
      final end = _endOfString(raw, i);
      if (end < 0) break; // cut off inside a string
      // In an array every string is a value; in an object only one that
      // follows a colon is.
      final isValue = open.last.kind == '[' || open.last.sawColon;
      i = end;
      if (isValue) markSafe(i);
      continue;
    }

    // A number or one of true/false/null.
    final end = _endOfScalar(raw, i);
    if (end <= i) {
      i++;
      continue;
    }
    i = end;
    // A token running to the very end of the text may itself be truncated
    // ("tru", or "12" of "123"), so it is never treated as complete.
    if (end < raw.length) markSafe(i);
  }

  if (safeEnd < 0) return null;

  final buf = StringBuffer(raw.substring(start, safeEnd));
  for (var k = safeStack.length - 1; k >= 0; k--) {
    buf.write(safeStack[k] == '{' ? '}' : ']');
  }
  return buf.toString();
}

/// Index just past the closing quote of the string starting at [i], or -1 if
/// the string never closes.
int _endOfString(String s, int i) {
  var esc = false;
  for (var k = i + 1; k < s.length; k++) {
    final c = s[k];
    if (esc) {
      esc = false;
    } else if (c == r'\') {
      esc = true;
    } else if (c == '"') {
      return k + 1;
    }
  }
  return -1;
}

const _scalarStops = ',}]: \t\r\n';

int _endOfScalar(String s, int i) {
  var k = i;
  while (k < s.length && !_scalarStops.contains(s[k])) {
    k++;
  }
  return k;
}

// ------------------------------------------------------- piecewise pasting

/// The shortest overlap treated as a genuine repeat rather than coincidence.
const _minOverlap = 24;
const _maxOverlap = 4000;

/// Line breaks at the seam. Removed because a piece may well end in the middle
/// of a JSON string, where a raw newline is illegal — and everywhere else in
/// JSON whitespace means nothing. Ordinary spaces are left alone, since they
/// are legal inside a string and might belong to the text.
final _seamTail = RegExp(r'[\r\n\t]+$');
final _seamHead = RegExp(r'^[\r\n\t]+');

/// Adds a freshly pasted piece to what has been collected so far.
///
/// Someone copying a long reply in stages almost never lands the selection on
/// the exact character where the previous piece ended; they overshoot
/// backwards to be safe. A repeated stretch breaks the JSON just as surely as
/// a missing one, so any overlap between the tail of [buffer] and the head of
/// [piece] is removed, and the two are then joined with nothing between them.
String appendPiece(String buffer, String piece) {
  final a = buffer.replaceFirst(_seamTail, '');
  final b = piece.replaceFirst(_seamHead, '').replaceFirst(_seamTail, '');
  if (a.trim().isEmpty) return b;
  if (b.trim().isEmpty) return a;

  final limit = min(min(a.length, b.length), _maxOverlap);
  for (var n = limit; n >= _minOverlap; n--) {
    if (a.endsWith(b.substring(0, n))) return a + b.substring(n);
  }
  return a + b;
}

/// What the collected text currently amounts to, so the paste screen can show
/// progress after each piece instead of only succeeding or failing at the end.
class ImportPreview {
  final bool ok;
  final String? type; // 'profile' | 'scenes'
  final int realms;
  final int scenes;
  final bool repaired;
  const ImportPreview({
    required this.ok,
    this.type,
    this.realms = 0,
    this.scenes = 0,
    this.repaired = false,
  });
  static const none = ImportPreview(ok: false);
}

ImportPreview previewImport(String raw) {
  final ex = extractJson(raw);
  if (!ex.ok) return ImportPreview.none;

  final v = validate(ex.data!);
  switch (v.type) {
    case 'scenes':
      final n = normaliseScenes(ex.data!);
      return ImportPreview(
        ok: v.ok && n.scenes.isNotEmpty,
        type: 'scenes',
        scenes: n.scenes.length,
        repaired: ex.repaired,
      );
    case 'profile':
      final n = normaliseProfile(ex.data!);
      return ImportPreview(
        ok: v.ok,
        type: 'profile',
        realms: n.realms.length,
        repaired: ex.repaired,
      );
    default:
      return ImportPreview.none;
  }
}

/// Brace scanner that respects strings and escapes, so braces inside a text
/// value cannot split the object.
List<String> _balancedObjects(String text) {
  final out = <String>[];
  var depth = 0, start = -1;
  var inStr = false, esc = false;

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inStr) {
      if (esc) {
        esc = false;
      } else if (c == r'\') {
        esc = true;
      } else if (c == '"') {
        inStr = false;
      }
      continue;
    }
    if (c == '"') {
      inStr = true;
    } else if (c == '{') {
      if (depth == 0) start = i;
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0 && start >= 0) {
        out.add(text.substring(start, i + 1));
        start = -1;
      }
      if (depth < 0) depth = 0;
    }
  }
  out.sort((a, b) => b.length.compareTo(a.length));
  return out;
}

// --------------------------------------------------------------- 2. validate

class ValidationResult {
  final bool ok;
  final List<String> errors;
  final String? type;
  const ValidationResult(this.ok, this.errors, this.type);
}

ValidationResult validate(Map<String, dynamic> data) {
  final errors = <String>[];

  final sv = data['schema_version'];
  if (sv == null) {
    errors.add('schema_version is missing');
  } else if (!supportedSchemas.contains('$sv')) {
    errors.add('unsupported schema_version: $sv');
  }

  var type = data['type'] as String?;
  if (type == null || !['profile', 'scenes'].contains(type)) {
    // Inferred when the AI left it out but the shape says which it is.
    if (data.containsKey('scenes')) {
      type = 'scenes';
    } else if (data.containsKey('domains') || data.containsKey('profile')) {
      type = 'profile';
    } else {
      errors.add('type is not profile or scenes');
    }
  }

  switch (type) {
    case 'scenes':
      if (data['scenes'] is! List) {
        errors.add('scenes is not a list');
      } else if ((data['scenes'] as List).isEmpty) {
        errors.add('scenes is empty');
      }
    case 'profile':
      if (data['domains'] is! List) {
        errors.add('domains is not a list');
      } else if ((data['domains'] as List).isEmpty) {
        errors.add('domains is empty');
      }
  }

  return ValidationResult(errors.isEmpty, errors, type);
}

// -------------------------------------------------------------- 3. normalise

String? _normLevel(Object? v, [String? fallback]) {
  final s = clean(v).toUpperCase();
  return _levels.contains(s) ? s : fallback;
}

int _normInt(Object? v, int lo, int hi, int dflt) {
  final n = v is num ? v.toInt() : int.tryParse(clean(v));
  return n == null ? dflt : clampInt(n, lo, hi);
}

double _normDouble(Object? v, double lo, double hi, double dflt) {
  final n = v is num ? v.toDouble() : double.tryParse(clean(v));
  return n == null ? dflt : clampDouble(n, lo, hi);
}

List<String> _normList(Object? v, [int max = 24]) {
  if (v is! List) return const [];
  return take(
    uniqueBy(v.map(clean).where((s) => s.isNotEmpty), (s) => s.toLowerCase()),
    max,
  );
}

class NormalisedProfile {
  final UserProfile profile;
  final List<Realm> realms;
  const NormalisedProfile(this.profile, this.realms);
}

NormalisedProfile normaliseProfile(Map<String, dynamic> data) {
  final p = (data['profile'] as Map?) ?? const {};
  final profile = UserProfile(
    englishLevel: _normLevel(p['english_level']) ?? 'UNKNOWN',
    levelConfidence: _normDouble(p['level_confidence'], 0, 1, 0.5),
    roles: _normList(p['roles'], 12),
    learningPriorities: _normList(p['learning_priorities'], 12),
    notes: clean(p['notes']),
  );

  final realms = <Realm>[];
  for (final raw in (data['domains'] as List? ?? const [])) {
    if (raw is! Map) continue;
    final name = clean(raw['name']);
    if (name.isEmpty) continue;
    final key = normKey(name);
    realms.add(Realm(
      id: slugId('realm', key),
      name: name,
      nameNative: clean(raw['name_native']),
      normKeyValue: key,
      importance: _normInt(raw['importance'], 1, 5, 3),
      confidence: _normDouble(raw['confidence'], 0, 1, 0.5),
      contexts: _normList(raw['contexts'], 10),
    ));
  }

  return NormalisedProfile(
    profile,
    uniqueBy(realms, (r) => r.normKeyValue),
  );
}

/// Reads the optional `register` block: several ways of saying the same thing,

String? declaredLanguage(Map<String, dynamic> data) {
  final s = clean(data['native_language']);
  return s.isEmpty ? null : s;
}
