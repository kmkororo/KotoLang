/// The debate gym's material: opponents that argue back, the moves an
/// argument is built from, and the record of what the learner said.
///
/// Everything here arrives from the learner's own AI as a "pack" and is stored
/// whole. A tree is read and written as one unit, never queried across, so its
/// nodes live as JSON inside the debate row rather than in a table of their
/// own — the same policy the rest of the schema follows for list-valued data.
library;

// ------------------------------------------------------------------ moves

/// What one piece of an argument is doing. Fixed and small on purpose: the
/// structural check after each rebuttal ("did you concede, then push back,
/// then give a reason?") only works if every chunk and every model rebuttal
/// is tagged from the same short list.
enum Move {
  concede,
  however,
  reason,
  evidence,
  example,
  question,
  reframe,
  propose,
  clarify,
  close;

  static Move? parse(String s) {
    final k = s.trim().toLowerCase();
    for (final m in Move.values) {
      if (m.name == k) return m;
    }
    return null;
  }
}

/// A reusable piece of argument with a slot or two for content. Generated
/// once, topic-independent, and used by every tree afterwards.
class Chunk {
  final String id;
  final Move move;

  /// English, with `{x}`-style slots where the topic goes.
  final String text;
  final String native;

  const Chunk({
    required this.id,
    required this.move,
    required this.text,
    this.native = '',
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'move': move.name, 'text': text, 'native': native};

  factory Chunk.fromJson(Map<String, dynamic> j) => Chunk(
        id: j['id'] as String,
        move: Move.parse('${j['move']}') ?? Move.reason,
        text: (j['text'] ?? '') as String,
        native: (j['native'] ?? '') as String,
      );
}

// ------------------------------------------------------------------ trees

/// How a rebuttal lands. Decided by the AI at generation time, so the app
/// never has to judge an argument — it only has to follow the branch.
enum Strength {
  strong,
  weak,
  concede;

  static Strength? parse(String s) {
    final k = s.trim().toLowerCase();
    for (final v in Strength.values) {
      if (v.name == k) return v;
    }
    return null;
  }
}

/// Where a line of argument ends up.
enum Outcome {
  /// The opponent gave ground.
  won,

  /// Neither side moved; the point stands.
  held,

  /// The opponent pushed through.
  pressed,

  /// The learner gave the point away.
  conceded;

  static Outcome? parse(String s) {
    final k = s.trim().toLowerCase();
    for (final v in Outcome.values) {
      if (v.name == k) return v;
    }
    return null;
  }

  /// The ending a leaf rebuttal gets when the AI forgot to write one. A strong
  /// reply that ends the exchange has won it; a weak one has been pushed
  /// through; a concession is a concession.
  static Outcome forStrength(Strength s) => switch (s) {
        Strength.strong => Outcome.won,
        Strength.weak => Outcome.pressed,
        Strength.concede => Outcome.conceded,
      };
}

/// One thing to catch in the opponent's line, with the wrong answers to sit
/// beside it. All in the learner's language: this tests whether the line was
/// understood, not whether English can be read.
class GraspItem {
  final String answer;
  final List<String> options;

  const GraspItem({required this.answer, required this.options});

  Map<String, dynamic> toJson() => {'answer': answer, 'options': options};

  factory GraspItem.fromJson(Map<String, dynamic> j) => GraspItem(
        answer: (j['answer'] ?? '') as String,
        options: ((j['options'] as List?) ?? const []).cast<String>(),
      );
}

/// The three things to catch before answering: what they claimed, why, and
/// where it gives. Listening to rebut is a different skill from listening to
/// understand, and this is the part of the exercise that trains it.
class Grasp {
  final GraspItem claim;
  final GraspItem reason;
  final GraspItem weakPoint;

  const Grasp({
    required this.claim,
    required this.reason,
    required this.weakPoint,
  });

  Map<String, dynamic> toJson() => {
        'claim': claim.toJson(),
        'reason': reason.toJson(),
        'weak_point': weakPoint.toJson(),
      };

