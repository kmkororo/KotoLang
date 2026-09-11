/// The two trips to the learner's own AI — for the profile, and for the
/// "conversations" — each split across two screens.
///
/// The first screen copies the prompt and opens the assistant; the second
/// takes the reply. They are separate so that, back from the assistant with
/// the reply on the clipboard, the only big button in sight is the one that
/// pastes it. On the first run a band at the top says which of the four
/// steps this is.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/l10n/languages.dart';
import '../data/builtin_scenes.dart';
import '../domain/field.dart';
import '../domain/models.dart';
import '../domain/progress_service.dart';
import '../domain/prompts.dart' as prompts;
import 'ai_links.dart';
import 'field_picker_screen.dart';
import 'field_screen.dart' show openLockedField;
import 'onboarding_screens.dart' show copyToClipboard;
import 'paste_box.dart';

/// What the AI is being asked for.
enum AiJob { profile, scenes, feedback }

const firstRunSteps = 4;

/// "Step n / 4", the step's name, and one line on what to do here. Shown on
/// the first run only.
class StepBand extends ConsumerWidget {
  final int step;
  final String title;
  final String hint;
  const StepBand({super.key, required this.step, required this.title, required this.hint});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(s.t('stepLabel', {'n': step, 'total': firstRunSteps}),
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer)),
        ],
      ),
    );
  }
}

/// The step a job belongs to on the first run.
int _stepOf(AiJob job) => job == AiJob.profile ? 2 : 4;

String _stepTitleKey(AiJob job) => job == AiJob.profile ? 'step2Title' : 'step4Title';

// ------------------------------------------------------------ screen A

/// Copy the prompt, open the assistant. Moving on to the reply screen happens
/// by itself the moment either is done.
class AiPromptScreen extends ConsumerStatefulWidget {
  final AiJob job;

  /// Set on the first run: shows the step band and carries the flow on to the
  /// next step when this one is done.
  final bool firstRun;

  /// For [AiJob.scenes]: the field the caller already chose.
  final String? initialField;
  const AiPromptScreen({super.key, required this.job, this.firstRun = false, this.initialField});

  @override
  ConsumerState<AiPromptScreen> createState() => _AiPromptScreenState();
}

class _AiPromptScreenState extends ConsumerState<AiPromptScreen> {
  UserProfile? _profile;
  bool _loaded = false;
  int _ownScenes = 0;
  String? _field;

  /// What this batch of conversations costs, read before the reply is taken:
  /// afterwards the field always has some, and the first batch is what is
  /// free.
  int _cost = 0;

