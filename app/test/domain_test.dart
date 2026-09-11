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

    test('a freeze covers a missed day', () {
      var p = Progress(streak: 9, bestStreak: 9, freezes: 2, lastStudyDay: addDays(t, -2));
      p = reconcileStreak(p, t);
      expect(p.streak, 9);
      expect(p.freezes, 1);
      expect(p.freezeUsed, 1);
      p = registerStudyDay(p, t).progress;
      expect(p.streak, 10);
    });

    test('insufficient freezes break the streak but are not wasted', () {
      var p = Progress(streak: 20, bestStreak: 20, freezes: 1, lastStudyDay: addDays(t, -4));
      p = reconcileStreak(p, t);
      expect(p.streak, 0);
      expect(p.freezes, 1, reason: 'a freeze that cannot save the streak is kept');
      expect(p.streakLostFrom, 20);
      expect(p.bestStreak, 20, reason: 'the best is a record, not a current state');
      p = registerStudyDay(p, t).progress;
      expect(p.streak, 1);
      expect(p.bestStreak, 20);
    });

    test('reconciling twice on the same day spends nothing extra', () {
      var p = Progress(streak: 4, freezes: 2, lastStudyDay: addDays(t, -2));
      p = reconcileStreak(p, t);
      final after = p.freezes;
      p = reconcileStreak(p, t);
      expect(p.freezes, after);
    });
  });

  // ============================================================= chest
  group('chest', () {
    test('all three chest rewards occur and each has an effect', () {
      final ids = <String>{};
      for (var i = 0; i < 3000; i++) {
        ids.add(openChest().id);
      }
      expect(ids.length, 3);

      const p = Progress();
      expect(applyChest(p, chestTable[0]).freezes, p.freezes + 1);
      expect(applyChest(p, chestTable[1]).pendingBoost, chestBoost);
      expect(applyChest(p, chestTable[2]).seeds, p.seeds + chestSeedBonus);
    });

    test('every reward is denominated in something that still exists', () {
      // The chest used to pay in XP, which the app no longer has. A reward
      // nobody can see is worse than no reward at all.
      for (final r in chestTable) {
        expect(applyChest(const Progress(), r), isNot(const Progress()),
            reason: r.id);
      }
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
