/// The four prompts the learner copies into their own AI.
///
/// KotoLang never calls an AI itself. These are plain text, copied out and the
/// reply pasted back, which is what keeps the app free of API keys, servers and
/// running costs.
///
/// The prompts are written in English regardless of interface language: the
/// instructions address the AI, not the learner, and every assistant follows
/// English instructions reliably. What *does* follow the interface language is
/// the output — the target language is named explicitly so a Spanish speaker
/// gets Spanish glosses rather than Japanese ones.
library;

import 'dart:convert';

import '../core/l10n/languages.dart';
import 'scene.dart';

const schemaVersion = '1.0';

/// The debate pack is a different shape from the material formats, so it has
/// its own version; the importer accepts both for ever.
const packSchemaVersion = '2.0';

/// Scenes — listen, choose, grow. The importer accepts every version for ever.
const scenesSchemaVersion = '3.0';

class PromptVersions {
  static const profile = 'PROFILE_PROMPT_V1';
  static const material = 'MATERIAL_PROMPT_V1';
  static const audit = 'AUDIT_PROMPT_V1';
  static const addRealm = 'ADD_REALM_PROMPT_V1';
  static const pack = 'PACK_PROMPT_V1';
  static const critique = 'CRITIQUE_PROMPT_V1';
  static const scenes = 'SCENES_PROMPT_V1';
}

String _commonRules(String native) => '''
RULES
- Put the entire reply inside ONE fenced code block marked ```json, and write
  nothing at all outside that block. No preamble, no explanation, no closing
  remarks, not even "here you go".
  This matters: the user is on a phone and copies the block with its copy
  button. Anything outside the block cannot be copied, and a second block
  splits the answer in two.
- The block must contain exactly one JSON object, and it must be valid JSON.
- Do not stop half-way and offer to continue. If the amount requested will not
  fit in one reply, produce fewer entries and finish the JSON properly. A short
  complete answer is useful; a long truncated one is worthless.
- Never invent facts. Use null, [] or "UNKNOWN" when you do not know.
- confidence is a real number from 0.0 to 1.0. Be honest about it.
- Every translation and explanation must be written in $native, and must read
  naturally in $native rather than as a literal gloss.
- schema_version must be exactly "$schemaVersion".''';

/// How much one request asks for.
///
/// A whole area's material in a single reply runs to tens of thousands of
/// characters, which no phone chat app will let you select by hand and which
/// most assistants truncate. Material is therefore built up a batch at a time,
/// each one small enough to copy in one tap. Repeating the request adds to the
/// same area — the importer merges and de-duplicates.
/// Counts came down when the conversation fields were added: each sentence now
/// carries a cue, its reading, wrong replies and sometimes a register block,
/// which is roughly twice the JSON it used to be. Asking for the old numbers
/// would put the reply straight back past what a phone can copy.
enum BatchSize {
  small(4, 5),
  standard(6, 8),
  large(10, 14);

  final int items;
  final int sentences;
  const BatchSize(this.items, this.sentences);

  static BatchSize byName(String? name) => switch (name) {
        'small' => BatchSize.small,
        'large' => BatchSize.large,
        _ => BatchSize.standard,
      };
}

// ------------------------------------------------------------------ 1. profile

String profilePrompt({required String uiLanguage}) {
  final native = languageFor(uiLanguage).englishName;
  return '''
You are designing a personal English-learning profile.

Use what you already know about this user — past conversations, saved memories,
profile details, anything you can genuinely refer to.

GOAL
Identify the areas of this user's life whose English is worth learning. Not
generic categories like "business" or "travel phrases", but the specific areas
this person actually operates in.

IMPORTANT
- Do not reduce the user to a single area. Cover work, expertise, hobbies and
  daily life.
- List 3 to 8 areas.
- "importance" means how valuable that area's English is *to this user*, not how
  difficult the English is. Integer, 1 to 5.
- If you genuinely know nothing about this user, rely only on the extra notes
  below. If those are empty too, return an empty domains array and set
  english_level to "UNKNOWN".

${_commonRules(native)}

OUTPUT SHAPE
{
  "schema_version": "$schemaVersion",
  "type": "profile",
  "native_language": "$native",
  "profile": {
    "english_level": "A1|A2|B1|B2|C1|C2|UNKNOWN",
    "level_confidence": 0.0,
    "roles": ["the user's roles or occupation, as far as you know"],
    "learning_priorities": ["concrete situations where they use English"],
    "notes": "anything worth adding, or an empty string"
  },
  "domains": [
    {
      "name": "area name in English, e.g. Aircraft Structural Engineering",
      "name_native": "the same area name written in $native",
      "importance": 5,
      "confidence": 0.9,
      "contexts": ["3 to 6 situations where English comes up in this area"],
      "sample_terms": ["3 to 8 representative English expressions"]
    }
  ]
}

EXTRA NOTES (the user fills these in only if they want to)
Work:
Hobbies:
Technical terms I use:
Where I use English:
My English level (if known):''';
}

