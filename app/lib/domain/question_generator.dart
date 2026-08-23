/// Turns sentences into questions locally, ported from `questions.js`.
///
/// The AI supplies sentences; the app builds every question from them. Doing
/// this on-device keeps AI output small, guarantees the formats stay
/// consistent, and means no network call is ever needed to study.
library;

import 'dart:math';

import '../core/util.dart';
import 'models.dart';

const _maxReorderTokens = 12;
const _minReorderTokens = 4;

// ---------------------------------------------------------------- tokenizer

/// Splits a sentence into reorder tiles. Sentence-final punctuation is stripped
/// and re-applied at render time so it cannot leak the word order; internal
/// punctuation stays glued to its word.
({List<String> tokens, String finalPunct}) tokenize(String text) {
  var trimmed = clean(text);
  var punct = '';
  final m = RegExp(r'([.!?]+)$').firstMatch(trimmed);
  if (m != null) {
    punct = m.group(1)!;
    trimmed = trimmed.substring(0, trimmed.length - punct.length).trim();
  }
  return (tokens: trimmed.split(' ').where((t) => t.isNotEmpty).toList(), finalPunct: punct);
}

/// Locates a target phrase inside the sentence, returning the exact original
/// substring plus the text either side of it.
({String before, String answer, String after})? locatePhrase(String sentence, String phrase) {
  final sTokens = sentence.split(' ');
  final pLen = phrase.split(' ').where((t) => t.isNotEmpty).length;
  final pKey = answerKey(phrase);

  for (var i = 0; i + pLen <= sTokens.length; i++) {
    final slice = sTokens.sublist(i, i + pLen).join(' ');
    if (answerKey(slice) == pKey) {
      return (
        before: sTokens.sublist(0, i).join(' '),
        answer: slice,
        after: sTokens.sublist(i + pLen).join(' '),
      );
    }
    // Allow a trailing comma or period on the final matched token.
    final stripped = slice.replaceAll(RegExp(r'[.,!?;:]+$'), '');
    if (answerKey(stripped) == pKey) {
      return (
        before: sTokens.sublist(0, i).join(' '),
        answer: stripped,
        after: '${slice.substring(stripped.length)} ${sTokens.sublist(i + pLen).join(' ')}'.trim(),
      );
    }
  }
  return null;
}

// ---------------------------------------------------------- distractors

/// Picks [want] options of comparable length, so the answer never stands out by
/// shape alone.
List<String> pickDistractors(String correct, List<String> pool, int want, [Random? rng]) {
  final key = normKey(correct);
  final len = correct.length;

  var candidates = uniqueBy(
    pool.where((t) => t.isNotEmpty && normKey(t) != key),
    normKey,
  );
  candidates.sort((a, b) => (a.length - len).abs().compareTo((b.length - len).abs()));

  // Draw from a widened band so the same trio is not served every time.
  final band = take(candidates, max(want * 4, want));
  return take(shuffled(band, rng), want);
}

/// Vocabulary from the same realm, used as decoy tiles. Real domain words are
/// far more confusable than random filler, which is what makes the exercise
/// worth doing.
List<String> collectWords(Iterable<Sentence> sentences) {
  final seen = <String, String>{};
  for (final s in sentences) {
    for (final raw in s.text.split(' ')) {
      final w = raw.replaceAll(RegExp(r"[^A-Za-z'-]"), '');
      if (w.length < 3) continue;
      seen.putIfAbsent(w.toLowerCase(), () => w);
    }
  }
  return seen.values.toList();
}

/// Decoys of comparable length to the answer words.
List<String> decoyWords(List<String> answerWords, List<String> realmWords, int want, [Random? rng]) {
  final taken = answerWords.map((w) => w.toLowerCase()).toSet();
  final avgLen = answerWords.isEmpty
      ? 6.0
      : answerWords.fold<int>(0, (a, w) => a + w.length) / answerWords.length;

  final pool = realmWords.where((w) => !taken.contains(w.toLowerCase())).toList();
  pool.sort((a, b) =>
      (a.length - avgLen).abs().compareTo((b.length - avgLen).abs()));
  return take(shuffled(take(pool, want * 2), rng), want);
}

// ---------------------------------------------------------------- builders

String _questionId(String sentenceId, QuestionType type) => 'q_${sentenceId}_${type.name}';

