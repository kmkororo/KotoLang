/// Application shell: providers, theme, and the routing decision that depends
/// on how far the learner has got through setup.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/languages.dart';
import 'core/l10n/strings.dart';
import 'core/share_intake.dart';
import 'core/speech.dart';
import 'core/util.dart';
import 'data/database.dart';
import 'data/repository.dart';
import 'data/builtin_scenes.dart';
import 'domain/importer.dart' as imp;
import 'domain/models.dart';
import 'domain/progress_service.dart';
import 'domain/scene.dart';
import 'domain/skills.dart';
import 'features/first_run_screen.dart';
import 'features/home_screen.dart';
import 'features/onboarding_screens.dart';
import 'features/record_screen.dart';
import 'features/scene_pack_screen.dart';
import 'features/settings_screen.dart';

// ---------------------------------------------------------------- providers

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = Provider<Repository>((ref) => Repository(ref.watch(databaseProvider)));

final speechProvider = Provider<SpeechService>((ref) => SpeechService());

/// Everything the shell needs before it can decide what to show.
class Boot {
  final String? uiLanguage;
  final AppSettings settings;
  final Progress progress;
  final UserProfile? profile;
  final int realmCount;

  /// Areas the learner has actually opened. Material can only be built for
  /// one of these, so a profile whose areas were never confirmed has to go
  /// back to the picker rather than to a material screen with nothing to
  /// build for.
  final int unlockedRealmCount;
  final int questionCount;
  const Boot(this.uiLanguage, this.settings, this.progress, this.profile,
      this.realmCount, this.unlockedRealmCount, this.questionCount);
}

final bootProvider = FutureProvider<Boot>((ref) async {
  final repo = ref.watch(repositoryProvider);
  // A flag that drifted out of step with the data would misroute the app, so
  // it is recomputed on every launch.
  await repo.repairRealmFlags();

  final settings = await repo.loadSettings();
  final progress = reconcileStreak(await repo.loadProgress());
  await repo.saveProgress(progress);

  final counts = await repo.counts();
  final unlocked = (await repo.realms()).where((r) => r.unlocked).length;

  // Speech is warmed up alongside, never awaited. Audio is not needed to show
  // the first screen, and a slow or unresponsive TTS engine must not be able
  // to hold the app on its splash.
  unawaited(ref.watch(speechProvider).init(preferredVoice: settings.voiceName));

  return Boot(
    await repo.loadUiLanguage(),
    settings,
    progress,
    await repo.loadProfile(),
    counts.realms,
    unlocked,
    counts.questions,
  );
});

// These three are seeded from [bootProvider] and then written directly by the
// UI. Deriving the initial value here rather than assigning it from a frame
// callback matters: assigning a fresh object every build notified listeners,
// which rebuilt, which assigned again — an endless loop that never settled.
final languageProvider = StateProvider<String?>(
    (ref) => ref.watch(bootProvider).valueOrNull?.uiLanguage);

final settingsProvider = StateProvider<AppSettings>(
    (ref) => ref.watch(bootProvider).valueOrNull?.settings ?? const AppSettings());

final progressProvider = StateProvider<Progress>(
    (ref) => ref.watch(bootProvider).valueOrNull?.progress ?? const Progress());

/// The active realm filter: `null` means every realm.
final realmFilterProvider = StateProvider<String?>((ref) => null);

/// Which kinds of question the next session draws from: all | listening |
/// phrasing | speaking. Held in memory rather than saved, because it is a
/// choice for one session — someone who wanted to drill listening on Tuesday
/// should not find the app still refusing to say anything on Friday.
final formatFilterProvider = StateProvider<String>((ref) => 'all');

/// What the home screen counts, and the areas it lists. Here rather than on
/// the screen itself because the quiz has to refresh both when it ends.
final homeCountsProvider = FutureProvider.autoDispose<HomeCounts>((ref) async {
  final realm = ref.watch(realmFilterProvider);
  return ref.watch(repositoryProvider).homeCounts(realm ?? 'all');
});

final realmsProvider = FutureProvider.autoDispose<List<Realm>>(
    (ref) => ref.watch(repositoryProvider).realms());

/// Every scene the learner has: their own, from the database, and the
/// built-in samples for the current language, ordered for their interests.
/// One list, so home, the record and the launcher all see the same thing.
final allScenesProvider = FutureProvider.autoDispose<List<Scene>>((ref) async {
  final own = await ref.watch(repositoryProvider).scenes();
  final lang = ref.watch(languageProvider) ?? fallbackLanguage;
  final interests = ref.watch(settingsProvider).interests;
  return [...own, ...builtinScenes(lang, interests: interests)];
});

final sceneResultsProvider = FutureProvider.autoDispose<List<SceneResult>>(
    (ref) => ref.watch(repositoryProvider).sceneResults());

/// The two skills, read off the results. Refreshed with them.
final skillStatsProvider = FutureProvider.autoDispose<SkillStats>((ref) async {
  final results = await ref.watch(sceneResultsProvider.future);
  return skillStats(results, today: today());
});

/// Strings for the current language.
final stringsProvider = Provider<S>((ref) {
  final code = ref.watch(languageProvider) ?? fallbackLanguage;
  return S(code);
});

