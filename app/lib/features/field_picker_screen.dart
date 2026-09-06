/// The learner's fields, as the AI read them off the profile.
///
/// Two jobs on one screen. Right after the profile comes in it is the
/// choosing screen: tick the starting fields, up to [freeRealmSlots], and
/// confirm. From Settings and the record it is the list: the open fields
/// lead to their scenes, the closed ones carry their Seeds price and open
/// through the locked-field dialog.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/l10n/strings.dart';
import '../domain/field.dart';
import '../domain/models.dart';
import '../domain/progress_service.dart';
import 'field_screen.dart' show FieldCard, openLockedField;
import 'onboarding_screens.dart' show explainSeedGate;
import 'ai_screens.dart';

class RealmPickerScreen extends ConsumerStatefulWidget {
  /// Choosing the starting fields, rather than browsing them all.
  final bool choose;

  /// On the first run: the step band at the top.
  final bool firstRun;
  const RealmPickerScreen({super.key, this.choose = false, this.firstRun = false});

  @override
  ConsumerState<RealmPickerScreen> createState() => _RealmPickerScreenState();
}

class _RealmPickerScreenState extends ConsumerState<RealmPickerScreen> {
  List<Realm> _realms = const [];
  final _selected = <String>{};
  int _left = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(repositoryProvider);
    final list = await repo.realms();
    final left = await repo.freeFieldSlotsLeft();
    if (!mounted) return;
    setState(() {
      _realms = list;
      _left = left;
      _loaded = true;
      if (widget.choose && _selected.isEmpty) {
        // The ones the AI rated most important, ticked to start with.
        for (final r in list.where((r) => !r.unlocked).take(left)) {
          _selected.add(r.id);
        }
      }
    });
  }

  Future<void> _confirm() async {
    final repo = ref.read(repositoryProvider);
    await repo.chooseFields(_selected.toList());
    if (!mounted) return;
    ref.read(progressProvider.notifier).state = await repo.loadProgress();
    ref.invalidate(realmsProvider);
    ref.invalidate(fieldsProvider);
    ref.invalidate(lockedFieldsProvider);
    ref.invalidate(freeFieldSlotsProvider);
    await reload(ref);
    if (!mounted) return;
    // As the root, the picker is replaced by home once a field is chosen;
    // pushed from elsewhere, it goes back.
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _open(Realm r) async {
    final ok = await openLockedField(context, ref, Field(id: r.id, label: r.label));
    if (ok && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final choose = widget.choose && _left > 0;
    final title = choose
        ? (_left >= freeRealmSlots ? s.t('realmChooseTitle') : s.t('fieldChooseLeft', {'n': _left}))
        : s.t('realmsTitle');
    final locked = [for (final r in _realms) if (!r.unlocked) r];
    final open = [for (final r in _realms) if (r.unlocked) r];

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        automaticallyImplyLeading: false,
        title: Text(title, maxLines: 2, style: const TextStyle(fontSize: 18)),
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: choose ? _chooseBody(s, muted, locked) : _listBody(s, muted, open, locked),
              ),
      ),
    );
  }

  List<Widget> _chooseBody(S s, TextStyle? muted, List<Realm> locked) => [
        if (widget.firstRun)
          StepBand(step: 3, title: s.t('step3Title'), hint: s.t('step3Hint')),
        Text(s.t('realmsHint'), style: muted),
        const SizedBox(height: 12),
        for (final r in locked) ...[
          _pickTile(r, _selected.length >= _left),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _selected.isEmpty ? null : _confirm,
          child: Text(s.t('sceneDecide')),
        ),
      ];

  List<Widget> _listBody(S s, TextStyle? muted, List<Realm> open, List<Realm> locked) => [
        if (_left > 0 && locked.isNotEmpty) ...[
          Text(s.t('fieldChooseLeft', {'n': _left}), style: muted),
          const SizedBox(height: 12),
        ],
        for (final r in open) ...[
          FieldCard(
            label: r.label,
            sub: r.hasMaterial ? s.t('hasMaterial') : s.t('unlockedLabel'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => AiPromptScreen(job: AiJob.scenes, initialField: r.id))),
          ),
          const SizedBox(height: 8),
        ],
        for (final r in locked) ...[
          FieldCard(
            label: r.label,
            locked: true,
            sub: '${'★' * r.importance}  ${s.t('importanceLabel', {'n': r.importance})}',
            action: _left > 0 ? s.t('fieldChooseButton') : s.t('seedsCost', {'n': realmUnlockCost}),
            onTap: () => _open(r),
          ),
          const SizedBox(height: 8),
        ],
      ];

  Widget _pickTile(Realm r, bool atCap) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final checked = _selected.contains(r.id);
    // Beyond the starting ones the tile stays tappable, but the tap explains
    // the rule instead of ticking the box.
    final gated = !checked && atCap;
    return Card(
      margin: EdgeInsets.zero,
      child: CheckboxListTile(
        value: checked,
        secondary: gated
            ? Icon(Icons.lock_outline, color: theme.colorScheme.onSurfaceVariant)
            : null,
        onChanged: (v) {
          if (gated) {
            explainSeedGate(context, ref);
            return;
          }
          setState(() {
            if (v == true) {
              _selected.add(r.id);
            } else {
              _selected.remove(r.id);
            }
          });
        },
        title: Text(r.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: gated ? theme.colorScheme.onSurfaceVariant : null,
            )),
        subtitle: Text(
          '${'★' * r.importance}  ${s.t('importanceLabel', {'n': r.importance})}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
