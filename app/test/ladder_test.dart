/// The ladder: a step is reached, never bought, and only the axis actually
/// being held at its hardest can learn anything from an answer.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/domain/ladder.dart';

Ladder answer(Ladder l, int times, {bool correct = true}) {
  var out = l;
  for (var i = 0; i < times; i++) {
    out = out.record(correct).ladder;
  }
  return out;
}

void main() {
  test('everything starts at the bottom, and the bottom is the frontier', () {
    const l = Ladder.empty;
    for (final a in LadderAxis.values) {
      expect(l.currentOf(a), 0);
      expect(l.maxOf(a), 0);
      expect(l.of(a).atFrontier, isTrue);
    }
    expect(l.reached, 0);
  });

  test('a window of right answers moves every axis up exactly one step', () {
    final out = answer(Ladder.empty, ladderWindow);
    for (final a in LadderAxis.values) {
      expect(out.maxOf(a), 1, reason: a.name);
      // The setting comes up with the step. Left behind, the axis would sit
      // below its own frontier and never count another answer.
      expect(out.currentOf(a), 1, reason: a.name);
    }
  });

  test('a long right streak still only moves one step per window', () {
    final out = answer(Ladder.empty, ladderWindow * 3);
    for (final a in LadderAxis.values) {
      expect(out.maxOf(a), 3, reason: a.name);
    }
  });

  test('an axis left behind stops counting after one step', () {
    // Everything up one, then the speed dialled back to where it started.
    var l = answer(Ladder.empty, ladderWindow);
    l = l.setTo(LadderAxis.speed, 0);
    expect(l.currentOf(LadderAxis.speed), 0);
    expect(l.maxOf(LadderAxis.speed), 1);
    expect(l.of(LadderAxis.speed).atFrontier, isFalse);

    // A hundred right answers at the easy speed.
    l = answer(l, ladderWindow * 10);
    expect(l.maxOf(LadderAxis.speed), 1,
        reason: 'speed was never heard above its first step');
    expect(l.maxOf(LadderAxis.noise), greaterThan(1),
        reason: 'the axes actually being held did climb');
  });

  test('an axis left behind is not dragged down either', () {
    var l = answer(Ladder.empty, ladderWindow);
    l = l.setTo(LadderAxis.speed, 0);
    final before = l.maxOf(LadderAxis.speed);
    l = answer(l, ladderWindow * 2, correct: false);
    expect(l.maxOf(LadderAxis.speed), before);
    expect(l.of(LadderAxis.speed).buffer, isEmpty);
  });

  test('a window that falls short starts again and costs nothing', () {
    var l = Ladder.empty;
    for (var i = 0; i < ladderWindow; i++) {
      l = l.record(i.isEven).ladder; // half right
    }
    for (final a in LadderAxis.values) {
      expect(l.maxOf(a), 0, reason: a.name);
      expect(l.of(a).buffer, isEmpty, reason: a.name);
    }
  });

  test('the top of an axis is the end of it', () {
    var l = Ladder.empty;
    l = answer(l, ladderWindow * (axisTop[LadderAxis.replay]! + 4));
    expect(l.maxOf(LadderAxis.replay), axisTop[LadderAxis.replay]);
    expect(l.currentOf(LadderAxis.replay), axisTop[LadderAxis.replay]);
  });

  test('a step can never be set above the one reached', () {
    final l = answer(Ladder.empty, ladderWindow);
    expect(l.setTo(LadderAxis.noise, 9).currentOf(LadderAxis.noise), 1);
    expect(l.setTo(LadderAxis.noise, -3).currentOf(LadderAxis.noise), 0);
  });

  test('height is every step ever reached, and it opens situations', () {
    final l = answer(Ladder.empty, ladderWindow * 2);
    expect(l.reached, LadderAxis.values.length * 2);
    expect(l.situationsOpen, 1 + l.reached ~/ stepsPerSituation);
  });

  test('the ladder survives being written down and read back', () {
    var l = answer(Ladder.empty, ladderWindow);
    l = l.setTo(LadderAxis.speed, 0);
    l = l.record(true).ladder;
    final back = Ladder.fromJson(l.toJson());
    for (final a in LadderAxis.values) {
      expect(back.currentOf(a), l.currentOf(a), reason: a.name);
      expect(back.maxOf(a), l.maxOf(a), reason: a.name);
      expect(back.of(a).buffer, l.of(a).buffer, reason: a.name);
    }
  });

  test('speed is cut in twentieths', () {
    expect(speedAt(0), 1.0);
    expect(speedAt(axisTop[LadderAxis.speed]!), closeTo(1.96, 0.001));
  });

  test('there are more than fifty steps in all', () {
    expect(ladderSteps, greaterThan(50));
  });
}
