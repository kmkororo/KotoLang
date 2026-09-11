/// The conversations that ship with the app, so there is something to do
/// before the first trip to the learner's own AI.
///
/// They are samples — everyday work and travel, easy, in every interface
/// language — and they are meant to be outgrown: the tree grows leaves on
/// them but never flowers. They are not rows in the database; they are merged
/// in at read time for the current language, so switching language switches
/// the words while every result and review, keyed by the same ids, stays.
///
/// **Empty while the samples are rewritten.** The thirty that shipped before
/// were written for a shape the app no longer has — two exchanges, a gist
/// question, no key word and no window — and the brief for this rebuild says
/// to write them again rather than carry them over. Until they are here the
/// app has nothing to offer before the learner's own AI, which is why the
/// setup no longer offers to try a sample first.
library;

import '../domain/scene.dart';

List<Scene> builtinScenes(String lang, {List<String> interests = const []}) =>
    const [];

/// The titles of every built-in conversation, in English, so the AI is told
/// not to write them again.
List<String> builtinTopics() => const [];

/// The one conversation the walkthrough uses, when there is one.
Scene? tutorialScene(String lang) => builtinScenes(lang).firstOrNull;

/// Which of the four sample fields a built-in conversation belongs to.
String kindOf(String sceneId) => 'work';
