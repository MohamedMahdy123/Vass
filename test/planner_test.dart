import 'package:flutter_test/flutter_test.dart';
import 'package:vess/state/outfit_state.dart';
import 'package:vess/state/planner_state.dart';

SavedOutfit _look(String id) =>
    SavedOutfit(id: id, title: 'Look $id', items: const [], tags: const [], score: 50);

void main() {
  group('PlannerState (demo mode)', () {
    test('keyFor formats a zero-padded yyyy-MM-dd key', () {
      expect(PlannerState.keyFor(DateTime(2026, 1, 5)), '2026-01-05');
      expect(PlannerState.keyFor(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('plan then read then clear round-trips in memory', () {
      final p = PlannerState();
      final day = DateTime(2026, 9, 20);
      expect(p.outfitIdFor(day), isNull);
      p.plan(day, 'outfit-x');
      expect(p.outfitIdFor(day), 'outfit-x');
      // Planning the same day replaces the prior look.
      p.plan(day, 'outfit-y');
      expect(p.outfitIdFor(day), 'outfit-y');
      p.clear(day);
      expect(p.outfitIdFor(day), isNull);
    });

    test('load seeds upcoming days from the saved looks in demo mode', () async {
      final p = PlannerState();
      await p.load([_look('a'), _look('b')]);
      expect(p.plannedCount, 2);
      final now = DateTime.now();
      expect(p.outfitIdFor(now.add(const Duration(days: 1))), 'a');
      expect(p.outfitIdFor(now.add(const Duration(days: 2))), 'b');
    });

    test('load with no saved looks plans nothing', () async {
      final p = PlannerState();
      await p.load(const []);
      expect(p.plannedCount, 0);
    });
  });
}
