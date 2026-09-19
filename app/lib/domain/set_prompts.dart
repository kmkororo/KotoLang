/// The prompts that make sets: one to write them, and one to mend the ones
/// the app refused.
///
/// Like every prompt here they are in English whatever the interface
/// language, because they address the AI; what the learner reads — the
/// summaries, the reasons, the translations — is asked for in their language
/// by name.
library;

import 'dart:convert';

import '../core/l10n/languages.dart';

/// Sets: hear one long line, reply, predict what comes back.
const setsSchemaVersion = '5.0';

/// How many sets one reply is asked for. As many as fit comfortably in one
/// answer from an ordinary assistant; the rest come with "continue".
const setsPerReply = 8;

String _example(String native) => '''
{
  "type": "replyPredict",
  "scene": "(in $native) At the front desk of a restaurant",
  "partnerName": "(in $native) Host",
  "partner": {
    "text": "Hi there, welcome to Bella's. So, we're pretty busy tonight. Without a reservation it's about a twenty-minute wait, but if you'd like, you can wait at the bar, and drinks there are half price until seven. Just give me a name and how many are in your party, and I'll come find you when your table's ready.",
    "paraphrase": "Welcome to Bella's. It's busy tonight. With no reservation, the wait is around twenty minutes. You're welcome to wait at the bar, where drinks are half price before seven. Tell me your name and the size of your group, and I'll come get you when the table is ready.",
    "native": "(in $native, a natural translation of text)",
    "stress": ["welcome", "bella's", "busy", "without", "reservation", "twenty", "wait", "bar", "half", "seven", "name", "many", "party", "find", "ready"]
  },
  "reply": {
    "options": [
      "No reservation. It's Tanaka, two people. We'll wait at the bar.",
      "We have a reservation under Tanaka, so we'll wait at the bar for twenty minutes.",
      "Tanaka, party of two. We'll grab the free drinks at the bar while we wait."
    ],
    "answer": 0,
    "why": ["", "(in $native) The twenty-minute wait is for people WITHOUT a reservation", "(in $native) The drinks are half price, not free"],
    "trap": "multiFact"
  },
  "predict": {
    "options": ["(in $native) Confirms the name and number, and says they will come and get us when the table is free", "(in $native) Asks again whether we have a reservation", "(in $native) Takes us to a table right away"],
    "answer": 0,
    "why": ["", "(in $native) We already said we have no reservation", "(in $native) They said there is a twenty-minute wait, so right away contradicts it"]
  },
  "response": {
    "text": "Perfect. Tanaka, party of two. Head on over to the bar, and I'll come get you in about twenty minutes.",
    "native": "(in $native, a natural translation of text)",
    "stress": ["perfect", "tanaka", "two", "bar", "get", "twenty"]
  }
}''';

String _rules(String native) => '''
## HOW ONE SET WORKS

1. The other person says one long line (`partner.text`). The learner hears it
   and **never sees it written** until they have answered.
2. Only then are three things the learner could say back shown
   (`reply.options`). Exactly one agrees with everything that was said.
3. The learner guesses what the other person says next, from three short
   summaries in $native (`predict.options`). Then the real next line
   (`response.text`) is played.

## THE ONE RULE: EXACTLY ONE OPTION FITS

"All three could work" is the failure this format exists to avoid.

- **The two wrong replies each contradict a concrete fact in `partner.text`**:
  a number, a time, a condition, who does what, a place. Not "a bit less
  polite", not "slightly unnatural" — a fact that is wrong. Someone who
  caught every fact rules them out; someone who missed one is tempted.
- **The two wrong predictions** either contradict something the other person
  already said, or ask again about something the learner's reply already
  answered.
- **Every wrong option carries its reason in `why`**, one short line in
  $native, naming the fact it contradicts. If you cannot write the reason,
  the option is not wrong — replace it.
- `why` has three entries. The entry for the right option is `""`. The other
  two are never empty.

## `partner.text`

- **50 to 60 words**, natural spoken English, with **4 or 5 concrete facts**
  (numbers, times, conditions, who is responsible, places).
- The situation comes from this person's own work, interests and daily life.
- Full stops and commas only. **No dashes, no semicolons, no brackets**: a
  phone's voice reads them badly.
- People are roles, never names ("the manager", "someone at the desk").
  Tools are kinds, never products ("the team chat", not an app's name). If
  the learner's reply has to give their own name, use one short, common name
  from $native.

## `partner.paraphrase`

The same facts in a different order and different words. It is played once
if the learner missed the first hearing, so it must not be the same sentence.

## `stress`

The words a speaker would stress, mostly content words, **copied exactly as
they appear** in the text (lower case is fine). Every listed word must occur
in its text.

## `reply`

- Three things the learner could say, in English, **12 to 15 words each**.
- `trap` names how the wrong ones are built, one of:
  - `keyword`: a word that sounds like one in the line changes a fact
    (fifteen and fifty, Tuesday and Thursday).
  - `polarity`: the line had a reversing word (not, without, unless, only)
    and the wrong reply is what someone who missed it would say.
  - `multiFact`: each wrong reply gets one of several facts wrong.
  Mix the three across the set of questions.

## `predict`

Three **summaries in $native**, one short sentence each, of what the other
person might say next. Never full English sentences: the learner must hear
the real line, not read it in advance.

## `response`

What the other person really says next, **20 to 30 words**, in English. It
must say what the right `predict` option summarises.

## `native`

`partner.native` and `response.native` are natural $native translations,
shown only after answering.

## `scene` and `partnerName`

In $native. `scene` is where this happens, in a few words. `partnerName` is
who is speaking, as a role.''';

