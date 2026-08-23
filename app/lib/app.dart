/// Application shell: providers, theme, and the routing decision that depends
/// on how far the learner has got through setup.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/languages.dart';
import 'core/l10n/strings.dart';
import 'core/speech.dart';
import 'data/database.dart';
import 'data/repository.dart';
import 'domain/models.dart';
import 'domain/progress_service.dart';
import 'features/home_screen.dart';
import 'features/library_screen.dart';
import 'features/onboarding_screens.dart';
import 'features/settings_screen.dart';
import 'features/stats_screen.dart';

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
  final int questionCount;
  const Boot(this.uiLanguage, this.settings, this.progress, this.profile,
      this.realmCount, this.questionCount);
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

class KotoLangApp extends ConsumerWidget {
  const KotoLangApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return MaterialApp(
      title: 'KotoLang',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      locale: lang == null ? null : Locale(languageFor(lang).languageCode),
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
        if (b.profile == null && b.realmCount == 0) return const WelcomeScreen();
        if (b.questionCount == 0) {
          return b.realmCount > 0 ? const MaterialScreen() : const WelcomeScreen();
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
    const pages = [HomeScreen(), LibraryScreen(), StatsScreen(), SettingsScreen()];

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
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book),
              label: s.t('libraryTitle')),
          NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights),
              label: s.t('statsTitle')),
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
