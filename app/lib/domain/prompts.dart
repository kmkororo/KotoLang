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

const schemaVersion = '1.0';

/// The debate pack is a different shape from the material formats, so it has
/// its own version; the importer accepts both for ever.
const packSchemaVersion = '2.0';

/// Scenes: read the replies, hear the line once, answer inside the window.
/// The importer accepts every version for ever.
const scenesSchemaVersion = '4.0';

class PromptVersions {
  static const profile = 'PROFILE_PROMPT_V1';
  static const material = 'MATERIAL_PROMPT_V1';
  static const audit = 'AUDIT_PROMPT_V1';
  static const addRealm = 'ADD_REALM_PROMPT_V1';
  static const pack = 'PACK_PROMPT_V1';
  static const critique = 'CRITIQUE_PROMPT_V1';
  static const scenes = 'SCENES_PROMPT_V4';
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

/// The conversations, for the learner's own assistant.
///
/// The whole exercise rests on one thing, so the prompt is built around it:
/// the three replies must all be natural, and only the sound of the line may
/// decide which is right. Everything else here — the three types, the tests
/// to run before answering, the ban on invented names — is there to keep that
/// true, because a reply that gives itself away turns listening practice into
/// reading practice and nothing in the app can tell the difference afterwards.
///
/// Nothing here asks for a difficulty. How hard this is belongs to the
/// ladder: the same line at 1.6× with noise over it is a harder question than
/// the same line at 1.0×, and that is the axis the app moves. Asking the AI
/// for harder sentences as well would make two things measure one.
String scenesPrompt({
  required String uiLanguage,
  String level = 'A2',
  String ageBand = '',
  List<String> roles = const [],
  List<String> priorities = const [],
  List<String> areas = const [],
  List<String> existingTopics = const [],
  String field = '',
  ({int rightPct, int firstTimePct, int turns})? recent,
  List<String> tendencies = const [],
  int scenes = 5,
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
    person.write('\n- This set is about: $field. Every one of the $scenes '
        'conversations happens there; the settings differ, the field does not.');
  }

  final recentText = recent == null
      ? ''
      : '\n## HOW THEY HAVE BEEN DOING\n\n'
          'Over their last ${recent.turns} turns: ${recent.rightPct}% right, '
          '${recent.firstTimePct}% caught on the first hearing, inside the window.\n';

  final tendencyText = tendencies.isEmpty
      ? ''
      : '\n## WHAT THEY KEEP MISHEARING\n\n${list(tendencies)}\n\n'
          'Aim one or two of the $scenes conversations at these.\n';

  final topicText = existingTopics.isEmpty
      ? ''
      : '\n## CONVERSATIONS THEY ALREADY HAVE\n\n'
          'Do not repeat these, and do not write a near-twin of one — '
          '"Code review timing" after "Code review submission" is a repeat.\n\n'
          '${list(existingTopics)}\n';

  return '''
You are writing listening practice for one person learning English.

They hear a line of speech **once**, then choose one of three replies. They
never see the line written down. A machine can translate for them; what it
cannot do is keep up with a conversation in real time. That is what this
practice is for.

## THE PERSON

$person
$recentText$tendencyText$topicText
## WHAT TO WRITE

$scenes conversations. Output JSON only, no commentary.

A conversation is 1 to 5 turns. **Vary the length across the set.** A quick
exchange in a corridor is one turn; a phone call about a change of plan is
four or five. Do not make them all the same length.

Each turn is: the other person says one line, and the learner picks one of
three replies.

## THE ONE RULE THAT MATTERS

**The three replies must all be natural, and only the sound of the line may
decide which is right.**

Test it like this, for every turn you write, before you output it:

> Hide the line. Show only the situation and the three replies to a native
> speaker. If they can tell which one is correct, the turn is broken.

A reply is broken if it is rude, off-topic, ungrammatical, or obviously
strange. Someone who misheard the line must be able to choose it without
feeling that they are choosing something odd.

## THE THREE TYPES

Mix them across the set: about half `keyword`, a quarter `polarity`, a
quarter `multiFact`. Do not make a whole conversation one type; mix within a
conversation too.

### `keyword` — one word decides

A single word in the line carries the meaning, and a word that **sounds like
it** would change that meaning. The learner has to tell the two apart by ear.

Three tests. A turn that fails any of them is not a `keyword` turn.

**1. The pair must sound alike.** Not opposites in meaning — pairs that ears
actually confuse: twelve and twenty, thirteen and thirty, fifteen and fifty,
Tuesday and Thursday, fourteen and forty, Monday and Sunday, walk and work,
can and cat. `noon` and `night` are not such a pair. Neither are `better` and
`worse`: they mean the opposite, and sound nothing alike, so nothing is being
heard — only understood.

**2. The line must not contain the other word.** "Can we talk at three
instead of two?" names both, so anyone who caught the sentence knows which is
which. There is nothing left to mishear. Put the key word in the line and
leave its pair out.

**3. Swapping them must still make sense.** Replace the key word with its
pair and read the line again. It has to be a grammatical sentence, and one
the same person could plausibly have said in the same situation. "I will walk
home" fails: swap in `work` and "I will work home" is not English, so the
learner rules the wrong reply out without hearing anything. If the swap turns
the line into nonsense, the turn measures nothing.

Test three is the one that catches the most. Do it on every `keyword` turn
before you output it.

```json
{
  "type": "keyword",
  "line": "The handover's on Thursday, so I'll need the file by Wednesday night.",
  "keyWord": "Thursday",
  "confusable": "Tuesday",
  "replies": [
    { "text": "Thursday — I'll have it ready the evening before.", "correct": true },
    { "text": "Got it, Tuesday. I'll finish up over the weekend, then.", "correct": false },
    { "text": "Is there any chance of another day? That week is full.", "correct": false }
  ],
  "restate": "It's the Thursday handover, so the file has to be in the night before.",
  "translations": { "line": "...", "replies": ["...", "...", "..."] }
}
```

**Do not write two replies that are the same sentence with one word changed.**
Change the wording as well, the way real people vary. Two near-identical
replies tell the learner that the answer is one of those two, and the third
becomes decoration.

### `polarity` — a reversing word decides

`not`, `can't`, `unless`, `without`, `never`, `hardly`. Miss it and the
meaning flips. This is where mishearing costs the most in real life.

**One of the two wrong replies must be the one a person who missed the
reversing word would naturally choose.** That is what makes a wrong answer
worth something: it says exactly what went wrong.

```json
{
  "type": "polarity",
  "line": "I won't be able to join unless the client call gets cancelled.",
  "keyWord": "unless",
  "confusable": "if",
  "replies": [
    { "text": "Understood — so only if that call drops off.", "correct": true },
    { "text": "Great, I'll save you a seat.", "correct": false },
    { "text": "Shall I move it to the afternoon instead?", "correct": false }
  ],
  "restate": "Only if that client call falls through can I make it.",
  "translations": { "line": "...", "replies": ["...", "...", "..."] }
}
```

### `multiFact` — two facts must both be caught

Time and place, person and place, day and time. The learner has to hold both
and check them.

**Each wrong reply drops exactly one of the facts, and says which one in
`missedSlot`.** A wrong answer then points at the thing that was missed, and
the same weakness can be practised again later.

Here the three replies *are* parallel in shape. That is correct for this
type: what differs is which fact was caught, and all three are natural
confirmations.

```json
{
  "type": "multiFact",
  "line": "Let's meet at the west exit at six, not the ticket gate.",
  "facts": [
    { "slot": "place", "value": "west exit", "confusable": "ticket gate" },
    { "slot": "time",  "value": "six",       "confusable": "seven" }
  ],
  "replies": [
    { "text": "West exit at six. See you then.", "correct": true },
    { "text": "Ticket gate at six — see you there.", "correct": false, "missedSlot": "place" },
    { "text": "West exit at seven, then.", "correct": false, "missedSlot": "time" }
  ],
  "restate": "Six in the evening, by the west exit — not the gate.",
  "translations": { "line": "...", "replies": ["...", "...", "..."] }
}
```

## RESTATE

Every turn carries a `restate`: what the person says when the learner misses
the moment to reply. **Say the same thing in different words.** Repeating the
sentence exactly would make it a second listen, which this practice does not
give.

## THE LINES THEMSELVES

- One to three sentences. Spoken English, not written English.
- Only what this person would actually hear.
- Invent nothing about the learner's world. You were told what they do and
  where they want English; everything else is unknown to you.
- **People are roles, never names.** "the reviewer", "someone on the team",
  "the person covering for her" — not Sarah, not David. A name you make up is
  a colleague they do not have, and the learner notices.
- **Tools are kinds, never products.** "the team channel", "chat", "the
  tracker", "email" — not the names of the apps. The same goes for companies.
- No jargon and no idioms that belong to one country only.
- The line must stand on its own. The learner has the situation and nothing
  else, so a line that needs earlier context is unusable.
- On a later turn the line may answer the reply the learner just gave, but it
  must still make sense whichever reply they chose.

## WINDOW

Each conversation carries `windowMs`: how long the learner has to reply,
after the line ends.

- A hurried exchange, someone on their way out: 2000
- Ordinary talk: 3000
- Unhurried, someone thinking aloud: 4000

**Vary it across the set.** The gap between turns is what real conversation
is made of; a fixed window would take that away.

## OUTPUT

```json
{
  "schema_version": "4.0",
  "type": "scenes",
  "native_language": "$native",
  "scenes": [
    {
      "title": "Moving a deadline",
      "titleNative": "...",
      "situation": "...",
      "settingNative": "...",
      "windowMs": 3000,
      "turns": [ ... ]
    }
  ]
}
```

- `title` in English, `titleNative` in $native.
- `settingNative` is one line of setting in $native. Where they are, never who
  the other person is — that would give the answer away.
- `translations.line` and `translations.replies` in $native. Natural
  translation, not word for word. The learner reads these only after
  answering.

## BEFORE YOU ANSWER

Go through every turn once more:

1. Hide the line. Can the three replies alone give the answer away? If yes,
   rewrite.
2. Are all three replies something a real person would say here?
3. `keyword` and `polarity`: are any two replies the same sentence with one
   word swapped? If yes, rewrite the wording.
4. `polarity`: does one wrong reply belong to someone who missed the
   reversing word?
5. `multiFact`: does each wrong reply drop exactly one fact, and name it?
6. Is `restate` different wording, not the same sentence?
7. Do the conversations vary in length, and the windows in size?
8. Did you invent anything about the learner's world — a name, a company, a
   product — that you were not told?
9. `keyword`: swap the pair into the line. Is it still a grammatical sentence
   the same person could have said?

Output the JSON and nothing else.
''';
}

/// The learner's own results, for the assistant that has been writing their
/// conversations. Nothing comes back into the app: the answer is coaching to
/// read, so it asks for plain prose in the learner's own language rather than
/// JSON.
String feedbackPrompt({
  required String uiLanguage,
  required String field,
  required String level,
  required int scenesDone,
  required int rightPct,
  required int firstTimePct,
  required List<({String topic, String line, String? slot})> misses,
}) {
  final native = languageFor(uiLanguage).englishName;
  final missText = misses.isEmpty
      ? '  (nothing missed)'
      : misses
          .map((m) => '  - topic: ${m.topic}\n'
              '    they said: "${m.line}"\n'
              '    missed: ${m.slot ?? 'the line as a whole'}')
          .join('\n');

  return '''
You are coaching one person who is learning to understand spoken English by
ear (CEFR $level). They practise with short conversations: the three possible
replies are on screen first, then one line is spoken once, and they choose
before a short window closes. So a miss is a hearing, not a reading.

THEIR RESULTS IN THE AREA "$field"
- conversations finished: $scenesDone
- chose the right reply: $rightPct% of the time
- got it on the first hearing, inside the window: $firstTimePct% of the time

WHAT THEY MISSED
$missText

WHAT TO WRITE BACK
1. One short paragraph: the pattern behind the misses, in plain words. Name
   the kind of thing they mishear (numbers, times, negatives, places, who is
   doing what), not the individual mistakes. A reply chosen too slowly is a
   different problem from one chosen wrongly; say which you are seeing.
2. Three things to listen for next time, one line each, concrete enough to
   act on while listening.
3. One short paragraph: what is already working, so they know what to keep.

RULES
- Write in $native. The learner reads this, not a program.
- No JSON, no code blocks, no headings — just the three parts above.
- Do not invent mistakes that are not in the list.
- Under 200 words in total.
''';
}