String setsPrompt({
  required String uiLanguage,
  required String batch,
  String level = 'A2',
  String ageBand = '',
  List<String> roles = const [],
  List<String> priorities = const [],
  List<String> areas = const [],
  List<String> existingTopics = const [],
  String field = '',
  ({int rightPct, int firstTimePct, int turns})? recent,
  List<String> tendencies = const [],
}) {
  final native = languageFor(uiLanguage).englishName;
  String list(Iterable<String> xs) => xs.map((x) => '- $x').join('\n');

  final person = StringBuffer()..writeln('- English level: $level');
  if (ageBand.isNotEmpty) person.writeln('- Age group: $ageBand');
  if (roles.isNotEmpty) person.writeln('- What they do: ${roles.join(', ')}');
  if (priorities.isNotEmpty) {
    person.writeln('- Where they want English: ${priorities.join(', ')}');
  }
  if (areas.isNotEmpty) person.writeln('- Areas they practise: ${areas.join(', ')}');
  person.write('- Their language: $native');
  if (field.isNotEmpty) {
    person.write('\n- Every set in this reply happens in: $field. The situations '
        'differ; the field does not.');
  }

  final recentText = recent == null
      ? ''
      : '\n## HOW THEY HAVE BEEN DOING\n\n'
          'Over their last ${recent.turns} replies: ${recent.rightPct}% right, '
          '${recent.firstTimePct}% right on the first hearing, in time.\n';

  final tendencyText = tendencies.isEmpty
      ? ''
      : '\n## WHAT THEY RECENTLY MISHEARD\n\n${list(tendencies)}\n\n'
          'Aim one or two sets at the same kind of fact.\n';

  final topicText = existingTopics.isEmpty
      ? ''
      : '\n## SITUATIONS THEY ALREADY HAVE\n\n'
          'Do not repeat these or write a near-twin of one.\n\n'
          '${list(existingTopics)}\n';

  return '''
You are writing listening practice for one person learning English.

## THE PERSON

$person
$recentText$tendencyText$topicText
${_rules(native)}

## HOW MUCH TO WRITE

Write **$setsPerReply sets**. If your answer would be cut off before that,
stop after the last complete set, close the JSON properly, and write nothing
else. When the learner then says "continue", write the remaining sets as a
new JSON of exactly the same shape, with the same `batch`, and without
repeating any set.

## OUTPUT

One fenced ```json block and nothing else:

```json
{
  "schema_version": "$setsSchemaVersion",
  "type": "replyPredict",
  "batch": "$batch",
  "native_language": "$native",
  "items": [
${_example(native)}
  ]
}
```

The example shows the shape and the standard. Write new situations for this
person; do not reuse it.

## BEFORE YOU ANSWER

Check every set:

1. Does `partner.text` have 50 to 60 words and 4 or 5 concrete facts?
2. Does each wrong reply contradict a specific fact, and does its `why` name
   that fact in $native?
3. Does each wrong prediction contradict what was said, or re-ask what was
   already answered, with its `why`?
4. Is the `why` of the right option empty, and are the other two filled?
5. Are the predictions summaries in $native, not English sentences?
6. Does `response.text` say what the right prediction summarises, in 20 to
   30 words?
7. Is every `stress` word in its text?
8. Is `paraphrase` really in different words?
''';
}

/// The sets the app refused, each with its reasons, for the same assistant to
/// mend. What comes back is imported like any other reply.
String setsFixPrompt({
  required String uiLanguage,
  required String batch,
  required List<({Map<String, dynamic> raw, List<String> reasons})> rejected,
}) {
  final native = languageFor(uiLanguage).englishName;
  const enc = JsonEncoder.withIndent('  ');
  final items = StringBuffer();
  for (var i = 0; i < rejected.length; i++) {
    final r = rejected[i];
    items
      ..writeln('### Set ${i + 1}')
      ..writeln()
      ..writeln('What is wrong:')
      ..writeln(r.reasons.map((x) => '- $x').join('\n'))
      ..writeln()
      ..writeln('```json')
      ..writeln(enc.convert(r.raw))
      ..writeln('```')
      ..writeln();
  }

  return '''
Some listening-practice sets you wrote could not be used. Each one is below
with what is wrong. Fix them.

${_rules(native)}

## THE SETS TO FIX

$items
## OUTPUT

Rewrite every set above so that nothing on its list is still wrong. Keep what
already worked; change what the list names. Where a wrong option has no fact
to contradict, replace the option rather than inventing a reason.

One fenced ```json block and nothing else:

```json
{
  "schema_version": "$setsSchemaVersion",
  "type": "replyPredict",
  "batch": "$batch",
  "native_language": "$native",
  "items": [ ... ]
}
```
''';
}
