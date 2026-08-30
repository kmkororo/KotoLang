/// Listening with no question attached: the learner's own sentences, played
/// one after another, swiped like a feed.
///
/// This is deliberately not a quiz. Nothing is graded, nothing is scheduled
/// and no Seeds are paid — recall is what earns those, and this asks for
/// none. What it is for is the minutes when answering is too much effort but
/// listening is not, which is otherwise time the app cannot use at all.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/speech.dart';
import '../core/util.dart';
import '../domain/models.dart';

final _feedProvider = FutureProvider.autoDispose<List<Sentence>>((ref) async {
  final realm = ref.watch(realmFilterProvider);
  final all = await ref.watch(repositoryProvider).sentences();
  final usable = all.where((x) =>
      !x.disabled && (realm == null || realm == 'all' || x.realmId == realm));
  return shuffled(usable.toList());
});

class ListenScreen extends ConsumerStatefulWidget {
  const ListenScreen({super.key});

  @override
  ConsumerState<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends ConsumerState<ListenScreen> {
  final _pages = PageController();
  int _index = 0;

  /// Which sentences have had their reading revealed. Per card, so a tap does
  /// not turn the whole feed into reading practice.
  final _revealed = <int>{};

  /// Keeps playing and moving on by itself until stopped. Off from the start
  /// on a device with no English voice: without audio, moving on by itself is
  /// just a page turning under nobody.
  bool _auto = false;

  /// Guards the hand-off between speaking and turning the page: a swipe during
  /// playback must not be undone by the advance that playback started.
  int _speaking = -1;
  Timer? _gap;

  /// Held directly: `ref` may not be read once the widget is disposed, and
  /// leaving the feed must still stop the audio.
  late final SpeechService _speech;

  @override
  void initState() {
    super.initState();
    _speech = ref.read(speechProvider);
    _auto = _speech.available;
  }

  @override
  void dispose() {
    _gap?.cancel();
    _pages.dispose();
    _speech.stop();
    super.dispose();
  }

  /// How long a card stays up at the very least. Some engines report a voice,
  /// accept the text and return immediately without saying anything; without a
  /// floor the feed then flicks through the whole library in seconds.
  static const _minDwell = Duration(milliseconds: 2600);

  Future<void> _playCurrent(List<Sentence> feed) async {
    if (feed.isEmpty) return;
    final at = _index;
    _speaking = at;
    final started = DateTime.now();
    await _speech.speak(feed[at].text, rate: ref.read(settingsProvider).rate);

    // `speak` returns when the engine has finished, so this is the end of the
    // sentence rather than the start of it — unless the engine said nothing,
    // which is what the floor below is for.
    if (!mounted || !_auto || _index != at) return;
    final spent = DateTime.now().difference(started);
    final wait = spent >= _minDwell
        ? const Duration(milliseconds: 900)
        : _minDwell - spent;
    _gap?.cancel();
    _gap = Timer(wait, () {
      if (!mounted || !_auto || _index != at) return;
      if (at + 1 >= feed.length) {
        setState(() => _auto = false);
        return;
      }
      _pages.nextPage(
          duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    });
  }

  void _onPage(int i, List<Sentence> feed) {
    _gap?.cancel();
    setState(() => _index = i);
    if (_auto) _playCurrent(feed);
  }

  void _toggleAuto(List<Sentence> feed) {
    _gap?.cancel();
    setState(() => _auto = !_auto);
    if (_auto) {
      _playCurrent(feed);
    } else {
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('listenTitle'))),
      body: ref.watch(_feedProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (feed) {
              if (feed.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(s.t('listenEmpty'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                );
              }

              // The first sentence has to be started by something; every later
              // one is started by the page that arrives.
              if (_speaking < 0 && _auto) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _speaking < 0) _playCurrent(feed);
                });
              }

              return Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      scrollDirection: Axis.vertical,
                      itemCount: feed.length,
                      onPageChanged: (i) => _onPage(i, feed),
                      itemBuilder: (context, i) =>
                          _card(feed[i], i, s, theme),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.t('listenPosition',
                                {'n': _index + 1, 'total': feed.length}),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                        IconButton.filled(
                          onPressed: () => _toggleAuto(feed),
                          icon: Icon(_auto ? Icons.pause : Icons.play_arrow),
                          tooltip: _auto ? s.t('listenPause') : s.t('listenPlay'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Widget _card(Sentence x, int i, dynamic s, ThemeData theme) {
    final shown = _revealed.contains(i);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(
          () => shown ? _revealed.remove(i) : _revealed.add(i)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (x.context.isNotEmpty) ...[
              Text(x.context.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
            ],
            Text(x.text,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.35)),
            const SizedBox(height: 16),
            // The reading waits for a tap. Reading along instead of listening
            // is the one thing that would make this exercise pointless.
            if (shown)
              Text(x.translationNative,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
            else
              Row(children: [
                Icon(Icons.touch_app_outlined,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(s.t('listenTapForMeaning'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            const SizedBox(height: 24),
            Text(s.t('listenSwipeHint'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            // Said once, on the card: a feed that turns pages in silence
            // otherwise looks broken rather than unsupported.
            if (!_speech.available) ...[
              const SizedBox(height: 8),
              Text(s.t(_speech.supported ? 'noAudioVoice' : 'noAudioSupport'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
