/// The ladder: the learning itself, and the only thing that measures it.
///
/// Five things can be made harder — how fast the line is said, how much noise
/// is behind it, how soon the translation appears, whose accent it is, and
/// whether it is said a second time. Each is cut into small steps, more than
/// fifty of them together, and a step opens only when it has been held.
///
/// There is nothing to buy here. A step is reached, not bought, and the only
/// way to go up is to keep answering at the hardest setting already reached.
library;

/// The five things that can be made harder.
enum LadderAxis {
  /// 1.00x to 1.96x, in twenty-fifths. Cut this fine because speed is where
  /// most of the climbing happens, and a step the ear cannot feel is a step
  /// nobody is afraid of.
  speed,

  /// How loud the room behind the voice is.
  noise,

  /// How long the translation waits: at once, a few seconds, only on a tap,
  /// never. Cut fine, because each of those is a large change on its own.
  translation,

  /// Which region the voice comes from.
  accent,

  /// Whether a missed moment is given again in other words, or not at all.
  /// Cut fine for the same reason as the translation.
  replay;
}

/// The topmost step of each axis. Zero is where everyone starts: the plainest
/// voice, no noise, the translation at once, a second chance at every turn.
///
/// The coarse axes are cut finer than the design first had them. A single
/// step that takes the translation away entirely, or takes away the second
/// chance, is too large a change to earn in one promotion — and the promise
/// of this app is many small hurdles, not a few big ones.
const axisTop = <LadderAxis, int>{
  LadderAxis.speed: 24,
  LadderAxis.noise: 12,
  LadderAxis.translation: 7,
  LadderAxis.accent: 5,
  LadderAxis.replay: 3,
};

/// Every step of every axis, added up. What the tree's height is read from.
int get ladderSteps => axisTop.values.fold(0, (a, b) => a + b);

/// How many answers at a setting before it can be judged.
const ladderWindow = 10;

/// How many of those have to be right.
const ladderPassRate = 0.8;

/// How far the whole ladder climbs between one situation opening and the next.
const stepsPerSituation = 3;

/// How fast the line is said at [step].
double speedAt(int step) => 1.0 + step * 0.04;

/// One axis: where the learner is now, the highest they have ever held, and
/// the answers given since the last promotion.
class AxisState {
  /// The setting in use. Never above [max] — a step has to be reached first.
  final int current;

  /// The highest step ever held. This never falls, so going back down to
  /// something comfortable costs nothing.
  final int max;

  /// Answers given at [max], since the last promotion.
  final List<bool> buffer;

  const AxisState({this.current = 0, this.max = 0, this.buffer = const []});

  /// Whether this axis is being used at its frontier. Only then does an
  /// answer say anything about it: an axis dialled down to something
  /// comfortable is not being tested, so neither its successes nor its
  /// failures are worth recording.
  bool get atFrontier => current >= max;

  AxisState copyWith({int? current, int? max, List<bool>? buffer}) => AxisState(
        current: current ?? this.current,
        max: max ?? this.max,
        buffer: buffer ?? this.buffer,
      );

  Map<String, dynamic> toJson() => {'current': current, 'max': max, 'buffer': buffer};

  factory AxisState.fromJson(Map<String, dynamic> j) => AxisState(
        current: (j['current'] as num?)?.toInt() ?? 0,
        max: (j['max'] as num?)?.toInt() ?? 0,
        buffer: [for (final b in (j['buffer'] as List? ?? const [])) b == true],
      );
}

/// Where the learner stands on all five axes.
class Ladder {
  final Map<LadderAxis, AxisState> axes;
  const Ladder(this.axes);

  static const empty = Ladder({});

  AxisState of(LadderAxis a) => axes[a] ?? const AxisState();

  int currentOf(LadderAxis a) => of(a).current;
  int maxOf(LadderAxis a) => of(a).max;

  /// The height the tree is read from: every step ever reached, added up.
  int get reached => LadderAxis.values.fold(0, (sum, a) => sum + maxOf(a));

  /// How many situations this much climbing has opened.
  int get situationsOpen => 1 + reached ~/ stepsPerSituation;

  Ladder withAxis(LadderAxis a, AxisState s) => Ladder({...axes, a: s});

  /// Moves an axis to [step], as far as it has been reached. Going down is
  /// free and loses nothing; going above [AxisState.max] is not a thing the
  /// learner can do, since a step has to be earned before it can be used.
  Ladder setTo(LadderAxis a, int step) {
    final s = of(a);
    final want = step < 0 ? 0 : (step > s.max ? s.max : step);
    // The buffer holds answers given at the frontier. Stepping away from the
    // frontier abandons them rather than mixing them with easier ones.
    return withAxis(a, s.copyWith(current: want, buffer: const []));
  }

  /// Takes in one answer.
  ///
  /// It counts only towards the axes being held at their frontier. An axis
  /// left somewhere comfortable learns nothing from it — which is what stops
  /// a learner who only ever raises the noise from climbing the speed ladder
  /// they have never heard.
  ///
  /// And it counts only a **clean** answer: inside the window, on one
  /// hearing. A right answer given after the line was played again says the
  /// learner can do this with a second listen, which is a different claim
  /// from the one every step of this ladder makes — and counting it would
  /// let somebody climb to the top by letting every window close first.
  /// A second hearing is not punished, it simply says nothing: the buffer
  /// does not see the answer at all.
  ///
  /// An axis promoted this way carries its setting up with it. Without that,
  /// the first promotion would put every axis one step above where it is
  /// being played, and nothing would ever count again.
  ({Ladder ladder, List<LadderAxis> promoted}) record(bool correct, {bool clean = true}) {
    if (!clean) return (ladder: this, promoted: const <LadderAxis>[]);
    final next = <LadderAxis, AxisState>{};
    final promoted = <LadderAxis>[];

    for (final a in LadderAxis.values) {
      final s = of(a);
      if (!s.atFrontier || s.max >= (axisTop[a] ?? 0)) {
        next[a] = s;
        continue;
      }
      final buffer = [...s.buffer, correct];
      if (buffer.length < ladderWindow) {
        next[a] = s.copyWith(buffer: buffer);
        continue;
      }
      final right = buffer.where((b) => b).length;
      if (right / buffer.length >= ladderPassRate) {
        // One step at a time, however well the window went: the point of
        // fifty small hurdles is the rhythm of clearing one every few
        // answers, not clearing several at once.
        promoted.add(a);
        next[a] = AxisState(current: s.max + 1, max: s.max + 1);
      } else {
        // Not this time. The window starts again rather than sliding, so a
        // bad patch is not carried forward for ever.
        next[a] = s.copyWith(buffer: const []);
      }
    }
    return (ladder: Ladder(next), promoted: promoted);
  }

  Map<String, dynamic> toJson() =>
      {for (final e in axes.entries) e.key.name: e.value.toJson()};

  factory Ladder.fromJson(Map<String, dynamic> j) => Ladder({
        for (final a in LadderAxis.values)
          if (j[a.name] is Map)
            a: AxisState.fromJson(Map<String, dynamic>.from(j[a.name] as Map))
      });
}