  @override
  void initState() {
    super.initState();
    _field = widget.initialField;
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(repositoryProvider);
    final profile = await repo.loadProfile();
    final own = await repo.scenes(includeDisabled: true);
    final cost = await repo.sceneAddCostFor(_field);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _ownScenes = own.length;
      _cost = cost;
      _loaded = true;
    });
  }

  String get _lang => ref.read(languageProvider) ?? fallbackLanguage;

  Future<String> _prompt() async {
    if (widget.job == AiJob.profile) return prompts.profilePrompt(uiLanguage: _lang);
    if (widget.job == AiJob.feedback) {
      final all = await ref.read(fieldsProvider.future);
      return ref.read(repositoryProvider).feedbackPromptText(
            uiLanguage: _lang,
            fieldId: _field ?? '',
            fieldLabel: all.where((f) => f.id == _field).firstOrNull?.label ?? '',
          );
    }
    return ref.read(repositoryProvider).scenesPromptText(
          uiLanguage: _lang,
          extraTopics: builtinTopics(),
          lookup: {for (final s in builtinScenes(_lang)) s.id: s},
          field: _field,
        );
  }

  Future<void> _copy() async {
    final s = ref.read(stringsProvider);
    final text = await _prompt();
    if (!mounted) return;
    await copyToClipboard(context, text, s.t('copied'));
    if (!mounted) return;
    // Feedback is one way: what comes back is coaching to read, so there is
    // no reply to take.
    if (widget.job == AiJob.feedback) return;
    await _toReply();
  }

  /// The reply screen, and what follows once the reply is in.
  Future<void> _toReply() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => AiReplyScreen(job: widget.job, firstRun: widget.firstRun, field: _field)),
    );
    if (ok != true || !mounted) return;
    await _done();
  }

  Future<void> _done() async {
    final repo = ref.read(repositoryProvider);
    if (widget.job == AiJob.profile) {
      // The fields the AI read off the profile: the learner picks the starting
      // ones now, while there are still some to pick.
      final left = await repo.freeFieldSlotsLeft();
      final anyLocked = (await repo.realms()).any((r) => !r.unlocked);
      if (!mounted) return;
      if (left > 0 && anyLocked) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => RealmPickerScreen(choose: true, firstRun: widget.firstRun)));
        if (!mounted) return;
      }
      if (widget.firstRun) {
        // Step 4 takes this screen's place: back from there goes past step 2.
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const AiPromptScreen(job: AiJob.scenes, firstRun: true)));
      } else {
        Navigator.pop(context, true);
      }
      return;
    }
    // Scenes are in. On the first run that is the end of the setup.
    if (widget.firstRun) {
      final settings = ref.read(settingsProvider);
      await updateSettings(ref, settings.copyWith(tutorialDone: true));
      if (!mounted) return;
    }
    Navigator.popUntil(context, (r) => r.isFirst);
    await reload(ref);
  }

  /// The price follows the field: the first batch in each one is free.
  Future<void> _reloadCost() async {
    final cost = await ref.read(repositoryProvider).sceneAddCostFor(_field);
    if (mounted) setState(() => _cost = cost);
  }

  Future<void> _makeProfile() async {
    await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const AiPromptScreen(job: AiJob.profile)));
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final scenes = widget.job == AiJob.scenes;

    // Scenes are written for the learner's own fields — the areas read off
    // their profile — never for the samples' four.
    final fieldsAsync = ref.watch(fieldsProvider);
    final lockedAsync = ref.watch(lockedFieldsProvider);
    // Their own fields, never the samples' four — except when the field
    // already chosen is one of those: conversations imported before fields
    // existed sit in the default field, and it is still theirs.
    final all = fieldsAsync.value ?? const <Field>[];
    final fields = [for (final f in all) if (!f.builtin || f.id == _field) f];
    final locked = lockedAsync.value ?? const <Field>[];
    final left = ref.watch(freeFieldSlotsProvider).value ?? 0;
    // A field that is no longer there is dropped — but only once the lists
    // have loaded, or a field just opened would be lost on the way in.
    final known = {for (final f in fields) f.id, for (final f in locked) f.id};
    if (fieldsAsync.hasValue && lockedAsync.hasValue && _field != null && !known.contains(_field)) {
      _field = null;
    }
    final field = _field ?? (fields.isEmpty ? null : fields.first.id);
    _field ??= field;
    final hasProfile = _profile != null;
    final ready = scenes ? hasProfile && field != null : true;

    final title = switch (widget.job) {
      AiJob.scenes => s.t(_ownScenes == 0 ? 'firstSceneMake' : 'nextScenesMake'),
      AiJob.profile => s.t('profileAiSection'),
      AiJob.feedback => s.t('feedbackButton'),
    };

    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 2, style: const TextStyle(fontSize: 18))),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  if (widget.firstRun)
                    StepBand(
                      step: _stepOf(widget.job),
                      title: s.t(_stepTitleKey(widget.job)),
                      hint: s.t('promptStepHint'),
                    ),

                  // The one thing the AI needs before it can write for this
                  // person. Done once; this screen comes straight back.
                  if (scenes && !hasProfile) ...[
                    Card(
                      color: scheme.primaryContainer,
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(s.t('scenePackNeedProfile'),
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              icon: const Icon(Icons.person_outline),
                              onPressed: _makeProfile,
                              label: Text(s.t('scenePackProfileButton')),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Every field deleted: nothing here can be asked for until
                  // there is a field again, and fields come from the profile.
                  if (scenes && hasProfile && fields.isEmpty && locked.isEmpty) ...[
                    Card(
                      color: scheme.secondaryContainer,
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(s.t('fieldsGoneBody'),
                                style: TextStyle(color: scheme.onSecondaryContainer)),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              icon: const Icon(Icons.refresh),
                              onPressed: _makeProfile,
                              label: Text(s.t('profileRemake')),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (scenes) ...[
                    DropdownButtonFormField<String>(
                      key: const ValueKey('fieldPicker'),
                      initialValue: field,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: s.t('fieldPickLabel'), isDense: true),
                      items: [
                        for (final f in fields)
                          DropdownMenuItem(
                              value: f.id, child: Text(f.label, overflow: TextOverflow.ellipsis)),
                        // The areas read off the profile that are not open yet;
                        // picking one opens it.
                        for (final f in locked)
                          DropdownMenuItem(
                            value: f.id,
                            child: Row(children: [
                              Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Expanded(child: Text(f.label, overflow: TextOverflow.ellipsis)),
                              Text(
                                  left > 0
                                      ? s.t('fieldChooseButton')
                                      : s.t('seedsCost', {'n': realmUnlockCost}),
                                  style: theme.textTheme.bodySmall),
                            ]),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        final l = locked.where((f) => f.id == v).firstOrNull;
                        if (l != null) {
                          openLockedField(context, ref, l).then((opened) {
                            if (opened && mounted) {
                              setState(() => _field = l.id);
                              _reloadCost();
                            }
                          });
                          return;
                        }
                        setState(() => _field = v);
                        _reloadCost();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  BigButton(
                    icon: Icons.copy_all,
                    label: s.t('copyPrompt'),
                    onPressed: ready ? _copy : null,
                  ),
                  // What this batch costs, said before the trip rather than
                  // after it.
                  if (scenes && field != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _cost == 0
                          ? s.t('sceneAddFirstFree')
                          : s.t('sceneAddPriced', {'n': _cost}),
                      style: muted,
                    ),
                  ],
                  const SizedBox(height: 10),
                  AiLinks(
                      s: s,
                      enabled: ready,
                      prompt: _prompt,
                      onOpened: widget.job == AiJob.feedback ? null : _toReply),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(child: Text(s.t('privacyLine'), style: muted)),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

// ------------------------------------------------------------ screen B

/// Paste the reply. One big button; the paste box appears only when the
/// clipboard had nothing to offer or the reply could not be read. Pops with
/// true once the reply is in — unless it was opened straight from a share,
/// with nothing underneath to hand back to, in which case it finishes the
/// job itself.
class AiReplyScreen extends ConsumerStatefulWidget {
  final AiJob job;
  final bool firstRun;

  /// For [AiJob.scenes]: the field the scenes are for.
  final String? field;

  /// Prefilled when the reply arrived through the share sheet.
  final String? initialText;
  const AiReplyScreen(
      {super.key, required this.job, this.firstRun = false, this.field, this.initialText});

  @override
  ConsumerState<AiReplyScreen> createState() => _AiReplyScreenState();
}

class _AiReplyScreenState extends ConsumerState<AiReplyScreen> {
  final _paste = PasteController();
  bool _showBox = false;
  bool _busy = false;
  String? _error;

  bool get _shared => widget.initialText != null;

  @override
  void initState() {
    super.initState();
    final shared = widget.initialText;
    if (shared != null) {
      _paste.field.text = shared;
      _showBox = true;
    }
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  String get _lang => ref.read(languageProvider) ?? fallbackLanguage;

  Future<void> _import() async {
    final s = ref.read(stringsProvider);
    if (_paste.isEmpty) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (!mounted) return;
      if (text.trim().isEmpty) {
        setState(() {
          _showBox = true;
          _error = s.t('clipboardEmpty');
        });
        return;
      }
      _paste.field.text = text;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(repositoryProvider);
    if (widget.job == AiJob.profile) {
      final res = await repo.importProfile(_paste.text, uiLanguage: _lang);
      if (!mounted) return;
      setState(() => _busy = false);
      if (!res.ok) {
        setState(() {
          _showBox = true;
          _error = s.t('importFailedHint');
        });
        return;
      }
      showToast(
        context,
        res.partial
            ? s.t('partialImported', {'n': res.realms})
            : s.t('importedProfile', {'n': res.realms}),
      );
      _paste.clear();
      await reload(ref);
      ref.invalidate(realmsProvider);
      ref.invalidate(fieldsProvider);
      ref.invalidate(lockedFieldsProvider);
      ref.invalidate(freeFieldSlotsProvider);
    } else {
      // Straight from a share there is no chosen field: the first of the
      // learner's own, as the prompt screen would have offered.
      var field = widget.field;
      if (field == null) {
        final fields = await ref.read(fieldsProvider.future);
        field = fields.where((f) => !f.builtin).firstOrNull?.id;
      }
      // The price of this batch, read before the import: afterwards the field
      // always has conversations, and the first batch is the free one.
      final cost = await repo.sceneAddCostFor(field);
      final seeds = (await repo.loadProgress()).seeds;
      if (!mounted) return;
      if (seeds < cost) {
        setState(() {
          _busy = false;
          _error = s.t('unlockRealmNeedMore', {'n': cost - seeds});
        });
        return;
      }
      final out = await repo.importScenes(_paste.text, uiLanguage: _lang, field: field);
      if (!mounted) return;
      setState(() => _busy = false);
      if (!out.ok) {
        setState(() {
          _showBox = true;
          _error = out.errors.contains('not a scenes reply')
              ? s.t('scenePackNotScenes')
              : s.t('importFailedHint');
        });
        return;
      }
      _paste.clear();
      // Paid only now, when conversations actually arrived.
      if (await repo.spendSeeds(cost) && mounted) {
        ref.read(progressProvider.notifier).state = await repo.loadProgress();
      }
      if (!mounted) return;
      ref.invalidate(allScenesProvider);
      showToast(
        context,
        out.rejected.isEmpty
            ? s.t('scenesImported', {'n': out.scenes})
            : '${s.t('scenesImported', {'n': out.scenes})} · ${s.t('packRejected', {
                    'n': out.rejected.length,
                    'reasons': out.rejected.map((r) => r.title).join(', ')
                  })}',
      );
    }
    if (!mounted) return;
    if (!_shared) {
      Navigator.pop(context, true);
      return;
    }
    // Straight from a share: finish here.
    if (widget.job == AiJob.profile) {
      final left = await repo.freeFieldSlotsLeft();
      final anyLocked = (await repo.realms()).any((r) => !r.unlocked);
      if (!mounted) return;
      final setup = !ref.read(settingsProvider).tutorialDone;
      if (left > 0 && anyLocked) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => RealmPickerScreen(choose: true, firstRun: setup)));
        if (!mounted) return;
      }
      // Mid-setup, a profile that arrived through the share sheet still owes
      // the learner step 4 — otherwise the flow ends here, and home is
      // reached without their AI ever being asked for conversations.
      if (setup) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const AiPromptScreen(job: AiJob.scenes, firstRun: true)));
        return;
      }
      Navigator.pop(context);
    } else {
      Navigator.popUntil(context, (r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('replyStepTitle'), style: const TextStyle(fontSize: 18))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (widget.firstRun)
              StepBand(
                step: _stepOf(widget.job),
                title: s.t(_stepTitleKey(widget.job)),
                hint: s.t('replyStepHint'),
              )
            else ...[
              Text(s.t('replyStepHint'), style: muted),
              const SizedBox(height: 16),
            ],
            BigButton(
              icon: Icons.download,
              label: s.t('scenePasteButton'),
              onPressed: _busy ? null : _import,
              busy: _busy,
            ),
            if (_showBox) ...[
              const SizedBox(height: 12),
              PasteBox(
                  controller: _paste,
                  s: s,
                  expecting: widget.job == AiJob.profile ? 'profile' : 'scenes'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            if (!_shared) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 16),
                  onPressed: () => Navigator.pop(context, false),
                  label: Text(s.t('promptAgain')),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(child: Text(s.t('privacyLine'), style: muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The one thing to do on a screen: a full-width button.
class BigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  const BigButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        alignment: Alignment.centerLeft,
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          Expanded(
              child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          if (busy)
            const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(icon, size: 20),
        ],
      ),
    );
  }
}
