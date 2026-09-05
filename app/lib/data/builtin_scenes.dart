/// The scenes that ship with the app, so there is something to do before the
/// first trip to the learner's own AI.
///
/// They are samples — everyday work and travel, easy, in every interface
/// language — and they are meant to be outgrown: the tree grows leaves on
/// them but never flowers. They are not rows in the database; they are merged
/// in at read time for the current language, so switching language switches
/// the words while every result and review, keyed by the same ids, stays.
library;

import '../domain/scene.dart';
import 'builtin_scenes_data.dart' as data;

/// Every built-in scene in [lang], falling back to English for a language the
/// data does not carry. Ordered for the learner's interests when given: the
/// kinds they chose first, in the order they chose them.
List<Scene> builtinScenes(String lang, {List<String> interests = const []}) {
  final raw = data.scenesFor(lang);
  final scenes = [for (final j in raw) Scene.fromJson(j)];
  if (interests.isEmpty) return scenes;
  int rank(Scene s) {
    final kind = data.kindOf(s.id);
    final i = interests.indexOf(kind);
    return i < 0 ? interests.length : i;
  }
  scenes.sort((a, b) => rank(a).compareTo(rank(b)));
  return scenes;
}

/// The topics of every built-in scene, in English, so the AI is told not to
/// write them again.
List<String> builtinTopics() => [for (final j in data.scenesFor('en')) '${j['topic']}'];

/// The one scene the walkthrough uses.
Scene? tutorialScene(String lang) =>
    builtinScenes(lang).where((s) => data.kindOf(s.id) == 'work').firstOrNull;
