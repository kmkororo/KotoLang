/// The sets that ship with the app, so there is something to do before the
/// first trip to the learner's own AI.
///
/// They are samples, and they are meant to be outgrown: the tree counts them
/// but never flowers on them. They are not rows in the database; they are
/// built at read time for the current language, so switching language
/// switches what is read about them while every result and review, keyed by
/// the same ids, stays where it was.
///
/// A language with no words of its own for a sample reads the English ones.
library;

import '../domain/field.dart';
import '../domain/scene.dart';
import 'sets/samples.dart';

/// Cached per language: the build is pure, the sources are constants, and
/// home asks for this on every rebuild.
final _cache = <String, List<Scene>>{};

/// Every sample, in [lang]. [interests] puts the fields the learner chose
/// first; the rest follow in their usual order, so nothing is hidden by not
/// having been chosen.
List<Scene> builtinScenes(String lang, {List<String> interests = const []}) {
  final all = _cache.putIfAbsent(lang, () => [for (final s in sampleSets) _build(s, lang)]);
  if (interests.isEmpty) return all;
  final wanted = interests.toSet();
  return [
    for (final s in all)
      if (wanted.contains(fieldOf(s))) s,
    for (final s in all)
      if (!wanted.contains(fieldOf(s))) s,
  ];
}

Scene _build(SampleSet s, String lang) {
  final t = s.text[lang] ?? s.text['en']!;
  // The translation is of English into the learner's language. Reading in
  // English there is nothing to translate into.
  final translate = lang != 'en' && s.text.containsKey(lang);
  final set = ReplyPredict(
    partnerName: t.partnerName,
    partner: Spoken(
      text: s.partner,
      native: translate ? t.partnerNative : '',
      stress: s.partnerStress,
    ),
    paraphrase: s.paraphrase,
    reply: SetChoice(
      options: s.replies,
      answer: 0,
      why: ['', ...t.replyWhy],
    ).arranged(optionOrder(s.id, 0)),
    trap: s.trap,
    predict: SetChoice(
      options: t.predict,
      answer: 0,
      why: ['', ...t.predictWhy],
    ).arranged(optionOrder(s.id, 1)),
    response: Spoken(
      text: s.response,
      native: translate ? t.responseNative : '',
      stress: s.responseStress,
    ),
  );
  return Scene.ofSet(
    id: s.id,
    label: t.scene,
    set: set,
    source: SceneSource.builtin,
    realmId: s.field,
    createdAt: 0,
  );
}

/// Where every sample happens, in English, so the learner's AI is told not
/// to write them again.
List<String> builtinTopics() => [for (final s in sampleSets) s.text['en']!.scene];

/// The one set the walkthrough uses: the first of the work samples.
Scene? tutorialScene(String lang) {
  for (final s in builtinScenes(lang)) {
    if (fieldOf(s) == 'work') return s;
  }
  return null;
}

/// Which of the four sample fields a built-in set belongs to.
String kindOf(String sceneId) {
  for (final s in sampleSets) {
    if (s.id == sceneId) return s.field;
  }
  return defaultFieldId;
}