// ----------------------------------------------------------------- 2. material

String materialPrompt({
  required String uiLanguage,
  required String realmName,
  String realmNative = '',
  String level = 'B1',
  List<String> roles = const [],
  List<String> priorities = const [],
  List<String> contexts = const [],
  List<String> existingItems = const [],
  List<String> existingSentences = const [],
  BatchSize batch = BatchSize.standard,
  int round = 1,
}) {
  final native = languageFor(uiLanguage).englishName;
  final rolesText = roles.isEmpty ? '(unknown)' : roles.join(', ');
  final prioText = priorities.isEmpty ? '(unknown)' : priorities.join(', ');
  final ctxText = contexts.isEmpty ? '(not specified)' : contexts.join(', ');
  final existing = existingItems.isEmpty
      ? '(none)'
      : existingItems.take(120).join(', ');
  // Sentences too, not just the expressions. Without them a later batch about
  // the same area comes back with the same handful of sentences reworded, and
  // the importer drops them as duplicates — so the library stops growing while
  // looking like it grew. Trimmed to an opening fragment: enough to recognise,
  // short enough that fifty of them do not swamp the prompt.
  final seen = existingSentences.isEmpty
      ? '(none)'
      : existingSentences
          .take(50)
          .map((s) => '- ${s.split(' ').take(9).join(' ')}')
          .join('\n');

  return '''
You are writing English study material for one specific person.

THE LEARNER
English level (CEFR): $level
Roles: $rolesText
Where they use English: $prioText

THE AREA
Area: $realmName${realmNative.isNotEmpty ? ' ($realmNative)' : ''}
Situations: $ctxText

ALREADY STORED — do not repeat these expressions
$existing

SENTENCES ALREADY STORED — write different ones, in different situations
$seen

THIS IS BATCH $round
The user builds their library a batch at a time and will ask you again for the
next one. Keep strictly to the amounts below even if you could write more —
a reply that fits in one message is the whole point.

WHAT TO PRODUCE
1. learning_items — expressions actually used in this area. Exactly ${batch.items}.
   Include not only technical terms but the verb phrases and collocations that
   come up constantly in this area's conversations.
2. sentences — natural English using those items. Exactly ${batch.sentences}.

THESE ARE SPOKEN TURNS, NOT WRITTEN SENTENCES — THIS MATTERS MOST
Every sentence must be something this person would **say out loud to another
person**, in a real exchange. Not a line from a document, a report or a status
field. The test: could you say it to someone's face and expect an answer?

  Good  "Could you check the revision status before we sign off?"
  Good  "I'd rather not commit to that date until we've seen the analysis."
  Bad   "The revision status has not been recorded yet."   <- a status field
  Bad   "The repair policy defines the applicable limits." <- a definition

Lean hard on the moves conversation is actually made of: asking for something,
declining, hedging, disagreeing politely, checking you understood, correcting
a misunderstanding, giving bad news, buying time, agreeing with a condition.

QUALITY BAR
- Every sentence must be grammatical and must sound like something a real
  practitioner would actually say.
- Do not cram terminology in. One or two target expressions per sentence.
- This is listening material: 6 to 18 words per sentence.
- Do not pad by rewording the same sentence. Each one must earn its place.
- Aim at CEFR $level. Specialist vocabulary may be hard, but do not make the
  sentence structure harder than it needs to be.
- Give each learning item 1 to 2 sentences in genuinely different situations.
- If the area is thin, produce fewer items rather than padding.

speech_act — use a real label, it is not decoration
One of: request, offer, refusal, agreement, disagreement, confirmation,
clarification, apology, warning, suggestion, question, report, instruction.

distractors_native
Each learning item needs 3 wrong-but-plausible meanings written in $native.
They must be clearly wrong, never a second valid reading.

paraphrase_en / paraphrase_options_en — IMPORTANT
Each sentence needs one English restatement (paraphrase_en) plus three English
near-misses (paraphrase_options_en). These become a "which sentence means the
same thing?" question.
- paraphrase_en must carry the same meaning using different words and structure.
- It must NOT reuse the target expression verbatim, or the question can be
  solved by matching letters instead of understanding.
- Keep all four options similar in length and register, or the answer stands out.
- Build each wrong option by changing exactly one thing: negation, who acts,
  tense, a condition, or strength of obligation.
- No wrong option may share the correct meaning.

Example
  text: "Do not sign off until the supplier confirms it."
  paraphrase_en: "Wait until the supplier has confirmed it before approving."
  paraphrase_options_en: [
    "Approve it now and let the supplier confirm afterwards.",
    "Ask the supplier to approve it on your behalf.",
    "You may approve it without waiting for the supplier."
  ]

meaning_options_native — IMPORTANT
Each sentence also needs 3 near-miss readings written in $native, for a
listening-comprehension question. Same technique: flip the negation, swap who
acts, shift the tense, change the strength, add or drop a condition.
A wholly unrelated option makes the question trivial. Never include an option
that means the same as translation_native.

cue_en / cue_translation_native — THE MOST VALUABLE FIELD HERE
What does the other person say, that this sentence is the answer to?

This turns the sentence from something to understand into something to *say
back*, which is the part of speaking that fails in real life. Write the other
person's line in English, plus its reading in $native.

- Give a cue to every sentence that could plausibly be a reply. Aim for most
  of them.
- Use "" only for a sentence that genuinely opens an exchange.
- The cue must not be a rephrasing of the sentence itself.
- Keep it short: one spoken line, 4 to 14 words.

reply_distractors_en
Three replies to that same cue that a learner might pick but that would land
badly. They must be correct English and about the same subject — the mistake
should be the *move*, not the grammar.
- Wrong move: answering a yes/no question with an unrelated request.
- Wrong stance: agreeing when the situation calls for pushing back.
- Wrong footing: too blunt, or too vague to be useful.
Never write a distractor that would also be a reasonable reply.

register — attach to roughly a third of the sentences, where politeness matters
The same intent said three ways, with only one fitting the stated relationship.
This is the part of English that fails silently: the grammar is right, the
meaning is right, and the effect is wrong.
- situation_native: who is being spoken to and how well you know them, in $native.
- variants: exactly 3. All say the same thing. Exactly one has "fits": true.
- why_native: one short line per variant, in $native, saying what it does to
  the listener. This is the teaching — write it for all three, not just the
  right one.
Skip the block entirely for a sentence where phrasing genuinely does not matter.

${_commonRules(native)}

OUTPUT SHAPE
{
  "schema_version": "$schemaVersion",
  "type": "material",
  "native_language": "$native",
  "domain": {
    "name": "$realmName",
    "name_native": "the area name in $native",
    "importance": 5,
    "confidence": 0.9,
    "contexts": ["situations"]
  },
  "learning_items": [
    {
      "text": "repair policy",
      "type": "term|phrase|collocation|expression",
      "meaning_native": "the meaning, in $native",
      "priority": 5,
      "confidence": 0.9,
      "related_terms": ["related expressions"],
      "contexts": ["where it comes up"],
      "distractors_native": ["wrong meaning 1", "wrong meaning 2", "wrong meaning 3"]
    }
  ],
  "sentences": [
    {
      "text": "Could we go over the repair policy before we sign anything?",
      "translation_native": "the sentence translated into $native",
      "level": "B1",
      "context": "design review",
      "speech_act": "request",
      "targets": ["repair policy"],
      "naturalness": 5,
      "cue_en": "Everything looks fine to me — shall we sign it off?",
      "cue_translation_native": "the cue translated into $native",
      "reply_distractors_en": [
        "Yes, go ahead and send it to the supplier tonight.",
        "I have not looked at any of the drawings yet.",
        "The repair policy was withdrawn earlier this year."
      ],
      "paraphrase_en": "Can we look at the rules for repairs first, before signing?",
      "paraphrase_options_en": [
        "We can sign it now and look at the rules for repairs later.",
        "Someone else will look at the rules for repairs for us.",
        "The rules for repairs were already gone through last week."
      ],
      "meaning_options_native": ["near miss 1", "near miss 2", "near miss 3"],
      "register": {
        "situation_native": "who you are speaking to, and how well you know them, in $native",
        "variants": [
          {"text": "Could we go over the repair policy first?", "fits": true,
           "why_native": "why this one lands well, in $native"},
          {"text": "Go over the repair policy first.", "fits": false,
           "why_native": "why this one is too blunt here, in $native"},
          {"text": "You need to go over the repair policy first.", "fits": false,
           "why_native": "why this one sounds like an order, in $native"}
        ]
      }
    }
  ]
}

NOTE: "targets" must contain only learning item texts that literally appear in
that sentence, matched exactly. Never list an expression the sentence does not
contain.

NOTE: "register" is optional per sentence — include it on about a third of
them. "cue_en" should be on most of them; use "" only for an opening line.''';
}

