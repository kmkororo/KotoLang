/// Settings: audio, difficulty, interface language, material and the reset
/// options.
///
/// Every reset states exactly what it will remove before it removes anything,
/// and the scopes are separated so replacing material never costs the learner
/// their streak.
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app.dart';
import '../core/l10n/languages.dart';
import '../domain/field.dart';
import '../domain/models.dart';
import '../domain/progress_service.dart';
import 'field_picker_screen.dart';
import 'onboarding_screens.dart';
import 'profile_screen.dart';
import 'tree_view.dart';

final _realmsProvider =
    FutureProvider.autoDispose<List<Realm>>((ref) => ref.watch(repositoryProvider).realms());

/// The l10n key suffix for one window length. Named by feel rather than by
/// the number: nobody chooses "1.5".
String _scaleKey(double v) => switch (v) {
      < 1.0 => 'short',
      == 1.0 => 'normal',
      < 2.0 => 'long',
      _ => 'longest',
    };

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

/// What the voice test says: one line at the level of the built-in scenes.
const _sample = 'Can you come a little early tomorrow? The meeting starts at nine.';

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _resetRealmId;
  bool _wipeOpen = false;
  String? _note;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final speech = ref.watch(speechProvider);
    final lang = ref.watch(languageProvider) ?? fallbackLanguage;
    // Every field the learner can actually study in — the samples' four and
    // the areas they have opened. A field never opened has nothing to clear.
    final fields = ref.watch(fieldsProvider).value ?? const <Field>[];
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(s.t('settingsTitle'),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),

        // ------------------------------------------------------ interface
        _Section(title: s.t('interfaceSection'), children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(languageFor(lang).flag, style: const TextStyle(fontSize: 26)),
            title: Text(s.t('uiLanguageLabel')),
            subtitle: Text(languageFor(lang).endonym),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LanguagePickerScreen())),
          ),
          Text(s.t('uiLanguageNote'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: settings.theme,
            isExpanded: true,
            decoration: InputDecoration(labelText: s.t('themeLabel'), isDense: true),
            items: [
              DropdownMenuItem(value: 'system', child: Text(s.t('themeSystem'))),
              DropdownMenuItem(value: 'light', child: Text(s.t('themeLight'))),
              DropdownMenuItem(value: 'dark', child: Text(s.t('themeDark'))),
            ],
            onChanged: (v) =>
                v == null ? null : updateSettings(ref, settings.copyWith(theme: v)),
          ),
        ]),
        // ---------------------------------------------------------- audio
        _Section(title: s.t('audioSection'), children: [
          if (!speech.available)
            Text(speech.supported ? s.t('voiceHelpNone') : s.t('noAudioSupport'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error))
          else ...[
            // The two voices of a set. Two different ones where the phone has
            // them, so who is speaking is heard as well as seen; with one, it
            // is pitched up for them and down for the learner.
            for (final (label, current, you) in [
              (s.t('partnerVoiceLabel'), settings.partnerVoice, false),
              (s.t('yourVoiceLabel'), settings.yourVoice, true),
            ]) ...[
              DropdownButtonFormField<String>(
                initialValue: current,
                isExpanded: true,
                decoration: InputDecoration(labelText: label, isDense: true),
                items: [
                  DropdownMenuItem(value: '', child: Text(s.t('voiceAuto'))),
                  for (final v in speech.voices)
                    DropdownMenuItem(
                        value: v.name,
                        child: Text('${v.name} (${v.locale})',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  final next = you
                      ? settings.copyWith(yourVoice: v)
                      : settings.copyWith(partnerVoice: v);
                  await updateSettings(ref, next);
                  final pair = speech.pair(partner: next.partnerVoice, you: next.yourVoice);
                  speech.say(_sample,
                      voice: you ? pair.you : pair.partner,
                      pitch: you ? pair.youPitch : pair.partnerPitch);
                },
              ),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Text(s.t('speedLabel'), style: theme.textTheme.bodySmall),
              Expanded(
                child: Slider(
                  value: settings.rate.clamp(0.6, 1.2),
                  min: 0.6,
                  max: 1.2,
                  divisions: 12,
                  label: '×${settings.rate.toStringAsFixed(2)}',
                  onChanged: (v) => updateSettings(ref, settings.copyWith(speechRate: v)),
                ),
              ),
            ]),
            OutlinedButton.icon(
              icon: const Icon(Icons.volume_up),
              onPressed: () => speech.speak(_sample, rate: settings.rate),
              label: Text(s.t('testVoice')),
            ),
            const SizedBox(height: 4),
            Text(s.t('voiceHelp'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],

          // How long there is to answer. A multiplier rather than a number of
          // seconds, because the number is the same for every turn and the
          // gauge is marked in it: what this setting changes is how much room
          // each of those marks stands for.
          const SizedBox(height: 14),
          Text(s.t('windowLabel'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<double>(
            segments: [
              for (final v in windowScales)
                ButtonSegment(value: v, label: Text(s.t('window_${_scaleKey(v)}'))),
            ],
            selected: {settings.windowScale},
            showSelectedIcon: false,
            onSelectionChanged: (v) =>
                updateSettings(ref, settings.copyWith(windowScale: v.first)),
          ),
          const SizedBox(height: 4),
          Text(
              s.t('windowHint', {
                'n': (answerWindowMs / 1000 * settings.windowScale).toStringAsFixed(1)
              }),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ]),


        // ------------------------------------------------------ feedback
        _Section(title: s.t('hapticsSection'), children: [
          // The first thing somebody who dislikes it will come looking for.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.haptics,
            title: Text(s.t('hapticsLabel')),
            subtitle: Text(s.t('hapticsHint'), style: theme.textTheme.bodySmall),
            onChanged: (v) => updateSettings(ref, settings.copyWith(haptics: v)),
          ),
        ]),

        _Section(title: s.t('materialSection'), children: [
          // Who the learner is, for the AI that writes their scenes.
          OutlinedButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: Text(s.t('profileMakeButton')),
          ),
          const SizedBox(height: 8),
          // Every area the AI ever suggested, lock state and unlock cost
          // included.
          OutlinedButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RealmPickerScreen())),
            child: Text(s.t('yourRealmsButton')),
          ),
        ]),

        // ----------------------------------------------------------- data
        _Section(title: s.t('dataSection'), children: [
          Text(s.t('storageNote'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file),
            onPressed: _export,
            label: Text(s.t('exportData')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.file_open),
            onPressed: _import,
            label: Text(s.t('importData')),
          ),
          if (_note != null) ...[
            const SizedBox(height: 10),
            Text(_note!, style: theme.textTheme.bodySmall),
          ],
        ]),

        // ---------------------------------------------------------- reset
        _Section(title: s.t('resetSection'), children: [
          Text(s.t('resetIntro'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          if (fields.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _resetRealmId ?? fields.first.id,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.t('resetRealmLabel'), isDense: true),
              items: [
                for (final f in fields)
                  DropdownMenuItem(
                      value: f.id,
                      child: Text(f.label, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _resetRealmId = v),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _deleteRealm(fields, removeRealm: false),
              child: Text(s.t('deleteRealmMaterial')),
            ),
            // Only a field of their own can be closed again. The samples' four
            // are always there, so there is nothing to close.
            if (!(fields
                    .where((f) => f.id == (_resetRealmId ?? fields.first.id))
                    .firstOrNull
                    ?.builtin ??
                true)) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _deleteRealm(fields, removeRealm: true),
                child: Text(s.t('deleteRealmEntirely')),
              ),
            ],
          ],
          // Everything below wipes more than one area. Rarely wanted, and
          // permanent, so it is folded away rather than sitting one stray tap
          // from the per-area buttons above.
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: Icon(_wipeOpen ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _wipeOpen = !_wipeOpen),
              label: Text(s.t('wipeSection')),
            ),
          ),
          if (_wipeOpen) ...[
            const SizedBox(height: 4),
            OutlinedButton(
              onPressed: () => _confirmed(
                title: s.t('deleteAllMaterial'),
                body: s.t('resetBodyAll'),
                action: () => ref.read(repositoryProvider).clearEveryField(),
              ),
              child: Text(s.t('deleteAllMaterial')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _confirmed(
                title: s.t('resetProgressOnly'),
                body: s.t('resetBodyProgress'),
                action: () => ref.read(repositoryProvider).forgetAnswers(),
              ),
              child: Text(s.t('resetProgressOnly')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _confirmed(
                title: s.t('resetProfile'),
                body: s.t('resetBodyProfile'),
                action: () => ref.read(repositoryProvider).resetProfileAndFields(),
              ),
              child: Text(s.t('resetProfile')),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
              ),
              onPressed: () => _confirmed(
                title: s.t('factoryReset'),
                body: s.t('resetBodyFactory'),
                action: () => ref.read(repositoryProvider).factoryReset(),
              ),
              child: Text(s.t('factoryReset')),
            ),
          ],
        ]),

        const SizedBox(height: 8),
        Text(s.t('privacyNote'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        // Both stores expect a policy to be reachable. Kept in the app rather
        // than behind a link, so it is readable with no connection and cannot
        // rot when a URL moves.
        Wrap(children: [
          TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DocScreen.privacy())),
            child: Text(s.t('privacyPolicy')),
          ),
          TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DocScreen.terms())),
            child: Text(s.t('termsTitle')),
          ),
        ]),
      ],
    );
  }

  /// Everything a reset can move. The screens that read these are all still
  /// alive underneath this one, so leaving any of them cached shows the
  /// learner data that no longer exists until they restart the app.
  void _forgetEverything() {
    ref.invalidate(_realmsProvider);
    ref.invalidate(realmsProvider);
    ref.invalidate(fieldsProvider);
    ref.invalidate(lockedFieldsProvider);
    ref.invalidate(fieldOpeningsProvider);
    ref.invalidate(ladderProvider);
    ref.invalidate(allScenesProvider);
    ref.invalidate(sceneResultsProvider);
    ref.invalidate(skillStatsProvider);
    ref.invalidate(treeDataProvider);
  }

  Future<void> _confirmed({
    required String title,
    required String body,
    required Future<void> Function() action,
  }) async {
    final s = ref.read(stringsProvider);
    final ok = await confirm(
      context,
      title: title,
      body: body,
      confirmLabel: s.t('confirmLabel'),
      cancelLabel: s.t('cancel'),
    );
    if (!ok) return;
    await action();
    if (!mounted) return;
    // A reset that clears the settings clears the chosen voice with them.
    // The speech engine is set up once per launch and would otherwise keep
    // reporting the old voice until the app is next started.
    final voice = ref.read(settingsProvider).voiceName;
    if (voice != null && voice.isNotEmpty) await ref.read(speechProvider).setVoice(voice);
    if (!mounted) return;
    showToast(context, s.t('deletedLabel'));
    _forgetEverything();
    await reload(ref);
    if (!mounted) return;
    // A reset can change which screen the app should be on entirely — a
    // factory reset belongs back at the welcome screen, not on a home screen
    // with nothing in it. Only the root decides that, so anything stacked on
    // top of it has to come off.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _deleteRealm(List<Field> fields, {required bool removeRealm}) async {
    final s = ref.read(stringsProvider);
    final id = _resetRealmId ?? fields.first.id;
    final repo = ref.read(repositoryProvider);
    final plan = await repo.planFieldClear(id);

    if (!mounted) return;
    final ok = await confirm(
      context,
      title: removeRealm ? s.t('deleteRealmEntirely') : s.t('deleteRealmMaterial'),
      body: '${s.t('scenesDoneLabel')}: ${plan.scenes}',
      confirmLabel: s.t('confirmLabel'),
      cancelLabel: s.t('cancel'),
    );
    if (!ok) return;

    await repo.clearField(id, closeField: removeRealm);
    if (!mounted) return;
    showToast(context, s.t('deletedLabel'));
    setState(() => _resetRealmId = null);
    _forgetEverything();
    await reload(ref);
    if (!mounted) return;
    // Removing the last area leaves nothing to study, so let the root re-route.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _export() async {
    final s = ref.read(stringsProvider);
    // iPad presents the share sheet as a popover and needs an anchor
    // rectangle. Captured before the first await, since the context must not
    // be read across an async gap.
    final box = context.findRenderObject() as RenderBox?;
    final anchor = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      final payload = await ref.read(repositoryProvider).exportAll();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/kotolang-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'KotoLang backup',
          sharePositionOrigin: anchor,
        ),
      );
      if (!mounted) return;
      setState(() => _note = s.t('exportedLabel'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _note = '$e');
    }
  }

  Future<void> _import() async {
    final s = ref.read(stringsProvider);
    try {
      final picked = await FilePicker.pickFile();
      final path = picked?.path;
      if (path == null) return;

      final raw = await File(path).readAsString();
      final n = await ref
          .read(repositoryProvider)
          .restore(jsonDecode(raw) as Map<String, dynamic>);

      if (!mounted) return;
      setState(() => _note = '${s.t('restoredLabel')} ($n)');
      await reload(ref);
    } catch (e) {
      if (!mounted) return;
      setState(() => _note = '${s.t('importFailedTitle')}: $e');
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                ...children,
              ],
            ),
          ),
        ),
      );
}

