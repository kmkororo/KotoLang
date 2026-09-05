/// The debate pack: what the importer accepts, what it repairs, what it
/// refuses and why — then the same through the repository, where critiques
/// have to find their attempts and the prompt has to carry out what is owed.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/debate.dart';
import 'package:kotolang/domain/importer.dart' as imp;
import 'package:kotolang/domain/prompts.dart' as pr;

import 'repository_test.dart' show profileJson;

// ------------------------------------------------------------------ fixtures

Map<String, dynamic> grasp(String stem) => {
      'claim': {'answer': '$stem の主張', 'options': ['$stem の主張', 'ほか1', 'ほか2']},
      'reason': {'answer': '$stem の根拠', 'options': ['$stem の根拠', 'ほか1', 'ほか2']},
      'weak_point': {
        'answer': '$stem を確認せずに言っている',
        'options': ['$stem を確認せずに言っている', 'ほか1', 'ほか2']
      },
    };

Map<String, dynamic> rebuttal(String id, String strength, String? next,
        {List<String> moves = const ['concede', 'however', 'evidence'],
        String? outcome}) =>
    {
      'id': id,
      'strength': strength,
      'model': 'Model reply $id, said out loud to the other person in the room.',
      'moves': moves,
      'slots': {'x': 'headcount'},
      'next': next,
      'outcome': ?outcome,
    };

Map<String, dynamic> node(String id, List<Map<String, dynamic>> rebuttals) => {
      'id': id,
      'line': 'Line $id: we simply do not have the headcount to move the date.',
      'line_native': '$id の台詞',
      'grasp': grasp(id),
      'rebuttals': rebuttals,
    };

/// A sound three-deep tree: n1 -> n2a / n2b, each of those -> a leaf node.
Map<String, dynamic> debate({String topic = 'Pulling the date forward', String? event}) => {
      'topic': topic,
      'topic_native': '日程の前倒し',
      'event': ?event,
      'opponent': {'persona': 'sceptical manager', 'persona_native': '懐疑的な上司'},
      'your_position': 'We should move the date up by two weeks.',
      'your_position_native': '2週間前倒しすべき',
      'nodes': [
        node('n1', [
          rebuttal('r1a', 'strong', 'n2a'),
          rebuttal('r1b', 'weak', 'n2b', moves: ['however']),
          rebuttal('r1c', 'concede', null, moves: ['concede', 'close'], outcome: 'conceded'),
        ]),
        node('n2a', [
          rebuttal('r2aa', 'strong', 'n3'),
          rebuttal('r2ab', 'weak', 'n3', moves: ['however']),
          rebuttal('r2ac', 'concede', null, moves: ['concede'], outcome: 'conceded'),
        ]),
        node('n2b', [
          rebuttal('r2ba', 'strong', 'n3'),
          rebuttal('r2bb', 'weak', null, moves: ['however'], outcome: 'pressed'),
          rebuttal('r2bc', 'concede', null, moves: ['concede'], outcome: 'conceded'),
        ]),
        node('n3', [
          rebuttal('r3a', 'strong', null, outcome: 'won'),
          rebuttal('r3b', 'weak', null, moves: ['however']), // outcome left for the importer
          rebuttal('r3c', 'concede', null, moves: ['concede'], outcome: 'conceded'),
        ]),
      ],
    };

List<Map<String, dynamic>> chunks() => [
      {'id': 'c1', 'move': 'concede', 'text': 'I take your point on {x}, but', 'native': '…はその通りですが'},
      {'id': 'c2', 'move': 'evidence', 'text': 'the numbers from {x} say otherwise:', 'native': '数字は逆で'},
      {'id': 'c3', 'move': 'dance', 'text': 'this move does not exist', 'native': ''},
      {'id': 'c4', 'move': 'propose', 'text': '', 'native': 'empty text'},
    ];

String pack({
  List<Map<String, dynamic>>? chunksList,
  List<Map<String, dynamic>> debates = const [],
  List<Map<String, dynamic>> critiques = const [],
}) =>
    jsonEncode({
      'schema_version': '2.0',
      'type': 'pack',
      'native_language': 'Japanese',
      'chunks': ?chunksList,
      'debates': debates,
      'critiques': critiques,
    });

