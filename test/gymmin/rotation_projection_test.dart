import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
  });

  tearDown(() {
    if (fit.session != null) fit.saveAndExit();
  });

  // A fixed "today" far from the real date, so the projection does not depend on the clock.
  final today = DateTime(2026, 3, 6);
  DateTime day(int offset, [int hour = 10]) => DateTime(today.year, today.month, today.day + offset, hour);

  String bench() => fit.matchExerciseByName('Bench Press')!.id;

  Routine routine(String name) {
    final id = fit.createRoutine(name);
    fit.toggleRoutineExercise(id, bench());
    return fit.routines.firstWhere((r) => r.id == id);
  }

  void train(Routine r, DateTime on) {
    fit.startRoutine(r, on: on);
    fit.endCountdown();
    fit.toggleSet(0, 0);
    fit.finishSession();
    fit.saveAndExit();
  }

  void logFree(DateTime at, {bool cardio = false}) {
    fit.sessions.add(LoggedSession(at, 1800, [
      cardio
          ? LoggedExercise('outdoor-run', 'Outdoor Run', 'quads', [LoggedSet(0, 0, sec: 1800, km: 5)])
          : LoggedExercise(bench(), 'Bench Press', 'chest', [LoggedSet(5, 60)]),
    ]));
    fit.sessions.sort((a, b) => a.date.compareTo(b.date));
  }

  List<String> cycle(List<Object> steps) {
    fit.setRotation(true);
    for (final s in steps) {
      if (s is Routine) {
        fit.toggleRotationRoutine(s.id);
      } else {
        fit.addRotationRest();
      }
    }
    return [...fit.rotationIds];
  }

  List<String> plan(int days, {int from = 0, DateTime? now}) => [
        for (final d in fit.rotationProjection(day(from), day(from + days - 1), today: now ?? today))
          d.routine?.name ?? (d.rest ? 'rest' : '-'),
      ];

  group('A, rest, B, rest', () {
    late Routine a, b;
    setUp(() {
      a = routine('A');
      b = routine('B');
      cycle([a, 'rest', b, 'rest']);
    });

    test('A done today: tomorrow rest, then B, rest, A', () {
      train(a, day(0));
      expect(plan(5), ['A', 'rest', 'B', 'rest', 'A']);
    });

    test('A done two days ago and nothing since: today is B', () {
      train(a, day(-2));
      expect(plan(3), ['B', 'rest', 'A']);
    });

    test('A done ten days ago: today is B, tomorrow rest, then A', () {
      train(a, day(-10));
      expect(plan(3), ['B', 'rest', 'A']);
    });

    test('A done yesterday: today is the rest step', () {
      train(a, day(-1));
      expect(plan(4), ['rest', 'B', 'rest', 'A']);
    });

    test('no sessions: today is the cursor routine and the list follows', () {
      expect(plan(6), ['A', 'rest', 'B', 'rest', 'A', 'rest']);
      fit.setRotationNext(b.id);
      expect(plan(4), ['B', 'rest', 'A', 'rest']);
    });

    test('an overdue routine stays today and pushes every later step back', () {
      train(a, day(-2));
      expect(plan(3, now: day(0)), ['B', 'rest', 'A']);
      expect(plan(3, from: 1, now: day(1)), ['B', 'rest', 'A']);
      expect(plan(3, from: 5, now: day(5)), ['B', 'rest', 'A']);
    });

    test('a free or cardio session yesterday does not move any projected day', () {
      train(a, day(-3));
      final before = plan(6);
      logFree(day(-1));
      logFree(day(-1, 18), cardio: true);
      expect(plan(6), before);
      expect(plan(6), ['B', 'rest', 'A', 'rest', 'B', 'rest']);
    });

    test('a free session today does not move the projection either', () {
      train(a, day(-3));
      logFree(day(0, 8));
      expect(plan(3), ['B', 'rest', 'A']);
    });

    test('two rotation workouts on one day advance by two routines', () {
      train(a, day(0));
      train(b, day(0));
      expect(plan(4), ['A', 'rest', 'A', 'rest']);
      expect(fit.rotationProjection(day(0), day(0), today: today).single.routine?.name, 'A');
    });

    test('a session dated in the future does not anchor the projection', () {
      train(a, day(3));
      final days = plan(5);
      expect(days.take(2), ['rest', 'B']);
      expect(days[3], 'A');
    });

    test('past days show the rotation routine logged that day, or nothing', () {
      train(a, day(-2));
      expect(plan(3, from: -3), ['-', 'A', '-']);
    });

    test('a removed or archived routine no longer appears', () {
      final c = routine('C');
      fit.toggleRotationRoutine(c.id);
      fit.addRotationRest();
      expect(plan(6), ['A', 'rest', 'B', 'rest', 'C', 'rest']);
      fit.toggleRotationRoutine(b.id);
      expect(plan(14), isNot(contains('B')));
      fit.archiveRoutine(c.id, true);
      expect(plan(14), isNot(contains('C')));
      expect(plan(3), ['A', 'rest', 'rest']);
    });

    test('an empty rotation projects nothing', () {
      fit.toggleRotationRoutine(a.id);
      fit.toggleRotationRoutine(b.id);
      expect(plan(4), ['-', '-', '-', '-']);
    });
  });

  group('rotation shapes', () {
    test('A, B with no rest steps: a routine every day, alternating', () {
      final a = routine('A'), b = routine('B');
      cycle([a, b]);
      expect(plan(5), ['A', 'B', 'A', 'B', 'A']);
      train(a, day(0));
      expect(plan(4), ['A', 'B', 'A', 'B']);
    });

    test('a rotation of one routine projects it every day', () {
      final a = routine('A');
      cycle([a]);
      expect(plan(3), ['A', 'A', 'A']);
      train(a, day(0));
      expect(plan(3), ['A', 'A', 'A']);
    });

    test('a rotation of rest steps only projects nothing', () {
      fit.setRotation(true);
      fit.addRotationRest();
      fit.addRotationRest();
      expect(plan(3), ['-', '-', '-']);
    });

    test('weekly-plan mode is not a rotation and projects nothing', () {
      final a = routine('A');
      fit.assignRoutineToDay(DateTime.monday, a.id);
      expect(plan(7), everyElement('-'));
    });
  });

  group('midnight', () {
    test('the time of day of today and of the range does not matter', () {
      final a = routine('A'), b = routine('B');
      cycle([a, 'rest', b, 'rest']);
      train(a, day(-1));
      final early = [
        for (final d in fit.rotationProjection(day(0, 0), day(3, 0), today: DateTime(2026, 3, 6, 0, 0)))
          d.routine?.name ?? (d.rest ? 'rest' : '-'),
      ];
      final late = [
        for (final d in fit.rotationProjection(day(0, 23), day(3, 23), today: DateTime(2026, 3, 6, 23, 59)))
          d.routine?.name ?? (d.rest ? 'rest' : '-'),
      ];
      expect(early, ['rest', 'B', 'rest', 'A']);
      expect(late, early);
      expect(fit.rotationProjection(day(0, 23), day(3, 1), today: today).map((d) => d.day),
          [for (var i = 0; i < 4; i++) DateTime(2026, 3, 6 + i)]);
    });

    test('a workout that ran past midnight counts for the day it started', () {
      final a = routine('A'), b = routine('B');
      final ids = cycle([a, 'rest', b, 'rest']);
      fit.sessions.add(LoggedSession(DateTime(2026, 3, 6, 0, 30), 3600, [], routineId: a.id));
      fit.rotationNextId = ids[1];
      fit.rotationRestDay = DateTime(2026, 3, 7);
      expect(plan(4), ['rest', 'B', 'rest', 'A']);
    });
  });

  group('adding routines from the picker', () {
    test('adding a routine with rest adds a rest step after it', () {
      final a = routine('A'), b = routine('B');
      fit.setRotation(true);
      fit.toggleRotationRoutine(a.id, rest: true);
      fit.toggleRotationRoutine(b.id, rest: true);
      expect(fit.rotationIds, [a.id, 'rest-1', b.id, 'rest-2']);
      expect(plan(4), ['A', 'rest', 'B', 'rest']);
    });

    test('the added rest step can be removed', () {
      final a = routine('A'), b = routine('B');
      fit.setRotation(true);
      fit.toggleRotationRoutine(a.id, rest: true);
      fit.toggleRotationRoutine(b.id, rest: true);
      fit.removeRotationRest('rest-1');
      expect(fit.rotationIds, [a.id, b.id, 'rest-2']);
      expect(plan(3), ['A', 'B', 'rest']);
    });

    test('removing a routine does not add a rest step', () {
      final a = routine('A'), b = routine('B');
      fit.setRotation(true);
      fit.toggleRotationRoutine(a.id, rest: true);
      fit.toggleRotationRoutine(b.id, rest: true);
      fit.toggleRotationRoutine(b.id, rest: true);
      expect(fit.rotationIds, [a.id, 'rest-1', 'rest-2']);
    });

    test('existing rotations and saved data are not changed', () {
      final a = routine('A'), b = routine('B');
      cycle([a, b]);
      fit.persistNow();
      fit.rotationIds.clear();
      fit.loadFromStore();
      expect(fit.rotationIds, [a.id, b.id]);
      fit.setRotation(false);
      fit.setRotation(true);
      expect(fit.rotationIds, [a.id, b.id]);
    });
  });

  group('readers follow the projection', () {
    DateTime real(int offset) {
      final n = DateTime.now();
      return DateTime(n.year, n.month, n.day + offset, 10);
    }

    test('routinesOn and rotationRestOn walk the whole step list', () {
      final a = routine('A'), b = routine('B');
      cycle([a, 'rest', b, 'rest']);
      train(a, real(0));
      expect(fit.routinesOn(real(0)).single.id, a.id);
      expect(fit.rotationRestOn(real(1)), isTrue);
      expect(fit.routinesOn(real(2)).single.id, b.id);
      expect(fit.rotationRestOn(real(3)), isTrue);
      expect(fit.routinesOn(real(4)).single.id, a.id);
      expect(fit.routineOn(real(3)), isNull);
    });

    test('the default today is the real date', () {
      final a = routine('A'), b = routine('B');
      cycle([a, 'rest', b, 'rest']);
      train(a, real(-1));
      expect(fit.restingToday, isTrue);
      expect(fit.todayRoutine, isNull);
      expect(fit.rotationUpcoming?.id, b.id);
      final days = fit.rotationProjection(real(0), real(2));
      expect([for (final d in days) d.routine?.name ?? (d.rest ? 'rest' : '-')], ['rest', 'B', 'rest']);
    });

    List<String> realPlan(int days) => [
          for (final d in fit.rotationProjection(real(0), real(days - 1)))
            d.routine?.name ?? (d.rest ? 'rest' : '-'),
        ];

    test('editing the rotation while a rest step is pending keeps the rest today', () {
      final a = routine('A'), b = routine('B'), c = routine('C');
      final ids = cycle([a, 'rest', b, 'rest']);
      train(a, real(-1));
      fit.toggleRotationRoutine(c.id, rest: true);
      expect(realPlan(6), ['rest', 'B', 'rest', 'C', 'rest', 'A']);
      fit.reorderRotation(4, 0);
      expect(fit.rotationIds, [c.id, a.id, ids[1], b.id, ids[3], 'rest-3']);
      expect(fit.restingToday, isTrue);
      expect(realPlan(3), ['rest', 'B', 'rest']);
      fit.removeRotationRest(ids[1]);
      expect(fit.restingToday, isFalse);
      expect(fit.todayRoutine?.id, b.id);
      expect(realPlan(3), ['B', 'rest', 'rest']);
    });

    test('a workout trained on a rest day continues from that routine', () {
      final a = routine('A'), b = routine('B');
      cycle([a, 'rest', b, 'rest']);
      train(a, real(-1));
      train(b, real(0));
      expect(realPlan(4), ['B', 'rest', 'A', 'rest']);
    });

    test('weekly-plan mode gives the same days as before', () {
      final a = routine('A'), b = routine('B');
      fit.assignRoutineToDay(DateTime.monday, a.id);
      fit.assignRoutineToDay(DateTime.thursday, b.id);
      for (var i = -3; i < 14; i++) {
        final d = real(i);
        final want = d.weekday == DateTime.monday
            ? [a.id]
            : d.weekday == DateTime.thursday
                ? [b.id]
                : <String>[];
        expect(fit.routinesOn(d).map((r) => r.id), want);
        if (i >= 0) expect(fit.restOn(d), want.isEmpty);
      }
    });
  });
}
