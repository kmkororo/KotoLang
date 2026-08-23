/// Turns a pasted AI reply into stored material.
///
/// Raw text -> extract -> parse -> validate -> normalise -> dedupe -> records.
/// Each stage is separate so a failure can be reported precisely, and nothing
/// here may throw on bad input: an AI that returns prose, truncated JSON or the
/// wrong shape must produce a readable message, never a crash.
library;

import 'dart:convert';

import '../core/util.dart';
import 'models.dart';

const supportedSchemas = ['1.0'];
const _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

// ---------------------------------------------------------------- 1. extract

class ExtractResult {
  final Map<String, dynamic>? data;
  final String? failure; // 'empty' | 'parse'
  final String? detail;
  const ExtractResult.ok(this.data)
      : failure = null,
        detail = null;
  const ExtractResult.fail(this.failure, [this.detail]) : data = null;
  bool get ok => data != null;
}

/// AI replies routinely wrap JSON in prose or fences, so this tries
/// progressively looser strategies rather than demanding a clean response.
ExtractResult extractJson(String? raw) {
  if (raw == null) return const ExtractResult.fail('empty');
  final text = raw.replaceFirst('﻿', '').trim();
  if (text.isEmpty) return const ExtractResult.fail('empty');

  final candidates = <String>[text];

  // Fenced blocks, ```json ... ``` or plain ``` ... ```
  for (final m in RegExp(r'```[a-zA-Z]*\s*([\s\S]*?)```').allMatches(text)) {
    final inner = m.group(1)?.trim();
    if (inner != null && inner.isNotEmpty) candidates.add(inner);
  }

  // Every balanced {...} region, longest first.
  candidates.addAll(_balancedObjects(text));

  String? firstError;
  for (final c in candidates) {
    try {
      final parsed = jsonDecode(c);
      if (parsed is Map<String, dynamic>) return ExtractResult.ok(parsed);
    } catch (e) {
      firstError ??= e.toString();
    }
  }
  return ExtractResult.fail('parse', firstError);
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
  if (type == null || !['profile', 'material', 'audit'].contains(type)) {
    // Infer when the AI omitted it but the shape is unambiguous.
    if (data.containsKey('learning_items') || data.containsKey('sentences')) {
      type = 'material';
    } else if (data.containsKey('domains') || data.containsKey('profile')) {
      type = 'profile';
    } else if (data.containsKey('results')) {
      type = 'audit';
    } else {
      errors.add('type is not profile, material or audit');
    }
  }

  switch (type) {
    case 'profile':
      if (data['domains'] is! List) {
        errors.add('domains is not a list');
      } else if ((data['domains'] as List).isEmpty) {
        errors.add('domains is empty');
      }
    case 'material':
      final d = data['domain'];
      if (d is! Map || clean(d['name']).isEmpty) errors.add('domain.name is missing');
      if (data['learning_items'] is! List) errors.add('learning_items is not a list');
      if (data['sentences'] is! List) {
        errors.add('sentences is not a list');
      } else if ((data['sentences'] as List).isEmpty) {
        errors.add('sentences is empty');
      }
    case 'audit':
      if (data['results'] is! List) errors.add('results is not a list');
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

class NormalisedMaterial {
  final Realm realm;
  final List<LearningItem> items;
  final List<Sentence> sentences;
  const NormalisedMaterial(this.realm, this.items, this.sentences);
}

NormalisedMaterial normaliseMaterial(Map<String, dynamic> data) {
  final d = (data['domain'] as Map?) ?? const {};
  final name = clean(d['name']);
  final realm = Realm(
    id: slugId('realm', normKey(name)),
    name: name,
    nameNative: clean(d['name_native']),
    normKeyValue: normKey(name),
    importance: _normInt(d['importance'], 1, 5, 3),
    confidence: _normDouble(d['confidence'], 0, 1, 0.7),
    contexts: _normList(d['contexts'], 10),
  );

  final items = <LearningItem>[];
  for (final raw in (data['learning_items'] as List? ?? const [])) {
    if (raw is! Map) continue;
    final text = clean(raw['text']);
    if (text.isEmpty || text.length > 80) continue;
    final type = clean(raw['type']);
    items.add(LearningItem(
      id: slugId('item', normKey(text)),
      text: text,
      normKeyValue: normKey(text),
      type: ['term', 'phrase', 'collocation', 'expression'].contains(type) ? type : 'term',
      meaningNative: clean(raw['meaning_native']),
      priority: _normInt(raw['priority'], 1, 5, 3),
      confidence: _normDouble(raw['confidence'], 0, 1, 0.7),
      relatedTerms: _normList(raw['related_terms'], 10),
      contexts: _normList(raw['contexts'], 8),
      distractorsNative: _normList(raw['distractors_native'], 6),
    ));
  }

  final sentences = <Sentence>[];
  for (final raw in (data['sentences'] as List? ?? const [])) {
    if (raw is! Map) continue;
    final text = clean(raw['text']);
    if (text.isEmpty) continue;
    // Guard against fragments and paragraph-length output.
    final words = text.split(' ').length;
    if (words < 3 || words > 40) continue;

    final translation = clean(raw['translation_native']);
    final paraphrase = clean(raw['paraphrase_en']);

    sentences.add(Sentence(
      id: slugId('sent', normKey(text)),
      text: text,
      normKeyValue: normKey(text),
      translationNative: translation,
      level: _normLevel(raw['level'], 'B1')!,
      context: clean(raw['context']),
      speechAct: clean(raw['speech_act']).isEmpty ? 'statement' : clean(raw['speech_act']),
      naturalness: _normInt(raw['naturalness'], 1, 5, 4),
      realmId: realm.id,
      itemIds: _normList(raw['targets'], 6), // resolved to ids when persisting
      // An option identical to the answer would create a second correct choice.
      meaningOptionsNative: _normList(raw['meaning_options_native'], 5)
          .where((o) => normKey(o) != normKey(translation))
          .toList(),
      // A paraphrase that merely repeats the sentence teaches nothing.
      paraphraseEn:
          (paraphrase.isNotEmpty && normKey(paraphrase) != normKey(text)) ? paraphrase : '',
      paraphraseOptionsEn: _normList(raw['paraphrase_options_en'], 5)
          .where((o) => normKey(o) != normKey(paraphrase) && normKey(o) != normKey(text))
          .toList(),
    ));
  }

  return NormalisedMaterial(
    realm,
    uniqueBy(items, (i) => i.normKeyValue),
    uniqueBy(sentences, (s) => s.normKeyValue),
  );
}

class AuditEntry {
  final String normKeyValue;
  final int score;
  final List<String> issues;
  final String fix;
  const AuditEntry(this.normKeyValue, this.score, this.issues, this.fix);
}

List<AuditEntry> normaliseAudit(Map<String, dynamic> data) {
  final out = <AuditEntry>[];
  for (final raw in (data['results'] as List? ?? const [])) {
    if (raw is! Map) continue;
    final t = clean(raw['text']);
    if (t.isEmpty) continue;
    out.add(AuditEntry(
      normKey(t),
      _normInt(raw['score'], 1, 5, 3),
      _normList(raw['issues'], 6),
      clean(raw['suggested_fix']),
    ));
  }
  return out;
}

/// The language the AI was asked to write translations in, echoed back so the
/// app can tell the learner when stored material predates a language change.
String? declaredLanguage(Map<String, dynamic> data) {
  final s = clean(data['native_language']);
  return s.isEmpty ? null : s;
}