/// The privacy policy and the terms, in the app itself.
///
/// Both stores expect these to exist and be reachable. Keeping the text in the
/// app as well as on the web means it reads with no connection, and cannot go
/// stale when a hosting URL moves.
class DocScreen extends ConsumerWidget {
  /// Heading/body key pairs, in order.
  final List<(String, String)> sections;
  final String titleKey;

  const DocScreen.privacy({super.key})
      : titleKey = 'privacyPolicy',
        sections = const [
          ('privacyCollectTitle', 'privacyCollectBody'),
          ('privacyStoredTitle', 'privacyStoredBody'),
          ('privacyAiTitle', 'privacyAiBody'),
          ('privacyPermissionsTitle', 'privacyPermissionsBody'),
          ('privacyContactTitle', 'privacyContactBody'),
        ];

  const DocScreen.terms({super.key})
      : titleKey = 'termsTitle',
        sections = const [
          ('termsUseTitle', 'termsUseBody'),
          ('termsMaterialTitle', 'termsMaterialBody'),
          ('termsAiTitle', 'termsAiBody'),
          ('termsDataTitle', 'termsDataBody'),
          ('termsWarrantyTitle', 'termsWarrantyBody'),
          ('privacyContactTitle', 'privacyContactBody'),
        ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.t(titleKey), maxLines: 2, style: const TextStyle(fontSize: 18)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            for (final (heading, body) in sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t(heading),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(s.t(body),
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