// -------------------------------------------------------------------- 3. audit

String auditPrompt({required String uiLanguage, required String sentences}) {
  final native = languageFor(uiLanguage).englishName;
  return '''
You are auditing English study material. Judge the sentences below strictly.

CRITERIA
- Grammar: is it correct?
- Naturalness: would a native speaker actually say this?
- Domain relevance: does it belong to the stated area?
- Listening suitability: can it be understood by ear?
- Ambiguity: is there exactly one reasonable reading?
- Difficulty: is it appropriate for the stated level?
- Duplication: does it substantially repeat another sentence?
- Factual accuracy: is anything stated simply untrue?

SCORES
5 = use as is
4 = essentially fine
3 = usable, could be better
2 = unnatural, needs fixing
1 = should not be used

${_commonRules(native)}

OUTPUT SHAPE
{
  "schema_version": "$schemaVersion",
  "type": "audit",
  "results": [
    {
      "text": "the sentence exactly as given",
      "score": 4,
      "issues": ["short notes, if any"],
      "suggested_fix": "a corrected version, or an empty string"
    }
  ]
}

SENTENCES TO REVIEW
$sentences''';
}

// ---------------------------------------------------------------- 4. add realm

String addRealmPrompt({
  required String uiLanguage,
  required List<String> existingRealms,
  String level = 'B1',
  String newRealm = '',
  BatchSize batch = BatchSize.standard,
}) {
  final native = languageFor(uiLanguage).englishName;
  final existing = existingRealms.isEmpty ? '(none)' : existingRealms.join(', ');
  return '''
You are adding a new area to an existing English-learning profile.

ALREADY REGISTERED
$existing

TASK
Produce material for the new area named at the bottom. Do not overlap with the
areas already registered: skip expressions those areas already cover and focus
on what is specific to this one.

English level (CEFR): $level

This is the first batch for the new area, and the user will ask again for more.
Keep to the amounts below so the reply fits in a single message.

Follow the same "material" format and the same quality bar as a normal material
request:
- exactly ${batch.items} learning_items and exactly ${batch.sentences} sentences
- every sentence must be a **spoken turn** — something said to another person
  and expecting an answer, never a line from a document or a status field
- 6 to 18 words per sentence, varied speech acts, no padding
- "targets" must appear literally in the sentence
- 3 distractors_native per learning item, written in $native
- paraphrase_en plus 3 paraphrase_options_en per sentence, all in English
- 3 meaning_options_native per sentence, written in $native
- cue_en plus cue_translation_native on most sentences: the line the other
  person says that this sentence answers
- reply_distractors_en: 3 replies to that cue that are correct English but the
  wrong move
- a "register" block on about a third of them: 3 ways to say the same thing,
  exactly one marked "fits": true, each with a why_native written in $native

${_commonRules(native)}

OUTPUT SHAPE
{
  "schema_version": "$schemaVersion",
  "type": "material",
  "native_language": "$native",
  "domain": { "name": "", "name_native": "", "importance": 3, "confidence": 0.8, "contexts": [] },
  "learning_items": [ { "text": "", "type": "term", "meaning_native": "", "priority": 3,
      "confidence": 0.8, "related_terms": [], "contexts": [], "distractors_native": [] } ],
  "sentences": [ { "text": "", "translation_native": "", "level": "$level", "context": "",
      "speech_act": "request", "targets": [], "naturalness": 5,
      "cue_en": "", "cue_translation_native": "", "reply_distractors_en": [],
      "paraphrase_en": "", "paraphrase_options_en": [],
      "meaning_options_native": [],
      "register": { "situation_native": "",
        "variants": [ { "text": "", "fits": true, "why_native": "" } ] } } ]
}

THE NEW AREA
${newRealm.isEmpty ? '(write the area you want to add here, e.g. Travel)' : newRealm}''';
}

