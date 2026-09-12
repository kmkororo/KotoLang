/// The conversations that ship with the app, so there is something to do
/// before the first trip to the learner's own AI.
///
/// They are samples, and they are meant to be outgrown: the tree grows leaves
/// on them but never flowers. They are not rows in the database; they are
/// merged in at read time for the current language, so switching language
/// switches the words while every result and review, keyed by the same ids,
/// stays where it was.
///
/// A language with no overlay is not a language with no samples. The English
/// is in `scenes/base.dart` and is the same for everyone; an overlay only
/// adds the glosses read *after* a turn has been answered. Missing them costs
/// a beginner something, but far less than having nothing to play — and the
/// translation rung of the ladder takes those glosses away in the end anyway.
library;

import '../domain/field.dart';
import '../domain/scene.dart';
import 'scenes/base.dart';
import 'scenes/overlay.dart';
import 'scenes/overlay_ja.dart';

/// The languages whose samples have been translated. Everything else falls
/// through to English.
const _overlays = <String, Map<String, SceneText>>{
  'ja': overlayJa,
};

/// Cached per language: the merge is pure, the sources are constants, and
/// home asks for this on every rebuild.
final _cache = <String, List<Scene>>{};

/// Every sample, in [lang]. [interests] is accepted so a caller can ask for
/// the fields the learner chose to come first; the rest follow in their usual
/// order, so nothing is hidden by not having been chosen.
List<Scene> builtinScenes(String lang, {List<String> interests = const []}) {
  final all = _cache.putIfAbsent(lang, () => _merged(lang));
  if (interests.isEmpty) return all;
  final wanted = interests.toSet();
  return [
    for (final s in all)
      if (wanted.contains(fieldOf(s))) s,
    for (final s in all)
      if (!wanted.contains(fieldOf(s))) s,
  ];
}

List<Scene> _merged(String lang) {
  final words = _overlays[lang];
  if (words == null) return baseScenes;
  return [for (final s in baseScenes) _dress(s, words[s.id])];
}

/// Puts one language's words onto one conversation. A conversation the
/// overlay does not mention, or mentions with the wrong number of turns, is
/// left in English rather than half-translated.
Scene _dress(Scene scene, SceneText? text) {
  if (text == null || text.turns.length != scene.turns.length) return scene;
  return Scene(
    id: scene.id,
    title: scene.title,
    titleNative: text.title,
    situation: scene.situation,
    settingNative: text.setting,
    windowMs: scene.windowMs,
    turns: [
      for (var i = 0; i < scene.turns.length; i++)
        _dressTurn(scene.id, i, scene.turns[i], text.turns[i]),
    ],
    source: scene.source,
    realmId: scene.realmId,
    createdAt: scene.createdAt,
  );
}

Turn _dressTurn(String sceneId, int index, Turn turn, TurnText text) {
  // The overlay is written right-first, the way the English is authored, and
  // the replies on the turn have already been moved. Putting the translations
  // through the same shuffle is what keeps each one on its own reply.
  final natives = text.replies.length == turn.replies.length
      ? arrangeBy(optionOrder(sceneId, index), text.replies)
      : null;
  return Turn(
    type: turn.type,
    line: turn.line,
    lineNative: text.line,
    keyWord: turn.keyWord,
    confusable: turn.confusable,
    facts: turn.facts,
    replies: natives == null
        ? turn.replies
        : [
            for (var i = 0; i < turn.replies.length; i++)
              Reply(
                text: turn.replies[i].text,
                native: natives[i],
                correct: turn.replies[i].correct,
                missedSlot: turn.replies[i].missedSlot,
              )
          ],
  );
}

/// The titles of every sample, in English, so the learner's AI is told not to
/// write them again.
List<String> builtinTopics() => [for (final s in baseScenes) s.title];

/// The one conversation the walkthrough uses: the shortest of the work
/// samples. The first thing anybody plays should end before they start
/// wondering how long it goes on for.
Scene? tutorialScene(String lang) {
  final work = [
    for (final s in builtinScenes(lang))
      if (fieldOf(s) == 'work') s
  ];
  if (work.isEmpty) return null;
  return work.reduce((a, b) => b.turns.length < a.turns.length ? b : a);
}

/// Which of the four sample fields a built-in conversation belongs to.
String kindOf(String sceneId) {
  for (final s in baseScenes) {
    if (s.id == sceneId) return fieldOf(s);
  }
  return defaultFieldId;
}