Question _base(Sentence s, QuestionType type, String? itemId) => Question(
      id: _questionId(s.id, type),
      type: type,
      sentenceId: s.id,
      realmId: s.realmId,
      itemId: itemId ?? (s.itemIds.isNotEmpty ? s.itemIds.first : null),
      text: s.text,
      translationNative: s.translationNative,
      level: s.level,
      context: s.context,
    );

/// "Which English sentence says the same thing?"
///
/// All four options restate the whole sentence, so the answer cannot be found
/// by spotting a fragment that appeared verbatim in the audio — which is all an
/// expression-matching question really tests. Reading four near-identical
/// English sentences also puts more vocabulary in front of the learner.
Question? buildParaphrase(Sentence s, [Random? rng]) {
  final correct = clean(s.paraphraseEn);
  if (correct.isEmpty) return null;

  final wrong = uniqueBy(
    s.paraphraseOptionsEn.where(
      (o) => normKey(o) != normKey(correct) && normKey(o) != normKey(s.text),
    ),
    normKey,
  );
  if (wrong.length < 3) return null;

  final picked = pickDistractors(correct, wrong, 3, rng);
  if (picked.length < 3) return null;

  final choices = shuffled([correct, ...picked], rng);
  final q = _base(s, QuestionType.paraphrase, null);
  return Question(
    id: q.id,
    type: q.type,
    sentenceId: q.sentenceId,
    realmId: q.realmId,
    itemId: q.itemId,
    text: q.text,
    translationNative: q.translationNative,
    level: q.level,
    context: q.context,
    prompt: '聞こえた英文の趣旨に最も近いのはどれですか？',
    options: choices,
    correct: choices.indexOf(correct),
    answerText: correct,
  );
}

