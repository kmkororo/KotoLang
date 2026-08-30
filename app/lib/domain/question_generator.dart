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

/// "Say it." The meaning is given; the English is not, and no audio plays
/// until the answer is in.
///
/// Mechanically close to reorder, and deliberately so — the tiles and the
/// grading are shared. What differs is the only thing that matters: reorder
/// plays the sentence first, so it asks the learner to reconstruct something
/// they just heard. Here the sentence is never heard, so the only route to the
/// answer is recalling it from what it means. That is the direction speaking
/// runs in, and nothing else in the app trains it.
Question? buildProduce(Sentence s, List<LearningItem> targets) {
  // Without a reading of the sentence there is no prompt at all.
  if (clean(s.translationNative).isEmpty) return null;

  final t = tokenize(s.text);
  if (t.tokens.length < _minReorderTokens || t.tokens.length > _maxReorderTokens) {
    return null;
  }

  final q = _base(s, QuestionType.produce, targets.isNotEmpty ? targets.first.id : null);
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
    tokens: t.tokens,
    finalPunct: t.finalPunct,
    answerText: s.text,
  );
}

/// "Someone says this to you. What do you say back?"
///
/// The audio is the other person's line, and the four options are replies. The
/// learner is not being asked what the English meant — they are being asked
/// which move is the right one, which is the thing conversation actually
/// demands and which no other format here touches.
Question? buildReply(Sentence s, List<Sentence> realmPool, [Random? rng]) {
  final cue = clean(s.cueEn);
  final answer = clean(s.text);
  if (cue.isEmpty || answer.isEmpty) return null;

  // Supplied distractors are better: they are wrong *as replies to this cue*.
  var wrong = uniqueBy(
    s.replyDistractorsEn.map(clean).where(
          (o) => o.isNotEmpty && normKey(o) != normKey(answer) && normKey(o) != normKey(cue),
        ),
    normKey,
  );

  if (wrong.length < 3) {
    // Fall back to other sentences from the same area. Preferring a different
    // speech act keeps them plausible English while still being the wrong
    // move — a second request where an answer was wanted, say.
    final pool = realmPool
        .where((x) =>
            x.id != s.id &&
            !x.disabled &&
            clean(x.text).isNotEmpty &&
            normKey(x.text) != normKey(answer))
        .toList()
      ..sort((a, b) {
        final da = a.speechAct == s.speechAct ? 1 : 0;
        final db = b.speechAct == s.speechAct ? 1 : 0;
        return da.compareTo(db);
      });
    wrong = uniqueBy([...wrong, ...pool.map((x) => clean(x.text))], normKey);
  }

  if (wrong.length < 3) return null;
  final picked = take(shuffled(take(wrong, 8), rng), 3);
  if (picked.length < 3) return null;

  final choices = shuffled([answer, ...picked], rng);
  final q = _base(s, QuestionType.reply, null);
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
    options: choices,
    correct: choices.indexOf(answer),
    cueText: cue,
    cueTranslationNative: clean(s.cueTranslationNative),
    answerText: answer,
  );
}

