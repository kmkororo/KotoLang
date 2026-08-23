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

import '../core/l10n/languages.dart';

const schemaVersion = '1.0';

class PromptVersions {
  static const profile = 'PROFILE_PROMPT_V1';
  static const material = 'MATERIAL_PROMPT_V1';
  static const audit = 'AUDIT_PROMPT_V1';
  static const addRealm = 'ADD_REALM_PROMPT_V1';
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

  return '''
You are writing English study material for one specific person.

THE LEARNER
English level (CEFR): $level
Roles: $rolesText
Where they use English: $prioText

THE AREA
Area: $realmName${realmNative.isNotEmpty ? ' ($realmNative)' : ''}
Situations: $ctxText

ALREADY STORED — do not repeat these
$existing

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