// --------------------------------------------------------------- 5. the pack

/// The moves an argument is made of, as the prompt names them. Kept in step
/// with `Move` in debate.dart by the prompt test.
const argumentMoves = [
  'concede',
  'however',
  'reason',
  'evidence',
  'example',
  'question',
  'reframe',
  'propose',
  'clarify',
  'close',
];

/// Rules for the pack. Differs from `_commonRules` in one important way: the
/// reply is *meant* to stop after one debate and wait. A whole week's trees in
/// one message is what a free chat app truncates, and a truncated tree is
/// useless; one complete tree per message is short enough to survive.
String _packRules(String native) => '''
RULES
- Put the entire reply inside ONE fenced code block marked ```json, and write
  nothing at all outside it. No preamble, no explanation, no closing remarks.
  The user is on a phone and copies the block with its copy button.
- The block must contain exactly one JSON object, and it must be valid JSON.
- ONE DEBATE PER REPLY. Write one complete debate, close the JSON properly,
  and stop. When the user says "continue" (or "続けて"), reply with the next
  debate as a fresh, complete JSON object in the same shape. Never split one
  debate across two replies, and never start a second debate in the same
  reply.
- Never invent facts about the user's real situation beyond what is written
  below. Where you must fill a gap, keep it generic and plausible.
- Every *_native field must be written in $native, naturally, not as a
  literal gloss. Every field without that suffix is English.
- schema_version must be exactly "$packSchemaVersion", type must be "pack".''';

