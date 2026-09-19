/// Making a pasted set sound before it is stored.
///
/// The exercise makes one promise: exactly one of three fits, and what says
/// which is something that was heard. Each wrong option therefore has to
/// contradict a fact, and has to say which — an option that is merely less
/// polite, or a little odd, is a second right answer, and a question with two
/// right answers teaches nothing. A set that breaks the promise is refused and
/// named with the reason, so the learner can hand it back to their AI to be
/// mended; it is never quietly kept.
library;

import '../core/util.dart';
import 'scene.dart';

/// Below this many words the first line cannot hold the facts a set turns on;
/// above the upper one it is a speech. The prompt asks for 50 to 60.
const partnerMinWords = 40;
const partnerMaxWords = 90;

/// A set that could not be taken, with every reason, and the set as it
/// arrived so it can be sent back to be mended.
class RejectedSet {
  final String title;
  final List<String> reasons;
  final Map<String, dynamic> raw;
  const RejectedSet({required this.title, required this.reasons, required this.raw});
}

class NormalisedSets {
  final List<Scene> sets;
  final List<RejectedSet> rejected;

  /// Taken, but worth a word: the summaries came back in English when the
  /// learner reads another language.
  final List<String> warnings;
  const NormalisedSets({required this.sets, required this.rejected, this.warnings = const []});
}

/// Whether [data] is a reply of sets rather than anything else.
bool isSetsReply(Map<String, dynamic> data) {
  if ('${data['type']}' == 'replyPredict') return true;
  final items = data['items'];
  return items is List && items.any((i) => i is Map && '${i['type']}' == 'replyPredict');
}

int wordCount(String text) =>
    text.split(RegExp(r'\s+')).where((w) => stressKey(w).isNotEmpty).length;

NormalisedSets normaliseSets(Map<String, dynamic> data, {required String uiLanguage}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final raws = data['items'] is List
      ? data['items'] as List
      : ('${data['type']}' == 'replyPredict' && data['partner'] is Map ? [data] : const []);
  final sets = <Scene>[];
  final rejected = <RejectedSet>[];
  final warnings = <String>{};
  final seen = <String>{};

  for (final raw in raws) {
    if (raw is! Map) continue;
    final j = Map<String, dynamic>.from(raw);
    final r = checkSet(j, uiLanguage: uiLanguage);
    if (r.reasons.isNotEmpty) {
      rejected.add(RejectedSet(title: r.title, reasons: r.reasons, raw: j));
      continue;
    }
    warnings.addAll(r.warnings);
    final set = r.set!;
    final id = sceneId(r.title, set.partner.text);
    // The same set twice in one reply is a repeat. Kept once.
    if (!seen.add(id)) continue;
    // The AI tends to put the right option first. Where it lands is decided
    // by the set's own id, so every device agrees and nobody has to think
    // about position.
    final arranged = ReplyPredict(
      partnerName: set.partnerName,
      partner: set.partner,
      paraphrase: set.paraphrase,
      reply: set.reply.arranged(optionOrder(id, 0)),
      trap: set.trap,
      predict: set.predict.arranged(optionOrder(id, 1)),
      response: set.response,
    );
    sets.add(Scene.ofSet(id: id, label: r.title, set: arranged, createdAt: now));
  }
  return NormalisedSets(sets: sets, rejected: rejected, warnings: warnings.toList());
}

