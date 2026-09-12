/// The parts of the old headless suite that still describe this app: the
/// arithmetic the review dates are built on, the normalising that decides
/// when two things are the same thing, and the streak.
library;


import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/core/util.dart';
import 'package:kotolang/domain/models.dart';
import 'package:kotolang/domain/ladder.dart';
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

  // ============================================================= opening
  group('what opens a field', () {
    test('the three chosen at the start are there from the start', () {
      expect(fieldsOpenAt(0), freeRealmSlots);
    });

    test('one more opens every few steps of the ladder, and never unopens', () {
      var last = fieldsOpenAt(0);
      for (var reached = 0; reached <= ladderSteps; reached++) {
        final now = fieldsOpenAt(reached);
        expect(now, greaterThanOrEqualTo(last), reason: 'step $reached');
        expect(now, greaterThanOrEqualTo(freeRealmSlots), reason: 'step $reached');
        last = now;
      }
      expect(fieldsOpenAt(stepsPerField), freeRealmSlots + 1);
      expect(fieldsOpenAt(stepsPerField * 2), freeRealmSlots + 2);
    });

    test('it says how far off the next one is, and stops saying it at the end', () {
      expect(stepsToNextField(0, fieldsHeld: 9), stepsPerField);
      expect(stepsToNextField(stepsPerField - 1, fieldsHeld: 9), 1);
      // Everything the profile named is already open: there is nothing left
      // for the number to be about.
      expect(stepsToNextField(0, fieldsHeld: freeRealmSlots), isNull);
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