/// One weekly request: the trees to argue against, the critiques owed, and —
/// the first time — the chunk library. Everything the learner captured or
/// failed at is written in so the AI can aim.
String packPrompt({
  required String uiLanguage,
  String level = 'B1',
  List<String> roles = const [],
  List<String> priorities = const [],
  List<String> areas = const [],
  List<String> existingTopics = const [],
  required List<({String? date, String note, String who})> events,
  required List<({String topic, String node, String kind, String note})> failures,
  required List<({String id, String topic, String line, String youSaid, List<String> moves})>
      attempts,
  bool needChunks = false,
  int debates = 3,
}) {
  final native = languageFor(uiLanguage).englishName;
  String list(Iterable<String> xs, String empty) =>
      xs.isEmpty ? empty : xs.map((x) => '- $x').join('\n');

  final eventText = list(
    events.map((e) =>
        '${e.date ?? '(no date)'}: ${e.note}${e.who.isNotEmpty ? ' — with: ${e.who}' : ''}'),
    '(none this week — build the debates from the areas and failures instead)',
  );
  final failureText = list(
    failures.map((f) => '${f.topic} / ${f.node}: ${f.kind}${f.note.isNotEmpty ? ' — ${f.note}' : ''}'),
    '(none recorded)',
  );
  final attemptText = attempts.isEmpty
      ? '(none — leave "critiques" as an empty array)'
      : attempts
          .map((a) => '''
  { "attempt": "${a.id}",
    "topic": "${a.topic}",
    "they_said": "${a.line}",
    "you_said": "${a.youSaid}",
    "moves_used": ${jsonEncode(a.moves)} }''')
          .join(',\n');

  return '''
You are a sparring partner and coach for one person learning to argue in
English. The user practises on a train, silently, against opponents you write
in advance. They cannot ask you anything mid-argument, so everything the
exercise needs has to be in this reply.

THE LEARNER
English level (CEFR): $level
Roles: ${roles.isEmpty ? '(unknown)' : roles.join(', ')}
Where they use English: ${priorities.isEmpty ? '(unknown)' : priorities.join(', ')}
Areas they study: ${areas.isEmpty ? '(none yet)' : areas.join(', ')}

WHAT IS COMING UP — build debates for these first, in date order
$eventText

WHERE THEY STRUGGLED LAST TIME — aim the remaining debates at these
$failureText

DEBATES ALREADY ON THE PHONE — do not repeat these topics
${list(existingTopics, '(none)')}

WHAT TO PRODUCE, IN ORDER
${needChunks ? '''
0. chunks — ONLY in this first reply. About 100 short pieces of argument that
   work for any topic, each tagged with one move from the list below and
   written with {x} / {y} slots where the topic goes. Roughly 10 per move.
   "I take your point on {x}, but" · "The numbers from {x} say otherwise:" ·
   "What if we {x} first and revisit {y} in a month?" Include the $native
   reading of each. Later replies must not include chunks.
''' : ''}
1. debates — ONE per reply, $debates in total over the conversation. The
   first must be the nearest upcoming event above. Say "continue" is expected.
2. critiques — in the FIRST reply only, one per attempt listed at the bottom.

THE MOVES (use exactly these labels, nothing else)
${argumentMoves.join(' · ')}

HOW TO WRITE A DEBATE
- The opponent is a person, with the persona given: a numbers-first manager
  argues with numbers, an anxious colleague argues with consequences. Keep the
  same voice down the whole tree.
- Depth is exactly 3: the opponent speaks, the user replies, the opponent
  answers that reply, the user replies, the opponent answers once more, and
  the user's third reply ends it. So: node ids n1 → n2a/n2b/n2c → n3aa... and
  the rebuttals of the third-level nodes all have "next": null plus an
  "outcome".
- Each node needs exactly 3 rebuttals: one "strong", one "weak", one
  "concede". A weak reply is correct English that makes the wrong move —
  restating the wish, getting louder, changing the subject. Its "next" node
  has the opponent pressing harder. The strong reply's "next" has the
  opponent giving ground or asking a real question.
- Every rebuttal lists its "moves", 2 to 4 from the list, in the order they
  occur in "model". A strong reply is never a single move. The "slots" say
  what fills {x}-style gaps for this reply.
- Lines are spoken, 8 to 22 words. Model rebuttals are spoken, 10 to 30 words.
  Aim the English at CEFR $level.

grasp — THE PART THAT TRAINS LISTENING FOR ARGUMENT
For every opponent line, three questions in $native, each with 3 options
of which exactly one is right and the other two are near-misses:
- claim: what they are actually asserting
- reason: the ground they gave for it
- weak_point: where the argument gives way

weak_point must be something the user can push on, written as a fault in the
reasoning, not a verdict:
  Good  "says there is no headcount without having checked what the work is"
  Good  "treats one late supplier as if every supplier is late"
  Good  "assumes the date and the scope must move together"
  Bad   "is wrong"        Bad   "is exaggerating"        Bad   "is being emotional"
The strong rebuttal must actually push on that weak point.

${_packRules(native)}

OUTPUT SHAPE (one debate; "chunks" only in the first reply, "critiques" only in the first reply)
{
  "schema_version": "$packSchemaVersion",
  "type": "pack",
  "native_language": "$native",
  "chunks": [
    { "id": "c-concede-01", "move": "concede",
      "text": "I take your point on {x}, but", "native": "..." }
  ],
  "debates": [
    {
      "topic": "Pulling the migration date forward",
      "topic_native": "...",
      "event": "2026-09-11",
      "opponent": { "persona": "sceptical, numbers-first manager", "persona_native": "..." },
      "your_position": "We should move the date up by two weeks.",
      "your_position_native": "...",
      "nodes": [
        {
          "id": "n1",
          "line": "We simply don't have the headcount to move the date.",
          "line_native": "...",
          "grasp": {
            "claim":      { "answer": "...", "options": ["...", "...", "..."] },
            "reason":     { "answer": "...", "options": ["...", "...", "..."] },
            "weak_point": { "answer": "...", "options": ["...", "...", "..."] }
          },
          "rebuttals": [
            { "id": "r1a", "strength": "strong",
              "model": "I take your point on headcount, but two of the three blockers are already cleared, so what's left is a fortnight, not a quarter.",
              "moves": ["concede", "however", "evidence"],
              "slots": { "x": "headcount" },
              "next": "n2a" },
            { "id": "r1b", "strength": "weak",
              "model": "But we really do need to move faster on this.",
              "moves": ["however"],
              "slots": {},
              "next": "n2b" },
            { "id": "r1c", "strength": "concede",
              "model": "Fair enough — let's keep the date as it is.",
              "moves": ["concede", "close"],
              "slots": {},
              "next": null, "outcome": "conceded" }
          ]
        }
      ]
    }
  ],
  "critiques": [
    { "attempt": "the id given below",
      "verdict_native": "two or three sentences in $native: what worked, what did not",
      "better": ["a stronger version in English", "another, in a different register"],
      "watch_native": "one habit to watch, in $native" }
  ]
}

"outcome" is one of: won, held, pressed, conceded.

ATTEMPTS TO CRITIQUE (first reply only)
[
$attemptText
]''';
}