/// "Which of these is closest to what you heard?" — comprehension in Japanese,
/// which pins down meaning errors precisely. The AI supplies near-miss readings
/// (negation flipped, wrong actor, wrong tense); when a sentence predates that
/// field, sentences from the same situation stand in, since they read more
/// alike than random ones.
Question? buildGist(Sentence s, List<Sentence> realmPool, [Random? rng]) {
  if (s.translationNative.isEmpty) return null;

  final near = s.meaningOptionsNative
      .where((o) => normKey(o) != normKey(s.translationNative))
      .toList();

  List<String> options;
  if (near.length >= 3) {
    options = take(shuffled(near, rng), 3);
  } else {
    final scored = realmPool
        .where((x) => x.translationNative.isNotEmpty && x.id != s.id)
        .map((x) {
      var score = 0.0;
      if (x.context.isNotEmpty && x.context == s.context) score += 3;
      if (x.speechAct.isNotEmpty && x.speechAct == s.speechAct) score += 2;
      if (x.itemIds.any(s.itemIds.contains)) score += 4;
      score -= (x.translationNative.length - s.translationNative.length).abs() / 12;
      return (s: x, score: score);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final ranked = uniqueBy(
      scored.map((r) => r.s.translationNative).where((t) => normKey(t) != normKey(s.translationNative)),
      normKey,
    );
    if (ranked.length < 3) return null;
    options = take(shuffled(take(ranked, 8), rng), 3);
  }

  final choices = shuffled([s.translationNative, ...options], rng);
  final q = _base(s, QuestionType.gist, null);
  return Question(
    id: q.id,
    type: q.type,
    sentenceId: q.sentenceId,
    realmId: q.realmId,
    itemId: q.itemId,
    text: q.text,
    translationNative: q.translationNative,
    level: q.level,
    context: q.context,
    prompt: '聞こえた内容に最も近いのはどれですか？',
    options: choices,
    correct: choices.indexOf(s.translationNative),
    answerText: s.translationNative,
  );
}

/// Never dictate a whole sentence: the answer is the target expression, built
/// from word tiles so a phone needs no keyboard.
Question? buildDictation(
  Sentence s,
  List<LearningItem> targets,
  List<String> realmWords, [
  Random? rng,
]) {
  for (final t in targets) {
    final loc = locatePhrase(s.text, t.text);
    if (loc == null) continue;
    final words = loc.answer.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length > 4) continue;

    final q = _base(s, QuestionType.dictation, t.id);
    return Question(
      id: q.id,
      type: q.type,
      sentenceId: q.sentenceId,
      realmId: q.realmId,
      itemId: t.id,
      text: q.text,
      translationNative: q.translationNative,
      level: q.level,
      context: q.context,
      prompt: '聞こえた表現を、タップして組み立ててください',
      before: loc.before,
      after: loc.after,
      answerWords: words,
      bankPool: decoyWords(words, realmWords, 12, rng),
      answerText: loc.answer,
    );
  }
  return null;
}

Question? buildReorder(Sentence s, List<LearningItem> targets) {
  final t = tokenize(s.text);
  if (t.tokens.length < _minReorderTokens || t.tokens.length > _maxReorderTokens) {
    return null;
  }
  final q = _base(s, QuestionType.reorder, targets.isNotEmpty ? targets.first.id : null);
  return Question(
    id: q.id,
    type: q.type,
    sentenceId: q.sentenceId,
    realmId: q.realmId,
    itemId: q.itemId,
    text: q.text,
    translationNative: q.translationNative,
    level: q.level,
    context: q.context,
    prompt: '単語を並べ替えて英文を完成させてください',
    tokens: t.tokens,
    finalPunct: t.finalPunct,
    answerText: s.text,
  );
}

/// Builds every question for the given sentences.
///
/// [corpus] is all sentences (existing plus new); it supplies the distractor
/// and decoy vocabulary.
List<Question> generateForSentences(
  List<Sentence> sentences,
  Map<String, LearningItem> itemsById,
  List<Sentence> corpus, [
  Random? rng,
]) {
  final out = <Question>[];
  final byRealm = groupBy(corpus.isEmpty ? sentences : corpus, (Sentence s) => s.realmId);
  final wordsByRealm = <String, List<String>>{};

  for (final s in sentences) {
    final pool = (byRealm[s.realmId] ?? const <Sentence>[])
        .where((x) => x.id != s.id && !x.disabled)
        .toList();
    final targets =
        s.itemIds.map((id) => itemsById[id]).whereType<LearningItem>().toList();

    final words = wordsByRealm.putIfAbsent(
        s.realmId, () => collectWords(byRealm[s.realmId] ?? const <Sentence>[]));

    final para = buildParaphrase(s, rng);
    if (para != null) out.add(para);

    final gist = buildGist(s, pool, rng);
    if (gist != null) out.add(gist);

    final dict = buildDictation(s, targets, words, rng);
    if (dict != null) out.add(dict);

    final reorder = buildReorder(s, targets);
    if (reorder != null) out.add(reorder);
  }
  return out;
}

// ---------------------------------------------------------------- grading

({bool correct, bool close}) gradeDictation(String? input, String answer) {
  final a = answerKey(input ?? '');
  final b = answerKey(answer);
  if (a.isEmpty) return (correct: false, close: false);
  if (a == b) return (correct: true, close: false);
  // A single-character slip is reported as "close" so the UI can show the
  // spelling without treating it as a pass.
  return (correct: false, close: _editDistance(a, b) <= 1);
}

int _editDistance(String a, String b) {
  if ((a.length - b.length).abs() > 2) return 99;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      ].reduce(min);
    }
    prev = cur;
  }
  return prev[b.length];
}

bool gradeReorder(List<String> arranged, Question q) =>
    arranged.join(' ') == q.tokens.join(' ');

/// Integrity checks used after import.
List<String> validateQuestion(Question q, Map<String, Sentence>? sentencesById) {
  final problems = <String>[];
  if (q.id.isEmpty) problems.add('id なし');
  if (q.sentenceId.isEmpty ||
      (sentencesById != null && !sentencesById.containsKey(q.sentenceId))) {
    problems.add('参照先の英文がない');
  }
  if (clean(q.text).isEmpty) problems.add('英文が空');

  if (q.type == QuestionType.paraphrase || q.type == QuestionType.gist) {
    if (q.options.length != 4) {
      problems.add('選択肢が4個でない');
    } else if (q.correct < 0 || q.correct > 3) {
      problems.add('正解位置が不正');
    } else if (uniqueBy(q.options, normKey).length != 4) {
      problems.add('選択肢が重複');
    }
  }
  if (q.type == QuestionType.dictation && clean(q.answerText).isEmpty) {
    problems.add('答えが空');
  }
  if (q.type == QuestionType.reorder && q.tokens.length < 3) {
    problems.add('並べ替えトークンが不足');
  }
  return problems;
}
