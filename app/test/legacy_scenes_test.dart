/// A conversation kept from before the sets is counted nowhere a learner can
/// see it. On the phone it made home believe the learner had questions of
/// their own, so "today's question" drew from them, found none it could play,
/// and said there were none — with the samples one tap away.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kotolang/app.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/scene.dart';

import 'fixtures.dart' show pack, scene;

void main() {
  test('only sets are offered; a conversation from before is not', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = Repository(db);
    await repo.saveUiLanguage('ja');
    await db.into(db.scenes).insert(sceneToRow(const Scene(
          id: 'old_one',
          title: 'Old',
          turns: [
            Turn(line: 'An old line?', replies: [
              Reply(text: 'a', correct: true),
              Reply(text: 'b'),
              Reply(text: 'c'),
            ]),
          ],
          realmId: 'work',
          createdAt: 0,
        )));

    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(c.dispose);

    var all = await c.read(allScenesProvider.future);
    expect(all.where((s) => !s.isBuiltin), isEmpty);
    expect(all.every((s) => s.playable), isTrue);

    await repo.importScenes(pack([scene('New')]), uiLanguage: 'ja', field: 'work');
    c.invalidate(allScenesProvider);
    all = await c.read(allScenesProvider.future);
    expect([for (final s in all) if (!s.isBuiltin) s.label], ['New']);
  });
}