/// "You are saying this to *this* person. Which phrasing fits?"
///
/// Politeness is the part of English that fails without anyone saying so: the
/// grammar is right, the meaning is right, and the effect is wrong. The note
/// attached to each option is the teaching — the choice alone would not be.
Question? buildRegister(Sentence s, [Random? rng]) {
  final situation = clean(s.registerSituationNative);
  final options = s.registerOptionsEn.map(clean).toList();
  if (situation.isEmpty || options.length < 3) return null;
  if (s.registerCorrect < 0 || s.registerCorrect >= options.length) return null;
  if (options.any((o) => o.isEmpty)) return null;
  if (uniqueBy(options, normKey).length != options.length) return null;

  final answer = options[s.registerCorrect];
  final whys = s.registerWhyNative;
  final note = s.registerCorrect < whys.length ? clean(whys[s.registerCorrect]) : '';

  final choices = shuffled(options, rng);
  final q = _base(s, QuestionType.register, null);
  return Question(
    id: q.id,
    type: q.type,
    sentenceId: q.sentenceId,
    realmId: q.realmId,
    itemId: q.itemId,
    // The spoken model after answering is the phrasing that fits, which is not
    // necessarily the sentence the material was built around.
    text: answer,
    translationNative: situation,
    level: q.level,
    context: q.context,
    options: choices,
    correct: choices.indexOf(answer),
    note: note,
    answerText: answer,
  );
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

    // The conversation formats. Each returns null when the material predates
    // the fields it needs, so an older library keeps working untouched.
    final produce = buildProduce(s, targets);
    if (produce != null) out.add(produce);

    final reply = buildReply(s, pool, rng);
    if (reply != null) out.add(reply);

    final register = buildRegister(s, rng);
    if (register != null) out.add(register);
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

/// Where a dragged word has to be inserted so it lands in the gap the learner
/// dropped it on.
///
/// Gaps are numbered by the word they sit before, so gap 2 of `[a, b, c]` is
/// between `b` and `c`. Moving a word that is already placed removes it first,
/// which shifts every gap after it down by one — the off-by-one that makes a
/// word dropped to its own right land one place short.
int reinsertIndex(int from, int gap) => from >= 0 && from < gap ? gap - 1 : gap;

/// The spoken sentence with some of it blanked out — a hint for a learner who
/// caught the shape of a sentence but not all of it.
///
/// Function words are given away and content words are hidden, because the
/// hard part of listening is rarely "the" or "to". The blanks keep each word's
/// length so the gap still says how much was missed, and at least one word is
/// always hidden, or the hint would just be the answer.
String blankedHint(String sentence) {
  const giveaway = {
    'a', 'an', 'the', 'to', 'of', 'in', 'on', 'at', 'for', 'and', 'or', 'but',
    'is', 'are', 'was', 'were', 'be', 'do', 'does', 'did', 'we', 'i', 'you',
    'he', 'she', 'it', 'they', 'this', 'that', 'with', 'as', 'by', 'from',
  };

  final words = sentence.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return sentence;

  String mask(String w) {
    // Punctuation stays: it is part of the shape, not of the answer.
    final letters = w.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final tail = w.substring(w.length - (w.length - w.indexOf(letters) - letters.length));
    return '${'_' * letters.length}$tail';
  }

  var hidden = 0;
  final out = <String>[];
  for (final w in words) {
    final bare = w.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
    if (bare.isNotEmpty && !giveaway.contains(bare)) {
      out.add(mask(w));
      hidden++;
    } else {
      out.add(w);
    }
  }

  // An all-function-word sentence would come back untouched, which is no hint
  // at all — hide the longest word instead.
  if (hidden == 0) {
    var longest = 0;
    for (var i = 1; i < words.length; i++) {
      if (words[i].length > words[longest].length) longest = i;
    }
    out[longest] = mask(words[longest]);
  }
  return out.join(' ');
}

/// Integrity checks used after import.
List<String> validateQuestion(Question q, Map<String, Sentence>? sentencesById) {
  final problems = <String>[];
  if (q.id.isEmpty) problems.add('id なし');
  if (q.sentenceId.isEmpty ||
      (sentencesById != null && !sentencesById.containsKey(q.sentenceId))) {
    problems.add('参照先の英文がない');
  }
  if (clean(q.text).isEmpty) problems.add('英文が空');

  if (q.type == QuestionType.paraphrase ||
      q.type == QuestionType.gist ||
      q.type == QuestionType.reply) {
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
  if (q.type == QuestionType.produce) {
    if (q.tokens.length < 3) problems.add('組み立てトークンが不足');
    // Without the reading there is nothing to prompt from, and the question
    // would show an empty card.
    if (clean(q.translationNative).isEmpty) problems.add('意味が空');
  }
  if (q.type == QuestionType.reply && clean(q.cueText).isEmpty) {
    problems.add('相手のセリフが空');
  }
  if (q.type == QuestionType.register) {
    if (q.options.length < 3) {
      problems.add('言い方の選択肢が不足');
    } else if (q.correct < 0 || q.correct >= q.options.length) {
      problems.add('正解位置が不正');
    } else if (uniqueBy(q.options, normKey).length != q.options.length) {
      problems.add('選択肢が重複');
    }
    if (clean(q.translationNative).isEmpty) problems.add('場面が空');
  }
  return problems;
}