  factory Grasp.fromJson(Map<String, dynamic> j) => Grasp(
        claim: GraspItem.fromJson(Map<String, dynamic>.from(j['claim'] as Map)),
        reason:
            GraspItem.fromJson(Map<String, dynamic>.from(j['reason'] as Map)),
        weakPoint: GraspItem.fromJson(
            Map<String, dynamic>.from(j['weak_point'] as Map)),
      );
}

/// One possible reply to a line, and where it leads.
class Rebuttal {
  final String id;
  final Strength strength;

  /// The model wording: what a strong speaker would actually say.
  final String model;
  final List<Move> moves;

  /// What goes in the chunks' slots for this reply, keyed by slot name.
  final Map<String, String> slots;

  /// The node the opponent answers from, or null when this reply ends the
  /// exchange — in which case [outcome] says how.
  final String? next;
  final Outcome? outcome;

  const Rebuttal({
    required this.id,
    required this.strength,
    required this.model,
    this.moves = const [],
    this.slots = const {},
    this.next,
    this.outcome,
  });

  bool get isLeaf => next == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'strength': strength.name,
        'model': model,
        'moves': [for (final m in moves) m.name],
        'slots': slots,
        'next': next,
        'outcome': outcome?.name,
      };

  factory Rebuttal.fromJson(Map<String, dynamic> j) => Rebuttal(
        id: j['id'] as String,
        strength: Strength.parse('${j['strength']}') ?? Strength.weak,
        model: (j['model'] ?? '') as String,
        moves: [
          for (final m in (j['moves'] as List? ?? const []))
            if (Move.parse('$m') != null) Move.parse('$m')!
        ],
        slots: Map<String, String>.from(
            (j['slots'] as Map? ?? const {}).map((k, v) => MapEntry('$k', '$v'))),
        next: j['next'] as String?,
        outcome: j['outcome'] == null ? null : Outcome.parse('${j['outcome']}'),
      );
}

/// One thing the opponent says, what to catch in it, and the replies open to
/// the learner.
class DebateNode {
  final String id;
  final String line;
  final String lineNative;
  final Grasp grasp;
  final List<Rebuttal> rebuttals;

  const DebateNode({
    required this.id,
    required this.line,
    required this.lineNative,
    required this.grasp,
    required this.rebuttals,
  });

  Rebuttal? get strongest =>
      rebuttals.where((r) => r.strength == Strength.strong).firstOrNull;

  Map<String, dynamic> toJson() => {
        'id': id,
        'line': line,
        'line_native': lineNative,
        'grasp': grasp.toJson(),
        'rebuttals': [for (final r in rebuttals) r.toJson()],
      };

  factory DebateNode.fromJson(Map<String, dynamic> j) => DebateNode(
        id: j['id'] as String,
        line: (j['line'] ?? '') as String,
        lineNative: (j['line_native'] ?? '') as String,
        grasp: Grasp.fromJson(Map<String, dynamic>.from(j['grasp'] as Map)),
        rebuttals: [
          for (final r in (j['rebuttals'] as List? ?? const []))
            Rebuttal.fromJson(Map<String, dynamic>.from(r as Map))
        ],
      );
}

/// A whole argument with one opponent: the tree the learner walks down, one
/// line at a time, in the train.
class DebateTree {
  final String id;
  final String topic;
  final String topicNative;

  /// The real-life date this was built for, as a day key, when there was one.
  final String? event;
  final String persona;
  final String personaNative;
  final String position;
  final String positionNative;

  /// The area this belongs to, when it maps onto one the learner studies.
  final String? realmId;

  /// In tree order: the first node is where the exchange opens.
  final List<DebateNode> nodes;
  final int createdAt;
  final bool disabled;