// ------------------------------------------------------------------- theme

const _seed = Color(0xFF5B8DEF);

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    // Every exercise is answered by tapping, so controls are sized for thumbs
    // rather than cursors.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

// ------------------------------------------------------------------- shell

class KotoLangApp extends ConsumerStatefulWidget {
  const KotoLangApp({super.key});

  @override
  ConsumerState<KotoLangApp> createState() => _KotoLangAppState();
}

class _KotoLangAppState extends ConsumerState<KotoLangApp>
    with WidgetsBindingObserver {
  final _navKey = GlobalKey<NavigatorState>();
  final _intake = ShareIntake();
  StreamSubscription<String>? _shareSub;

  /// Text shared before the app was in a position to act on it. Held rather
  /// than dropped: a share can arrive while the language picker is still up on
  /// a brand-new install.
  String? _pendingShare;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shareSub = _intake.stream.listen(_offerShare);
    _intake.start().then((text) {
      if (text != null) _offerShare(text);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Catches a share that reached the platform before Dart was listening.
    if (state == AppLifecycleState.resumed) {
      _intake.take().then((text) {
        if (text != null) _offerShare(text);
      });
    }
  }

  void _offerShare(String text) {
    _pendingShare = text;
    _drainShare();
  }

  /// Opens whichever screen matches what was shared. Retried from build, so a
  /// share that arrives too early lands as soon as it can.
  void _drainShare() {
    final text = _pendingShare;
    if (text == null) return;
    final nav = _navKey.currentState;
    // Nothing can be imported before a language exists: material has to be
    // told which language its explanations are written in.
    if (nav == null || ref.read(languageProvider) == null) return;

    _pendingShare = null;
    final kind = imp.previewImport(text).type;
    // A profile goes to the profile box; everything else to the scenes box,
    // which says plainly when what arrived is not a scenes reply.
    nav.push(MaterialPageRoute(
      builder: (_) => kind == 'profile'
          ? PasteProfileScreen(initialText: text, forScenes: true)
          : ScenePackScreen(initialText: text),
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareSub?.cancel();
    _intake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    if (_pendingShare != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _drainShare());
    }
    return MaterialApp(
      title: 'KotoLang',
      navigatorKey: _navKey,
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      // The stored preference, which until now was written and never read.
      themeMode: switch (ref.watch(settingsProvider).theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      locale: lang == null ? null : languageFor(lang).locale,
      // Every interface language has to be listed. WidgetsApp resolves the
      // requested locale against this list, and its default is English alone —
      // which silently reduced every language to English and left Japanese
      // text without the hint Android needs to pick Japanese glyphs.
      supportedLocales: [for (final l in supportedLanguages) l.locale],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Root(),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(bootProvider);

    return boot.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                const Text('KotoLang could not start.'),
                const SizedBox(height: 8),
                Text('$e', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
      data: (b) {
        // Language first: nothing else can be read until it is chosen.
        if (ref.watch(languageProvider) == null) {
          return const LanguagePickerScreen(firstRun: true);
        }
        // Two questions and one sample scene, once. A phone that already has
        // a profile or areas came through the older setup and skips it.
        if (!b.settings.tutorialDone && b.profile == null && b.realmCount == 0) {
          return const FirstRunScreen();
        }
        // Areas exist but none was ever confirmed and the phone never came
        // through the new first run: setup was abandoned at the old picker.
        // Home would offer areas that were never chosen.
        if (!b.settings.tutorialDone &&
            b.realmCount > 0 && b.questionCount == 0 && b.unlockedRealmCount == 0) {
          return const RealmPickerScreen(firstRun: true);
        }
        return const HomeShell();
      },
    );
  }
}

/// Bottom-tab shell for the four main destinations.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    // Three destinations: today, the record, settings. The record holds what
    // used to be two tabs — progress and the library — now that the scenes
    // are few enough to list under the numbers they produce.
    const pages = [HomeScreen(), RecordScreen(), SettingsScreen()];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: s.t('todayEyebrow')),
          NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights),
              label: s.t('recordTab')),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: s.t('settingsTitle')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- utilities

/// Re-reads everything and rebuilds the shell. Used after imports and resets,
/// where the correct destination may have changed.
Future<void> reload(WidgetRef ref) async {
  ref.invalidate(bootProvider);
  await ref.read(bootProvider.future);
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}


/// A plain "what is this?" popup, for the counters and badges whose names
/// cannot carry their own explanation. Dismissed by a tap anywhere.
Future<void> explainNote(
  BuildContext context, {
  required String title,
  required String body,
  required String closeLabel,
}) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(ctx),
        child: AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(closeLabel),
            ),
          ],
        ),
      ),
    );
/// Confirmation used before anything destructive. Returns false when dismissed.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Persists a settings change and keeps the in-memory copy in step.
Future<void> updateSettings(WidgetRef ref, AppSettings next) async {
  ref.read(settingsProvider.notifier).state = next;
  await ref.read(repositoryProvider).saveSettings(next);
}

/// Companion helper re-exported so feature files need not import Drift.
Value<T> dbValue<T>(T v) => Value<T>(v);
