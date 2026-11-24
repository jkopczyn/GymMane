import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/gymmin.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/screens/profile_screen.dart';
import 'package:gymmane/screens/recap_screen.dart';
import 'package:gymmane/services/health_metrics.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'switches.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  switchesOffInEachTest();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    setAppLanguage('en');
  });

  void logTwoMonths() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bench = fit.exerciseById('EIeI8Vf')!;
    final squat = fit.exerciseById('qXTaZnJ')!;
    final run = fit.allExercises.firstWhere((e) => fit.isCardio(e.id));
    for (var back = 55; back >= 0; back -= 2) {
      final day = today.subtract(Duration(days: back)).add(const Duration(hours: 18));
      fit.sessions.add(LoggedSession(day, 3600, [
        LoggedExercise(bench.id, bench.name, bench.primary, [LoggedSet(5, 60.0 + (55 - back)), LoggedSet(5, 60)]),
        LoggedExercise(squat.id, squat.name, squat.primary, [LoggedSet(5, 80.0 + (55 - back))]),
        LoggedExercise(run.id, run.name, run.primary, [LoggedSet(0, 0, km: 3, sec: 1200)]),
      ]));
    }
    fit.refreshAwards();
    fit.healthShown.add(HealthMetric.sleep);
    fit.healthByDay[HealthMetric.sleep] = {
      for (var back = 60; back >= 0; back--) HealthMetrics.dayKey(today.subtract(Duration(days: back))): [420.0],
    };
  }

  Future<Set<String>> pagesShown(WidgetTester tester) async {
    final report = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.exceptionAsString().contains('overflowed')) report!(details);
    };
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    fit.route = 'settings';
    await tester.pumpWidget(const GymManeApp());
    await tester.pump(const Duration(seconds: 1));
    openRecap(tester.element(find.byType(ProfileScreen)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RecapScreen), findsOneWidget);

    final kickers = {
      'workouts': t.recapWorkoutsKicker,
      'time': t.recapTimeKicker,
      'volume': t.recapVolumeKicker,
      'lift': t.recapLiftKicker,
      'muscle': t.recapMuscleKicker,
      'records': t.recapRecordsKicker,
      'medals': t.recapMedalsKicker,
      'cardio': t.recapCardioKicker,
      'steps': t.recapStepsKicker,
      'sleep': t.recapSleepKicker,
      'food': t.recapFoodKicker,
      'foodStar': t.recapFoodStarKicker,
      'habit': t.recapHabitKicker,
      'share': t.recapShareKicker,
    };
    final seen = <String>{};
    for (var i = 0; i < 20; i++) {
      for (final MapEntry(:key, :value) in kickers.entries) {
        if (find.text(value.toUpperCase()).evaluate().isNotEmpty) seen.add(key);
      }
      if (find.text(t.recapShare).evaluate().isNotEmpty) seen.add('shareButton');
      await tester.tapAt(const Offset(330, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }
    FlutterError.onError = report;
    return seen;
  }

  testWidgets('with the switches on, the same data shows the hidden pages', (tester) async {
    GymMin.setAll(true);
    fit.nutritionBeta = false;
    logTwoMonths();
    final extras = recapExtras(fit.recapFor(fit.recapMonth));
    expect(extras.medals, isNotEmpty);
    expect(extras.sleep, isNotNull);
    expect(fit.recapFor(fit.recapMonth).topMuscle, isNotNull);

    final seen = await pagesShown(tester);
    expect(seen, containsAll(['muscle', 'medals', 'sleep', 'share', 'shareButton']));
  });

  testWidgets('a month of sessions keeps the training pages and drops the hidden ones', (tester) async {
    logTwoMonths();

    final seen = await pagesShown(tester);
    expect(seen, containsAll(['workouts', 'time', 'volume', 'lift', 'records', 'cardio', 'habit']));
    for (final hidden in ['muscle', 'medals', 'steps', 'sleep', 'food', 'foodStar', 'share', 'shareButton']) {
      expect(seen, isNot(contains(hidden)), reason: '$hidden should be hidden');
    }
  });
}