  const DebateTree({
    required this.id,
    required this.topic,
    required this.topicNative,
    this.event,
    required this.persona,
    required this.personaNative,
    required this.position,
    required this.positionNative,
    this.realmId,
    required this.nodes,
    required this.createdAt,
    this.disabled = false,
  });

  DebateNode get root => nodes.first;

  DebateNode? node(String id) => nodes.where((n) => n.id == id).firstOrNull;

  /// The label shown to the learner: their language first.
  String get label => topicNative.isNotEmpty ? topicNative : topic;

  DebateTree copyWith({bool? disabled, String? realmId}) => DebateTree(
        id: id,
        topic: topic,
        topicNative: topicNative,
        event: event,
        persona: persona,
        personaNative: personaNative,
        position: position,
        positionNative: positionNative,
        realmId: realmId ?? this.realmId,
        nodes: nodes,
        createdAt: createdAt,
        disabled: disabled ?? this.disabled,
      );
}

// ---------------------------------------------------------------- feedback

/// What the AI said about one attempt, once the next pack brought it back.
class Critique {
  final String attemptId;
  final String verdictNative;
  final List<String> better;
  final String watchNative;

  const Critique({
    required this.attemptId,
    required this.verdictNative,
    this.better = const [],
    this.watchNative = '',
  });

  Map<String, dynamic> toJson() => {
        'attempt': attemptId,
        'verdict_native': verdictNative,
        'better': better,
        'watch_native': watchNative,
      };

  factory Critique.fromJson(Map<String, dynamic> j) => Critique(
        attemptId: (j['attempt'] ?? '') as String,
        verdictNative: (j['verdict_native'] ?? '') as String,
        better: ((j['better'] as List?) ?? const []).cast<String>(),
        watchNative: (j['watch_native'] ?? '') as String,
      );
}

/// One reply the learner gave to one line. Kept so the next pack can carry it
/// out for critique, and so the critique has somewhere to land when it comes
/// back.
class Attempt {
  final String id;
  final String debateId;
  final String nodeId;
  final String youSaid;
  final List<Move> moves;

  /// The model rebuttal the attempt was judged closest to, and its strength.
  final String? closest;
  final Strength? closestStrength;
  final String day;
  final int at;
  final Critique? critique;

  const Attempt({
    required this.id,
    required this.debateId,
    required this.nodeId,
    required this.youSaid,
    this.moves = const [],
    this.closest,
    this.closestStrength,
    required this.day,
    required this.at,
    this.critique,
  });

  bool get awaitingCritique => critique == null;

  Attempt withCritique(Critique c) => Attempt(
        id: id,
        debateId: debateId,
        nodeId: nodeId,
        youSaid: youSaid,
        moves: moves,
        closest: closest,
        closestStrength: closestStrength,
        day: day,
        at: at,
        critique: c,
      );
}

/// A line the learner wrote down in twenty seconds after a real conversation:
/// what is coming, or what could not be said. Raw material for the next pack.
class Capture {
  final String id;
  final String noteNative;

  /// A day key, when the note is about a date.
  final String? date;
  final String who;
  final int createdAt;

  /// Set once a pack prompt has carried it out. Kept rather than deleted, so
  /// the learner can see what they asked for.
  final int? consumedAt;

  const Capture({
    required this.id,
    required this.noteNative,
    this.date,
    this.who = '',
    required this.createdAt,
    this.consumedAt,
  });

  bool get pending => consumedAt == null;
}

/// Something that went wrong in a debate, written by the app rather than the
/// learner. The AI reads these to aim the next pack's reinforcement.
class Failure {
  final String id;
  final String debateId;
  final String nodeId;

  /// A short machine key: `no_evidence_move`, `weak_point_missed`, `pressed`.
  final String kind;
  final String noteNative;
  final int at;
  final int? consumedAt;

  const Failure({
    required this.id,
    required this.debateId,
    required this.nodeId,
    required this.kind,
    required this.noteNative,
    required this.at,
    this.consumedAt,
  });

  bool get pending => consumedAt == null;
}
