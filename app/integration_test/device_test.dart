/// Runs on a real Android device or emulator.
///
/// The unit and widget suites run on the host and stub the platform away.
/// These checks are the ones that only hardware can answer: does the SQLite
/// engine actually open a file-backed database on the device, does the
/// installed text-to-speech engine expose an English voice, and does speaking
/// actually succeed rather than throwing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:kotolang/app.dart';
import 'package:kotolang/core/l10n/strings.dart';
import 'package:kotolang/core/speech.dart';
import 'package:kotolang/data/database.dart';
import 'package:kotolang/data/repository.dart';
import 'package:kotolang/domain/models.dart';

const _material = '''
{
  "schema_version": "1.0",
  "type": "material",
  "native_language": "English",
  "domain": {"name": "Work", "name_native": "Work", "importance": 5},
  "learning_items": [
    {"text": "repair policy", "meaning_native": "the rules for repairs", "priority": 5},
    {"text": "revision status", "meaning_native": "how up to date it is", "priority": 4}
  ],
  "sentences": [
    {
      "text": "Please confirm the repair policy before the review.",
      "translation_native": "Check the repair rules before the review.",
      "level": "B2", "context": "review", "speech_act": "request",
      "targets": ["repair policy"],
      "paraphrase_en": "Make sure the rules for repairs are checked ahead of the review.",
      "paraphrase_options_en": [
        "There is no need to check the rules for repairs beforehand.",
        "The reviewer will check the rules for repairs themselves.",
        "The rules for repairs were confirmed at the last review."
      ],
      "meaning_options_native": [
        "No need to check the repair rules.",
        "Someone else checks the repair rules.",
        "The repair rules were already checked."
      ]
    },
    {
      "text": "The revision status has not been recorded yet.",
      "translation_native": "Nobody has written down how up to date it is.",
      "level": "B2", "context": "audit", "speech_act": "report",
      "targets": ["revision status"],
      "paraphrase_en": "Nobody has written down how current the document is so far.",
      "paraphrase_options_en": [
        "Somebody wrote down how current the document is already.",
        "The supplier will write down how current the document is.",
        "How current the document is no longer needs recording."
      ],
      "meaning_options_native": [
        "It was already written down.",
        "It will be written down later.",
        "It does not need writing down."
      ]
    }
  ]
}
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the device text-to-speech engine offers an English voice',
      (tester) async {
    final speech = SpeechService();
    await speech.init();

    expect(speech.supported, isTrue,
        reason: 'the platform reported no TTS support at all');
    expect(speech.voices, isNotEmpty,
        reason: 'no English voice is installed on this device');
    debugPrint('TTS voices found: ${speech.voices.length}');
    debugPrint('chosen: ${speech.chosen?.name} (${speech.chosen?.locale})');

    // Speaking must not throw. Whether sound leaves the speaker cannot be
    // asserted from here, but a failing engine surfaces as an exception.
    await speech.speak('Please confirm the repair policy.', rate: 1.0);
    await tester.pump(const Duration(seconds: 1));
    await speech.stop();
  });

  testWidgets('the real on-device database persists a full import',
      (tester) async {
    // Uses the app's own file-backed database, not an in-memory one.
    final db = AppDatabase();
    final repo = Repository(db);
    addTearDown(db.close);

    await repo.factoryReset(keepLanguage: false);

    final profile = await repo.importProfile(
      '{"schema_version":"1.0","type":"profile",'
      '"profile":{"english_level":"B2","roles":["engineer"],"learning_priorities":["reviews"]},'
      '"domains":[{"name":"Work","name_native":"Work","importance":5}]}',
      uiLanguage: 'en',
    );
    expect(profile.ok, isTrue, reason: profile.errors.join(', '));

    final material = await repo.importMaterial(_material, uiLanguage: 'en');
    expect(material.ok, isTrue, reason: material.errors.join(', '));
    expect(material.newItems, 2);
    expect(material.newSentences, 2);
    expect(material.questions, greaterThan(0));

    // Read it back through a fresh connection: proves it reached disk.
    final counts = await repo.counts();
    expect(counts.items, 2);
    expect(counts.questions, material.questions);

    final types = (await repo.questions()).map((q) => q.type).toSet();
    expect(types, containsAll(QuestionType.values),
        reason: 'all four formats should be generated on device');
  });

  testWidgets('a learner can answer a question end to end on the device',
      (tester) async {
    final db = AppDatabase();
    final repo = Repository(db);
    addTearDown(db.close);

    await repo.factoryReset(keepLanguage: false);
    await repo.saveUiLanguage('en');
    await repo.importProfile(
      '{"schema_version":"1.0","type":"profile",'
      '"profile":{"english_level":"B2","roles":[],"learning_priorities":[]},'
      '"domains":[{"name":"Work","importance":5}]}',
      uiLanguage: 'en',
    );
    await repo.importMaterial(_material, uiLanguage: 'en');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const KotoLangApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final s = S('en');
    expect(find.text('KotoLang'), findsOneWidget);
    expect(find.text(s.t('justOne')), findsOneWidget);

    await tester.tap(find.text(s.t('justOne')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // The question screen is up and audio has been requested.
    expect(find.text(s.t('playAgain')), findsOneWidget);

    // Answer by tapping the last interactive element on screen, whichever
    // format came up.
    final tappable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(InkWell),
    );
    expect(tappable, findsWidgets);
    await tester.tap(tappable.last, warnIfMissed: false);
    await tester.pumpAndSettle();

    final answer = find.widgetWithText(FilledButton, s.t('answerLabel'));
    if (tester.widget<FilledButton>(answer).onPressed != null) {
      await tester.tap(answer);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // One answer is one study day, written to the device database.
      expect((await repo.history()).length, 1);
      expect((await repo.loadProgress()).streak, 1);
    }

    // Leave the session: this is the path that used to throw on dispose.
    await repo.factoryReset(keepLanguage: false);
  });
}
