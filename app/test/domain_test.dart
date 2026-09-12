/// The parts of the old headless suite that still describe this app: the
/// arithmetic the review dates are built on, the normalising that decides
/// when two things are the same thing, and the streak.
library;


import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/core/util.dart';
import 'package:kotolang/domain/models.dart';
import 'package:kotolang/domain/progress_service.dart';

void main() {
  // ================================================================ dates
  group('day arithmetic', () {
    test('crosses month, year and leap boundaries', () {
      expect(addDays('2026-01-31', 1), '2026-02-01');
      expect(addDays('2026-12-31', 1), '2027-01-01');
      expect(addDays('2028-02-28', 1), '2028-02-29');
      expect(addDays('2026-03-01', 35), '2026-04-05');
    });

    test('daysBetween is signed and exact', () {
      expect(daysBetween('2026-08-17', '2026-08-22'), 5);
      expect(daysBetween('2026-01-31', '2026-02-01'), 1);
      expect(daysBetween('2026-08-22', '2026-08-17'), -5);
      expect(daysBetween('2026-08-22', '2026-08-22'), 0);
    });

    test('a full year of round trips never drifts', () {
      // Runs across daylight-saving transitions in either hemisphere.
      var key = '2026-01-01';
      for (var i = 0; i < 365; i++) {
        final next = addDays(key, 1);
        expect(daysBetween(key, next), 1, reason: 'from $key');
        key = next;
      }
      expect(key, '2027-01-01');
    });
  });

  // ================================================================ text
  group('normalisation', () {
    test('duplicate detection ignores case, spacing and punctuation', () {
      expect(normKey('Repair  Policy'), normKey('repair policy'));
      expect(normKey('repair policy.'), normKey('repair policy'));
    });

    test('phrase containment respects word boundaries', () {
      expect(containsPhrase('We reviewed the repair policy today.', 'repair policy'), isTrue);
      expect(containsPhrase('We repaired it.', 'repair policy'), isFalse);
    });
  });

  // ================================================================ SRS
  group('streak', () {
    final t = today();

    test('a day counts once no matter how many answers', () {
      var p = const Progress();
      var r = registerStudyDay(p, t);
      p = r.progress;
      expect(p.streak, 1);
      expect(r.result.advanced, isTrue);

      for (var i = 0; i < 30; i++) {
        r = registerStudyDay(p, t);
        p = r.progress;
      }
      expect(p.streak, 1, reason: '30 answers on one day is still one day');
      expect(r.result.advanced, isFalse);
    });

    test('consecutive days chain', () {
      var p = const Progress();
      p = registerStudyDay(p, t).progress;
      p = registerStudyDay(p, addDays(t, 1)).progress;
      expect(p.streak, 2);
      expect(p.bestStreak, 2);
    });

    test('a missed day breaks the chain, and the best of it is kept', () {
      // There is no token that could have covered the gap. A rest day was a
      // thing to be given and spent, and this app keeps no balance of
      // anything — so the honest answer is that the streak went.
      var p = Progress(streak: 20, bestStreak: 20, lastStudyDay: addDays(t, -4));
      p = reconcileStreak(p, t);
      expect(p.streak, 0);
      expect(p.streakLostFrom, 20, reason: 'home says what happened');
      expect(p.bestStreak, 20, reason: 'the best is a record, not a current state');
      p = registerStudyDay(p, t).progress;
      expect(p.streak, 1);
      expect(p.bestStreak, 20);
    });

    test('one day missed is still one day missed', () {
      var p = Progress(streak: 9, bestStreak: 9, lastStudyDay: addDays(t, -2));
      p = reconcileStreak(p, t);
      expect(p.streak, 0);
      expect(p.streakLostFrom, 9);
    });

    test('reconciling twice on the same day says the same thing twice', () {
      var p = Progress(streak: 4, lastStudyDay: addDays(t, -2));
      p = reconcileStreak(p, t);
      final once = p.streakLostFrom;
      p = reconcileStreak(p, t);
      expect(p.streakLostFrom, 0,
          reason: 'the notice is cleared once it has been shown');
      expect(once, 4);
    });
  });

  // ====================================================== the answer window
  group('how long there is to answer', () {
    test('the setting scales what the conversation asks for', () {
      // A flat number of seconds would flatten the conversations: one person
      // is on their way out and gives you two seconds, another is thinking
      // aloud and gives you four. The setting stretches both.
      const hurried = 2000, unhurried = 4000;
      for (final scale in windowScales) {
        expect((hurried * scale).round() < (unhurried * scale).round(), isTrue,
            reason: 'at ×$scale the two are still different');
      }
      expect((hurried * windowScales.first).round(),
          lessThan((hurried * windowScales.last).round()));
    });

    test('a stored scale from another build is snapped to one on offer', () {
      for (final v in windowScales) {
        expect(offeredWindowScale(v), v);
      }
      expect(offeredWindowScale(1.1), 1.0);
      expect(offeredWindowScale(3.0), windowScales.last);
      expect(offeredWindowScale(0.1), windowScales.first);
    });
  });

  // ========================================================= what it pays

  group('what a turn is worth', () {
    test('a wrong answer is worth nothing', () {
      // Paying for those would make the balance a measure of time spent
      // rather than of anything heard.
      expect(seedsForTurn(correct: false, clean: true, windowLeft: 1), 0);
      expect(seedsForTurn(correct: false, clean: false, windowLeft: 0), 0);
    });

    test('the faster it was, the more it pays', () {
      final slow = seedsForTurn(correct: true, clean: true, windowLeft: 0);
      final quick = seedsForTurn(correct: true, clean: true, windowLeft: 1);
      expect(slow, seedFloor);
      expect(quick, seedTop);
      expect(seedsForTurn(correct: true, clean: true, windowLeft: 0.5),
          inInclusiveRange(slow, quick));
    });

    test('a second hearing pays the floor and no more', () {
      // It was right, and it was still not caught the first time.
      expect(seedsForTurn(correct: true, clean: false, windowLeft: 1), seedFloor);
    });
  });

  group('combo', () {
    test('a short run pays nothing, a long one is capped', () {
      expect(comboBonus(0), 0);
      expect(comboBonus(2), 0);
      expect(comboBonus(3), 1);
      expect(comboBonus(5), 3);
      expect(comboBonus(50), maxComboBonus);
    });

    test('the bonus only ever adds', () {
      for (var i = 0; i < 30; i++) {
        expect(comboBonus(i), greaterThanOrEqualTo(0));
      }
    });
  });

}