/// Critiques alone, for the learner who cannot wait for the next pack.
String critiquePrompt({
  required String uiLanguage,
  String level = 'B1',
  required List<({String id, String topic, String line, String youSaid, List<String> moves})>
      attempts,
}) {
  final native = languageFor(uiLanguage).englishName;
  final attemptText = attempts
      .map((a) => '''
  { "attempt": "${a.id}",
    "topic": "${a.topic}",
    "they_said": "${a.line}",
    "you_said": "${a.youSaid}",
    "moves_used": ${jsonEncode(a.moves)} }''')
      .join(',\n');

  return '''
You are coaching one person who is learning to argue in English (CEFR $level).
Below are replies they gave to an opponent's line. Critique each one.

FOR EACH ATTEMPT
- verdict_native: two or three sentences in $native. Say what the reply did
  well and where it fell short — in the *move* it made, not only the grammar.
  Did it concede before pushing back? Did it give a reason, or only restate
  the wish? Did it answer what the opponent actually said?
- better: two stronger versions in English, 10 to 30 words each, in two
  different registers (one collegial, one firmer). Natural spoken English.
- watch_native: one habit to watch for next time, in $native, one line.

${_packRules(native)}

OUTPUT SHAPE
{
  "schema_version": "$packSchemaVersion",
  "type": "pack",
  "native_language": "$native",
  "critiques": [
    { "attempt": "...", "verdict_native": "...", "better": ["...", "..."], "watch_native": "..." }
  ]
}

ATTEMPTS
[
$attemptText
]''';
}