/// One set checked against the rules. Every broken rule is named, not only
/// the first: the list goes back to the AI, and a set mended one reason at a
/// time takes as many trips as it has faults.
({ReplyPredict? set, String title, List<String> reasons, List<String> warnings})
    checkSet(Map<String, dynamic> j, {required String uiLanguage}) {
  final title = clean(j['scene'] ?? j['title']);
  final reasons = <String>[];
  final warnings = <String>[];

  Map<String, dynamic> part(String k) =>
      j[k] is Map ? Map<String, dynamic>.from(j[k] as Map) : <String, dynamic>{};
  final p = part('partner');
  final rp = part('reply');
  final pr = part('predict');
  final rs = part('response');

  if (title.isEmpty) reasons.add('scene is empty');
  final partnerName = clean(j['partnerName']);
  if (partnerName.isEmpty) reasons.add('partnerName is empty');

  final text = clean(p['text']);
  final paraphrase = clean(p['paraphrase']);
  final words = wordCount(text);
  if (text.isEmpty) {
    reasons.add('partner.text is empty');
  } else if (words < partnerMinWords) {
    reasons.add('partner.text has $words words, needs at least $partnerMinWords');
  } else if (words > partnerMaxWords) {
    reasons.add('partner.text has $words words, at most $partnerMaxWords');
  }
  if (paraphrase.isEmpty) {
    reasons.add('partner.paraphrase is empty');
  } else if (normKey(paraphrase) == normKey(text)) {
    reasons.add('partner.paraphrase is the same as partner.text');
  }

  final responseText = clean(rs['text']);
  if (responseText.isEmpty) reasons.add('response.text is empty');

  List<String> stressOf(Map<String, dynamic> m, String where, String said) {
    final list = [for (final w in (m['stress'] as List? ?? const [])) clean(w)]
        .where((w) => w.isNotEmpty)
        .toList();
    if (said.isEmpty) return list;
    final heard = wordsOf(said);
    final missing = [
      for (final w in list)
        if (!stressKey(w).split('-').every((x) => x.isEmpty || heard.contains(x)) &&
            !heard.contains(stressKey(w)))
          w
    ];
    if (missing.isNotEmpty) {
      reasons.add('$where.stress has words not in $where.text: ${missing.join(', ')}');
    }
    return list;
  }

  final partnerStress = stressOf(p, 'partner', text);
  final responseStress = stressOf(rs, 'response', responseText);

  SetChoice? choice(Map<String, dynamic> m, String where) {
    final options = [for (final o in (m['options'] as List? ?? const [])) clean(o)];
    final why = [for (final w in (m['why'] as List? ?? const [])) clean(w)];
    final answer = m['answer'] is num ? (m['answer'] as num).toInt() : -1;
    var ok = true;
    if (options.length != repliesPerTurn) {
      reasons.add('$where.options has ${options.length}, needs $repliesPerTurn');
      ok = false;
    } else if (options.any((o) => o.isEmpty)) {
      reasons.add('$where.options has an empty option');
      ok = false;
    } else if ({for (final o in options) normKey(o)}.length != options.length) {
      reasons.add('$where.options has the same option twice');
      ok = false;
    }
    if (answer < 0 || answer >= repliesPerTurn) {
      reasons.add('$where.answer must be 0, 1 or 2');
      ok = false;
    }
    if (why.length != repliesPerTurn) {
      reasons.add('$where.why has ${why.length}, needs $repliesPerTurn');
      ok = false;
    } else if (answer >= 0 && answer < repliesPerTurn) {
      if (why[answer].isNotEmpty) {
        reasons.add('$where.why must be empty for the right option');
        ok = false;
      }
      for (var i = 0; i < repliesPerTurn; i++) {
        if (i != answer && why[i].isEmpty) {
          reasons.add('$where.why is empty for wrong option ${i + 1}: every wrong '
              'option needs the fact it contradicts');
          ok = false;
        }
      }
    }
    return ok ? SetChoice(options: options, answer: answer, why: why) : null;
  }

  final reply = choice(rp, 'reply');
  final predict = choice(pr, 'predict');

  // The summaries and the reasons are read in the learner's language. Written
  // in English they still work, so the set is taken, but it is said.
  if (uiLanguage != 'en' && predict != null) {
    final shown = [...predict.options, ...predict.why, ...?reply?.why];
    final english = shown
        .where((t) => t.isNotEmpty)
        .every((t) => RegExp(r'^[\x00-\x7F’‘“”–—…]*$').hasMatch(t));
    if (english) warnings.add('english summaries');
  }

  if (reasons.isNotEmpty || reply == null || predict == null) {
    return (set: null, title: title.isEmpty ? '?' : title, reasons: reasons, warnings: warnings);
  }
  return (
    set: ReplyPredict(
      partnerName: partnerName,
      partner: Spoken(text: text, native: clean(p['native']), stress: partnerStress),
      paraphrase: paraphrase,
      reply: reply,
      trap: TurnType.parse(rp['trap']),
      predict: predict,
      response: Spoken(
          text: responseText, native: clean(rs['native']), stress: responseStress),
    ),
    title: title,
    reasons: reasons,
    warnings: warnings,
  );
}