void main() {
  group('importer: pack', () {
    test('a sound pack normalises whole', () {
      final n = imp.normalisePack(jsonDecode(pack(chunksList: chunks(), debates: [debate()])));
      expect(n.rejected, isEmpty);
      expect(n.debates, hasLength(1));
      final t = n.debates.single;
      expect(t.nodes.map((x) => x.id), ['n1', 'n2a', 'n2b', 'n3']);
      expect(t.root.id, 'n1');
      expect(t.persona, 'sceptical manager');
      expect(t.positionNative, '2週間前倒しすべき');
    });

    test('chunks with no move or no words are dropped, the rest keep a content id', () {
      final n = imp.normalisePack(jsonDecode(pack(chunksList: chunks())));
      expect(n.chunks.map((c) => c.move), [Move.concede, Move.evidence]);
      expect(n.chunks.first.id, startsWith('chunk_'));
      // The same chunk pasted twice is one chunk.
      final twice = imp.normalisePack(jsonDecode(pack(chunksList: [...chunks(), ...chunks()])));
      expect(twice.chunks, hasLength(2));
    });

    test('the type is inferred from the shape when the AI leaves it out', () {
      final data = jsonDecode(pack(debates: [debate()])) as Map<String, dynamic>;
      data.remove('type');
      final v = imp.validate(data);
      expect(v.ok, isTrue);
      expect(v.type, 'pack');
    });

    test('a critique-only reply is a valid pack', () {
      final v = imp.validate(jsonDecode(pack(critiques: [
        {'attempt': 'a1', 'verdict_native': 'よい', 'better': ['Better.'], 'watch_native': '注意'}
      ])));
      expect(v.ok, isTrue);
      final p = imp.previewImport(pack(critiques: [
        {'attempt': 'a1', 'verdict_native': 'よい'}
      ]));
      expect(p.ok, isTrue);
      expect(p.type, 'pack');
      expect(p.critiques, 1);
    });

    test('an empty pack is refused', () {
      final v = imp.validate(jsonDecode(pack()));
      expect(v.ok, isFalse);
      expect(v.errors.single, contains('no debates, chunks or critiques'));
    });

    test('a leaf the AI forgot to close is closed the way its strength says', () {
      final t = imp.normalisePack(jsonDecode(pack(debates: [debate()]))).debates.single;
      final r3b = t.node('n3')!.rebuttals.firstWhere((r) => r.id == 'r3b');
      expect(r3b.isLeaf, isTrue);
      expect(r3b.outcome, Outcome.pressed);
      final r3a = t.node('n3')!.rebuttals.firstWhere((r) => r.id == 'r3a');
      expect(r3a.outcome, Outcome.won, reason: 'a written outcome is kept');
    });

    test('a missing answer among the options is put back, so the question can be answered', () {
      final d = debate();
      (d['nodes'] as List)[0]['grasp']['claim']['options'] = ['ほか1', 'ほか2'];
      final t = imp.normalisePack(jsonDecode(pack(debates: [d]))).debates.single;
      expect(t.root.grasp.claim.options, contains('n1 の主張'));
    });

    test('unknown moves are dropped rather than failing the tree', () {
      final d = debate();
      (d['nodes'] as List)[0]['rebuttals'][0]['moves'] = ['concede', 'shout', 'evidence'];
      final t = imp.normalisePack(jsonDecode(pack(debates: [d]))).debates.single;
      expect(t.root.rebuttals.first.moves, [Move.concede, Move.evidence]);
    });

    group('a tree is refused, with the reason, when', () {
      String? reasonFor(Map<String, dynamic> d) {
        final n = imp.normalisePack(jsonDecode(pack(debates: [d])));
        expect(n.debates, isEmpty);
        return n.rejected.single.reason;
      }

      test('a rebuttal points at a node that does not exist', () {
        final d = debate();
        (d['nodes'] as List)[0]['rebuttals'][0]['next'] = 'n9';
        expect(reasonFor(d), contains('n9'));
      });

      test('a node has no strong rebuttal', () {
        final d = debate();
        (d['nodes'] as List)[3]['rebuttals'][0]['strength'] = 'weak';
        expect(reasonFor(d), contains('no strong rebuttal'));
      });

      test('a node is missing one of the three things to catch', () {
        final d = debate();
        ((d['nodes'] as List)[1]['grasp'] as Map).remove('weak_point');
        expect(reasonFor(d), contains('weak_point'));
      });

      test('a node has no rebuttals at all', () {
        final d = debate();
        (d['nodes'] as List)[2]['rebuttals'] = <Map<String, dynamic>>[];
        expect(reasonFor(d), contains('no rebuttals'));
      });

      test('it runs deeper than three lines', () {
        final d = debate();
        // Give n3 a strong reply that carries on to a fourth node.
        (d['nodes'] as List)[3]['rebuttals'][0] = rebuttal('r3a', 'strong', 'n4');
        (d['nodes'] as List).add(node('n4', [
          rebuttal('r4a', 'strong', null, outcome: 'won'),
        ]));
        expect(reasonFor(d), contains('deeper'));
      });

      test('two nodes share an id', () {
        final d = debate();
        (d['nodes'] as List)[2]['id'] = 'n2a';
        expect(reasonFor(d), contains('twice'));
      });

      test('there is no topic', () {
        final d = debate()..remove('topic')..remove('topic_native');
        expect(reasonFor(d), 'no topic');
      });
    });

    test('a node nobody points at is left out, not fatal', () {
      final d = debate();
      (d['nodes'] as List).add(node('orphan', [rebuttal('ro', 'strong', null, outcome: 'won')]));
      final n = imp.normalisePack(jsonDecode(pack(debates: [d])));
      expect(n.rejected, isEmpty);
      expect(n.debates.single.node('orphan'), isNull);
    });

    test('the id is content-derived, and the event date takes part in it', () {
      final a = imp.normalisePack(jsonDecode(pack(debates: [debate()]))).debates.single;
      final b = imp.normalisePack(jsonDecode(pack(debates: [debate()]))).debates.single;
      final c = imp.normalisePack(jsonDecode(pack(debates: [debate(event: '2026-09-11')])))
          .debates
          .single;
      expect(a.id, b.id, reason: 'the same tree pasted twice is one tree');
      expect(c.id, isNot(a.id), reason: 'the same topic for a different day is another tree');
      expect(c.event, '2026-09-11');
      final bad = imp.normalisePack(jsonDecode(pack(debates: [debate(event: 'Thursday')])))
          .debates
          .single;
      expect(bad.event, isNull, reason: 'only a day key is an event');
    });

    test('a JSON round trip through the row shape loses nothing', () {
      final t = imp.normalisePack(jsonDecode(pack(debates: [debate()]))).debates.single;
      final back = [
        for (final n in jsonDecode(jsonEncode([for (final n in t.nodes) n.toJson()])))
          DebateNode.fromJson(Map<String, dynamic>.from(n as Map))
      ];
      expect(back.map((n) => n.id), t.nodes.map((n) => n.id));
      expect(back.first.grasp.weakPoint.answer, t.root.grasp.weakPoint.answer);
      expect(back.first.rebuttals.first.slots, {'x': 'headcount'});
      expect(back.last.rebuttals[1].outcome, Outcome.pressed);
    });
  });

  group('prompts: pack', () {
    test('the moves the prompt names are exactly the moves the app knows', () {
      expect(pr.argumentMoves, Move.values.map((m) => m.name).toList());
    });

    test('carries out what is owed, and asks for one debate per reply', () {
      final text = pr.packPrompt(
        uiLanguage: 'ja',
        events: [(date: '2026-09-11', note: '木曜のレビュー', who: '上司')],
        failures: [(topic: 'Pulling the date', node: 'n2a', kind: 'no_evidence_move', note: '')],
        attempts: [
          (
            id: 'att_1',
            topic: 'Pulling the date',
            line: 'We do not have the headcount.',
            youSaid: 'But we need to move faster.',
            moves: ['however']
          )
        ],
        needChunks: true,
      );
      expect(text, contains('2026-09-11: 木曜のレビュー — with: 上司'));
      expect(text, contains('no_evidence_move'));
      expect(text, contains('"attempt": "att_1"'));
      expect(text, contains('ONE DEBATE PER REPLY'));
      expect(text, contains('"schema_version": "2.0"'));
      expect(text, contains('0. chunks'), reason: 'asked for when none are stored');
      expect(text, contains('Japanese'));
    });

    test('leaves the chunk library out once it exists', () {
      final text = pr.packPrompt(
          uiLanguage: 'en', events: const [], failures: const [], attempts: const []);
      expect(text, isNot(contains('0. chunks')));
      expect(text, contains('leave "critiques" as an empty array'));
    });
  });

  group('repository: pack', () {
    late AppDatabase db;
    late Repository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = Repository(db, rng: Random(1));
    });
    tearDown(() async => db.close());

    test('chunks and debates land, and a repeat paste lands on itself', () async {
      final first = await repo.importPack(pack(chunksList: chunks(), debates: [debate()]),
          uiLanguage: 'ja');
      expect(first.ok, isTrue);
      expect(first.chunks, 2);
      expect(first.debates, 1);
      expect(first.rejected, isEmpty);

      await repo.importPack(pack(chunksList: chunks(), debates: [debate()]), uiLanguage: 'ja');
      expect(await repo.chunks(), hasLength(2));
      expect(await repo.debates(), hasLength(1));
    });

    test('a refused tree is named in the outcome, and the rest still import', () async {
      final bad = debate(topic: 'Broken');
      (bad['nodes'] as List)[0]['rebuttals'][0]['next'] = 'nowhere';
      final out = await repo.importPack(pack(debates: [debate(), bad]), uiLanguage: 'ja');
      expect(out.ok, isTrue);
      expect(out.debates, 1);
      expect(out.rejected.single.topic, '日程の前倒し');
      expect(out.rejected.single.reason, contains('nowhere'));
    });

    test('critiques attach to the attempts still waiting, and strays are counted', () async {
      await repo.importPack(pack(debates: [debate()]), uiLanguage: 'ja');
      final tree = (await repo.debates()).single;
      final a = await repo.recordAttempt(
        tree: tree,
        node: tree.root,
        youSaid: 'But we need to go faster.',
        moves: [Move.however],
        closest: tree.root.rebuttals[1],
      );
      expect((await repo.attempts(pendingOnly: true)), hasLength(1));

      final out = await repo.importPack(
        pack(critiques: [
          {'attempt': a.id, 'verdict_native': '型はできている', 'better': ['Better one.'], 'watch_native': '注意'},
          {'attempt': 'att_from_another_phone', 'verdict_native': 'x'},
        ]),
        uiLanguage: 'ja',
      );
      expect(out.critiques, 1);
      expect(out.unmatchedCritiques, 1);

      final stored = (await repo.attempts()).single;
      expect(stored.critique?.verdictNative, '型はできている');
      expect(stored.critique?.better, ['Better one.']);
      expect(stored.closest, 'r1b');
      expect(stored.closestStrength, Strength.weak);
      expect(await repo.attempts(pendingOnly: true), isEmpty);
    });

    test('captures and failures are carried out when debates come back, not before', () async {
      await repo.addCapture(note: '木曜のレビュー', date: '2026-09-11', who: '上司');
      await repo.importPack(pack(debates: [debate()]), uiLanguage: 'ja');
      expect(await repo.captures(pendingOnly: true), isEmpty,
          reason: 'the debates that came back were built from it');

      // New things waiting, after that import.
      await repo.addCapture(note: '来週の1on1', date: '2026-09-15');
      final tree = (await repo.debates()).single;
      await repo.recordFailure(tree: tree, node: tree.root, kind: 'no_evidence_move');

      // A critique-only reply is not new material; nothing is consumed by it.
      await repo.importPack(pack(critiques: [
        {'attempt': 'x', 'verdict_native': 'y'}
      ]), uiLanguage: 'ja');
      expect(await repo.captures(pendingOnly: true), hasLength(1));
      expect(await repo.failures(pendingOnly: true), hasLength(1));

      await repo.importPack(pack(debates: [debate(topic: 'Another topic')]), uiLanguage: 'ja');
      expect(await repo.captures(pendingOnly: true), isEmpty);
      expect(await repo.failures(pendingOnly: true), isEmpty);
      expect(await repo.captures(), hasLength(2), reason: 'kept and marked, never deleted');
    });

    test('the pack prompt is built from what is waiting on this phone', () async {
      await repo.importProfile(profileJson(['Work']), uiLanguage: 'ja');
      // Only areas the learner has actually opened are named to the AI.
      await repo.markRealmsUnlocked((await repo.realms()).map((r) => r.id).toList());
      await repo.addCapture(note: '来週の1on1', date: '2026-09-15');
      await repo.importPack(pack(debates: [debate()]), uiLanguage: 'ja');
      // The import above consumed that capture; add one that is still pending.
      await repo.addCapture(note: '木曜のレビュー', date: '2026-09-11', who: '上司');
      final tree = (await repo.debates()).single;
      final a = await repo.recordAttempt(
          tree: tree, node: tree.root, youSaid: 'We need this.', moves: [Move.however]);
      await repo.recordFailure(tree: tree, node: tree.root, kind: 'weak_point_missed');

      final text = await repo.packPromptText(uiLanguage: 'ja');
      expect(text, contains('2026-09-11: 木曜のレビュー — with: 上司'));
      expect(text, isNot(contains('来週の1on1')), reason: 'already carried out');
      expect(text, contains('Pulling the date forward / n1: weak_point_missed'));
      expect(text, contains('"attempt": "${a.id}"'));
      expect(text, contains('"they_said": "Line n1:'));
      expect(text, contains('- Pulling the date forward'), reason: 'existing topics are named');
      expect(text, contains('0. chunks'), reason: 'no chunk library stored yet');
      expect(text, contains('Areas they study: Work'));

      await repo.importPack(pack(chunksList: chunks()), uiLanguage: 'ja');
      expect(await repo.packPromptText(uiLanguage: 'ja'), isNot(contains('0. chunks')));

      final crit = await repo.critiquePromptText(uiLanguage: 'ja');
      expect(crit, contains('"attempt": "${a.id}"'));
      expect(crit, isNot(contains('debates')), reason: 'critiques only');
    });

    test('a backup carries the debate tables, and a factory reset clears them', () async {
      await repo.importPack(pack(chunksList: chunks(), debates: [debate()]), uiLanguage: 'ja');
      await repo.addCapture(note: 'memo');
      final tree = (await repo.debates()).single;
      await repo.recordAttempt(tree: tree, node: tree.root, youSaid: 'x', moves: const []);
      await repo.recordFailure(tree: tree, node: tree.root, kind: 'pressed');

      final dump = await repo.exportAll();
      final data = dump['data'] as Map<String, dynamic>;
      for (final t in ['chunks', 'debates', 'attempts', 'captures', 'failures']) {
        expect((data[t] as List), isNotEmpty, reason: '$t must be in the backup');
      }

      await repo.factoryReset();
      expect(await repo.chunks(), isEmpty);
      expect(await repo.debates(), isEmpty);
      expect(await repo.attempts(), isEmpty);
      expect(await repo.captures(), isEmpty);
      expect(await repo.failures(), isEmpty);

      // And the backup restores them.
      await repo.restore(dump);
      expect(await repo.debates(), hasLength(1));
      expect((await repo.debates()).single.node('n3'), isNotNull);
    });

    test('resetting progress forgets attempts and failures but keeps the trees', () async {
      await repo.importPack(pack(debates: [debate()]), uiLanguage: 'ja');
      final tree = (await repo.debates()).single;
      await repo.recordAttempt(tree: tree, node: tree.root, youSaid: 'x', moves: const []);
      await repo.addCapture(note: 'memo');
      await repo.resetProgress();
      expect(await repo.attempts(), isEmpty);
      expect(await repo.debates(), hasLength(1));
      expect(await repo.captures(), hasLength(1), reason: 'the learner\'s own notes are not progress');
    });
  });
}
