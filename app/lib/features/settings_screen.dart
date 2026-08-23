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
import '../domain/models.dart';
import '../domain/prompts.dart' as prompts;
import 'onboarding_screens.dart';

final _realmsProvider =
    FutureProvider.autoDispose<List<Realm>>((ref) => ref.watch(repositoryProvider).realms());

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _resetRealmId;
  bool _auditOpen = false;
  final _auditController = TextEditingController();
  String? _note;

  @override
  void dispose() {
    _auditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final speech = ref.watch(speechProvider);
    final lang = ref.watch(languageProvider) ?? fallbackLanguage;
    final realms = ref.watch(_realmsProvider).value ?? const <Realm>[];
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
        ]),

        // ---------------------------------------------------------- audio
        _Section(title: s.t('audioSection'), children: [
          if (!speech.available)
            Text(speech.supported ? s.t('voiceHelpNone') : s.t('noAudioSupport'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error))
          else ...[
            DropdownButtonFormField<String>(
              initialValue: speech.chosen?.name,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.t('voiceLabel'), isDense: true),
              items: [
                for (final v in speech.voices)
                  DropdownMenuItem(
                      value: v.name,
                      child: Text('${v.name} (${v.locale})',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await speech.setVoice(v);
                await updateSettings(ref, settings.copyWith(voiceName: v));
                setState(() {});
                speech.speak('This is how your listening practice will sound.',
                    rate: settings.rate);
              },
            ),
            const SizedBox(height: 12),
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
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    updateSettings(ref, settings.copyWith(clearSpeechRate: true)),
                child: Text(s.t('followDifficulty')),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.volume_up),
              onPressed: () => speech.speak(
                  'We need to review the repair policy before proceeding.',
                  rate: settings.rate),
              label: Text(s.t('testVoice')),
            ),
            const SizedBox(height: 8),
            Text(s.t('voiceHelp'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ]),

        // ------------------------------------------------------- learning
        _Section(title: s.t('learningSection'), children: [
          DropdownButtonFormField<String>(
            initialValue: settings.difficulty,
            decoration: InputDecoration(labelText: s.t('difficultyLabel'), isDense: true),
            items: [
              DropdownMenuItem(value: 'easy', child: Text(s.t('diffEasy'))),
              DropdownMenuItem(value: 'normal', child: Text(s.t('diffNormal'))),
              DropdownMenuItem(value: 'hard', child: Text(s.t('diffHard'))),
            ],
            onChanged: (v) =>
                v == null ? null : updateSettings(ref, settings.copyWith(difficulty: v)),
          ),
          const SizedBox(height: 6),
          Text(
            switch (settings.difficulty) {
              'easy' => s.t('diffEasyHint'),
              'normal' => s.t('diffNormalHint'),
              _ => s.t('diffHardHint'),
            },
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: settings.inputMode,
            isExpanded: true,
            decoration: InputDecoration(labelText: s.t('inputModeLabel'), isDense: true),
            items: [
              DropdownMenuItem(value: 'tap', child: Text(s.t('inputTap'))),
              DropdownMenuItem(value: 'keyboard', child: Text(s.t('inputKeyboard'))),
            ],
            onChanged: (v) =>
                v == null ? null : updateSettings(ref, settings.copyWith(inputMode: v)),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: settings.dailyGoal,
            decoration: InputDecoration(labelText: s.t('dailyGoalLabel'), isDense: true),
            items: [
              DropdownMenuItem(value: 1, child: Text(s.t('goalOne'))),
              const DropdownMenuItem(value: 5, child: Text('5')),
              const DropdownMenuItem(value: 10, child: Text('10')),
              const DropdownMenuItem(value: 20, child: Text('20')),
            ],
            onChanged: (v) =>
                v == null ? null : updateSettings(ref, settings.copyWith(dailyGoal: v)),
          ),
        ]),

        // ------------------------------------------------------- material
        _Section(title: s.t('materialSection'), children: [
          OutlinedButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const MaterialScreen())),
            child: Text(s.t('addMaterial')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final profile = await ref.read(repositoryProvider).loadProfile();
              if (!context.mounted) return;
              await copyToClipboard(
                context,
                prompts.addRealmPrompt(
                  uiLanguage: lang,
                  existingRealms: realms.map((r) => r.name).toList(),
                  level: profile?.englishLevel ?? 'B1',
                ),
                s.t('copied'),
              );
            },
            child: Text(s.t('newRealmPrompt')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setState(() => _auditOpen = !_auditOpen),
            child: Text(s.t('auditButton')),
          ),
          if (_auditOpen) ...[
            const SizedBox(height: 10),
            Text(s.t('auditHint'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final sentences = await ref.read(repositoryProvider).sentences();
                final list = sentences
                    .where((x) => !x.disabled)
                    .take(120)
                    .toList()
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value.text}')
                    .join('\n');
                if (!context.mounted) return;
                await copyToClipboard(
                    context,
                    prompts.auditPrompt(uiLanguage: lang, sentences: list),
                    s.t('copied'));
              },
              child: Text(s.t('copyAuditPrompt')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _auditController,
              maxLines: 6,
              minLines: 4,
              decoration: InputDecoration(hintText: s.t('pastePlaceholder')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final res = await ref
                    .read(repositoryProvider)
                    .importAudit(_auditController.text);
                if (!context.mounted) return;
                if (res.low > 0) {
                  final removed =
                      await ref.read(repositoryProvider).disableLowQuality();
                  if (!context.mounted) return;
                  showToast(context, '${res.matched} · $removed');
                } else {
                  showToast(context, '${res.matched}');
                }
              },
              child: Text(s.t('loadAudit')),
            ),
          ],
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
          if (realms.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _resetRealmId ?? realms.first.id,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.t('resetRealmLabel'), isDense: true),
              items: [
                for (final r in realms)
                  DropdownMenuItem(value: r.id, child: Text(r.label)),
              ],
              onChanged: (v) => setState(() => _resetRealmId = v),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _deleteRealm(realms, removeRealm: false),
              child: Text(s.t('deleteRealmMaterial')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _deleteRealm(realms, removeRealm: true),
              child: Text(s.t('deleteRealmEntirely')),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _confirmed(
              title: s.t('deleteAllMaterial'),
              action: () => ref.read(repositoryProvider).deleteAllMaterial(),
            ),
            child: Text(s.t('deleteAllMaterial')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _confirmed(
              title: s.t('resetProgressOnly'),
              action: () => ref.read(repositoryProvider).resetProgress(),
            ),
            child: Text(s.t('resetProgressOnly')),
          ),
          const Divider(height: 28),
          OutlinedButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PasteProfileScreen())),
            child: Text(s.t('reprofile')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _confirmed(
              title: s.t('resetProfile'),
              action: () => ref.read(repositoryProvider).resetProfileAndRealms(),
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
              action: () => ref.read(repositoryProvider).factoryReset(),
            ),
            child: Text(s.t('factoryReset')),
          ),
        ]),

        const SizedBox(height: 8),
        Text(s.t('privacyNote'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Future<void> _confirmed({
    required String title,
    required Future<void> Function() action,
  }) async {
    final s = ref.read(stringsProvider);
    final ok = await confirm(
      context,
      title: title,
      body: s.t('resetIntro'),
      confirmLabel: s.t('confirmLabel'),
      cancelLabel: s.t('cancel'),
    );
    if (!ok) return;
    await action();
    if (!mounted) return;
    showToast(context, s.t('deletedLabel'));
    ref.invalidate(_realmsProvider);
    await reload(ref);
  }

  Future<void> _deleteRealm(List<Realm> realms, {required bool removeRealm}) async {
    final s = ref.read(stringsProvider);
    final id = _resetRealmId ?? realms.first.id;
    final repo = ref.read(repositoryProvider);
    final plan = await repo.planRealmDeletion(id);

    if (!mounted) return;
    final ok = await confirm(
      context,
      title: removeRealm ? s.t('deleteRealmEntirely') : s.t('deleteRealmMaterial'),
      body: '${s.t('readyItems')}: ${plan.items} · '
          '${s.t('readySentences')}: ${plan.sentences} · '
          '${s.t('readyQuestions')}: ${plan.questions}',
      confirmLabel: s.t('confirmLabel'),
      cancelLabel: s.t('cancel'),
    );
    if (!ok) return;

    await repo.deleteRealmMaterial(id, removeRealm: removeRealm);
    if (!mounted) return;
    showToast(context, s.t('deletedLabel'));
    setState(() => _resetRealmId = null);
    ref.invalidate(_realmsProvider);
    await reload(ref);
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