// ------------------------------------------------------------------ scenes

/// How the AI is asked to pitch the scenes. Decided from the learner's recent
/// results, never typed in: the app reports the numbers and the AI adjusts.
enum SceneDifficulty {
  /// The default, and where everyone starts: one or two short sentences,
  /// school-level words, wrong answers that differ on a big point.
  easy,

  /// Recent results were high: longer lines, finer mishearings.
  harder,

  /// Recent results were low: even shorter lines, the most concrete facts.
  easier,
}

/// Five scenes for one learner, in one reply.
///
/// Everything the exercise relies on is spelled out: one right answer per
/// question, wrong answers that a mishearing would produce, no names or
/// titles in the lines, short plain English. The learner's recent results
/// and mistakes ride along so the next scenes aim at them.
String scenesPrompt({
  required String uiLanguage,
  String level = 'A2',
  String ageBand = '',
  List<String> roles = const [],
  List<String> priorities = const [],
  List<String> areas = const [],
  List<String> existingTopics = const [],
  SceneDifficulty difficulty = SceneDifficulty.easy,
  String field = '',
  ({int gistPct, int replyPct, int exchanges})? recent,
  List<String> tendencies = const [],
  int scenes = 5,
}) {
  final native = languageFor(uiLanguage).englishName;
  String list(Iterable<String> xs, String empty) =>
      xs.isEmpty ? empty : xs.map((x) => '- $x').join('\n');

  final difficultyText = switch (difficulty) {
    SceneDifficulty.easy =>
      'EASY. Each line is 1 or 2 short sentences in school-level English. One line carries at most two facts. Wrong answers differ from the right one on a big point (tonight vs tomorrow, stay vs leave, free vs paid).',
    SceneDifficulty.harder =>
      'A STEP HARDER than easy. Lines may be 2 or 3 sentences and carry two or three facts. Wrong answers may differ on a finer detail (this morning vs tonight, forty vs four, included vs not included). Vocabulary stays everyday.',
    SceneDifficulty.easier =>
      'VERY EASY. One short sentence per line, one fact per line, the most concrete everyday words. Wrong answers differ on the most obvious point.',
  };

  final recentText = recent == null
      ? '(no results yet — this is their first set)'
      : 'Over the last 7 days, across ${recent.exchanges} exchanges: "what did they say?" ${recent.gistPct}% right, "how do you reply?" ${recent.replyPct}% right.';

  final questions = scenes * exchangesPerScene * 2;
  final perPosition = (questions / 4).floor();

  final learner = StringBuffer()
    ..writeln('- Native language: $native. Every field ending in _native is written in $native.')
    ..writeln('- English level: $level.');
  if (ageBand.isNotEmpty) {
    learner.writeln('- Age group: $ageBand. Choose settings and a register that fit this age.');
  }
  if (roles.isNotEmpty) learner.writeln('- Roles: ${roles.join(', ')}.');
  if (priorities.isNotEmpty) {
    learner.writeln('- What they want English for: ${priorities.join(', ')}.');
  }
  if (areas.isNotEmpty) learner.writeln('- Areas they practise: ${areas.join(', ')}.');
  if (field.isNotEmpty) {
    learner.writeln(
        '- This set is about: $field. Every one of the $scenes scenes happens there; the settings differ, the field does not.');
  }
  learner.write('- Difficulty for this set: $difficultyText');

  final tendencyText = tendencies.isEmpty
      ? ''
      : 'Mistakes they keep making:\n${list(tendencies, '')}\nMake 1 or 2 of the $scenes scenes target these.\n';

  return '''
You are writing listening practice for one person learning English. They will
hear a line (spoken by their phone), then answer two three-way questions about
it. They cannot ask you anything while practising, so everything has to be in
this reply.

Reply with ONE JSON code block in the exact shape at the end. No greeting, no
explanation before or after it.

THE LEARNER
$learner

RECENT RESULTS (aim the scenes at these)
$recentText
$tendencyText
TOPICS THEY ALREADY HAVE (do not repeat any of these)
${list(existingTopics, '(none yet)')}

WHAT TO WRITE
$scenes scenes. A scene is $exchangesPerScene exchanges: the other person says a line,
the learner replies, the other person says one more line, the learner replies.
It runs straight; there are no branches. The second line follows on from the
learner having given the RIGHT reply to the first.

Each exchange has two questions:
1. gist — "What did they say?": three summaries in $native. Exactly one is right.
2. reply — "How do you reply?": three English replies. Exactly one is right.

RULES — every one of these matters
1. Every question has exactly one right answer. The other two are answers a
   person who MISHEARD the line would give.
2. gist: the two wrong summaries get one key fact wrong — when, who, how
   much, whether something happens or not (e.g. "stay tonight" becomes "come
   in early tomorrow" or "go home now").
3. reply: the right reply answers what was actually said. The two wrong replies
   are natural English but respond to a misheard version of the line. Never
   grade on politeness, tone or negotiating skill — a wrong answer must be
   wrong on the FACTS of what was said, so that no two answers could both be
   right.
4. Wrong replies restate the misheard fact, so the mistake shows in the words:
   good — "Tomorrow evening, right? OK." / bad — "I'll send it tomorrow
   evening, is that OK?" (a correct listener might also say that). Never use
   a proposal, preference, negotiation or question that a correct listener
   might also make.
5. Wrong replies must still be things people actually say. Do not write a
   reply that merely negates the request ("OK, I won't check them today",
   "I don't need a ticket"). Mishear a time, a day, a place, an object or a
   person instead.
6. Lines: 1 or 2 sentences, school-level vocabulary, no jargon.
7. No names, job titles or organisations inside the lines ("as your manager"
   is also banned). The one line of setting goes in setting_native only.
8. Each option is one sentence: English up to 15 words, $native up to 40
   characters.
9. Spread the right answer's position (0, 1, 2) across questions. Over the
   $questions questions, use each position at least $perPosition times.
10. Every English string gets a $native translation (native). Each of the
    three replies gets a one-sentence "why" in $native: why it is right, or
    what it misheard.
11. Fit the scenes to the learner's age, roles and areas above. Do not reuse
    the topics they already have.

OUTPUT SHAPE (keep the key names exactly; write $native in the *_native
fields; "answer" is the 0-based index of the right option)
```json
{
  "schema_version": "$scenesSchemaVersion",
  "type": "scenes",
  "native_language": "$native",
  "scenes": [
    {
      "topic": "Asked to stay late",
      "topic_native": "(topic in $native)",
      "setting_native": "(one line of setting in $native: where and when, never who)",
      "exchanges": [
        {
          "line": "Sorry to ask, but could you stay an extra hour tonight? The client moved the deadline to tomorrow morning.",
          "line_native": "(translation in $native)",
          "gist": {
            "options": ["(wrong: come in early tomorrow)", "(right: stay one hour tonight, deadline moved to tomorrow morning)", "(wrong: go home early tonight)"],
            "answer": 1
          },
          "reply": {
            "options": [
              { "text": "One hour is fine. What should I start on?", "native": "(translation)", "why": "(why it is right)" },
              { "text": "Sure, I'll come in early tomorrow. What time?", "native": "(translation)", "why": "(misheard: tonight as tomorrow morning)" },
              { "text": "Great, thanks! See you tomorrow then.", "native": "(translation)", "why": "(misheard: stay as go home)" }
            ],
            "answer": 0
          }
        },
        { "line": "...", "line_native": "...", "gist": { "options": ["...", "...", "..."], "answer": 2 }, "reply": { "options": [ { "text": "...", "native": "...", "why": "..." }, { "text": "...", "native": "...", "why": "..." }, { "text": "...", "native": "...", "why": "..." } ], "answer": 1 } }
      ]
    }
  ]
}
```
The example above only shows the shape. Do not write that topic; write $scenes new
scenes in the same shape, with real $native text in every *_native, native and
why field.''';
}
