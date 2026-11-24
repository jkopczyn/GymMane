import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/gymmin.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/health_metrics.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/widgets/health_cards.dart';
import 'package:gymmane/widgets/muscle_radar.dart';
import 'package:gymmane/widgets/ui_kit.dart' show sentenceCase;
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

  Finder labelled(String label) =>
      find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label);

  LoggedExercise lift(String id, double kg) {
    final ex = fit.exerciseById(id)!;
    return LoggedExercise(ex.id, ex.name, ex.primary, [LoggedSet(5, kg), LoggedSet(5, kg)]);
  }

  void logMonth() {
    final now = DateTime.now();
    final arm = fit.allExercises.firstWhere((e) => e.primary == 'biceps');
    for (final back in [25, 20]) {
      fit.sessions.add(LoggedSession(now.subtract(Duration(days: back)), 1800, [
        LoggedExercise(arm.id, arm.name, arm.primary, [LoggedSet(10, 12)]),
      ]));
    }
    for (var back = 28; back >= 1; back -= 3) {
      fit.sessions.add(LoggedSession(now.subtract(Duration(days: back)), 3600, [
        lift('qXTaZnJ', 100 + (28 - back).toDouble()),
        lift('ila4NZS', 60),
        lift('EIeI8Vf', 70),
      ]));
    }
    fit.sessions.sort((a, b) => a.day.compareTo(b.day));
  }

  Future<void> openProgress(WidgetTester tester) async {
    fit.route = 'progress';
    await tester.pumpWidget(const GymManeApp());
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('a brand-new user sees no muscle map, measurement, photo or share entry', (tester) async {
    await openProgress(tester);

    expect(find.text(t.setupTitle), findsOneWidget);
    expect(find.text(t.setupWorkout), findsOneWidget);
    expect(find.text(t.setupWeight), findsOneWidget);
    expect(find.text(t.setupMeasures), findsNothing);
    expect(find.text(t.setupPhoto), findsNothing);
    expect(find.text(t.muscleMap), findsNothing);
    expect(find.byType(MuscleRadarCard), findsNothing);
    expect(find.text(sentenceCase(t.share)), findsNothing);
    expect(labelled(t.share), findsNothing);
    expect(find.text(t.weightLabel.toUpperCase()), findsOneWidget);
    expect(find.text(t.tileAddWeight), findsOneWidget);
  });

  testWidgets('the workout setup step opens the exercise picker, not the body map', (tester) async {
    await openProgress(tester);

    await tester.tap(find.text(t.setupWorkout));
    await tester.pump();
    expect(fit.route, 'train');
    expect(fit.trainStep, 'review');
  });

  testWidgets('a month of sessions shows strength and records but no muscle, balance or share', (tester) async {
    logMonth();
    final muscleNote = fit.weekInsights.where((n) => n.kind == 'muscle').toList();
    expect(muscleNote, isNotEmpty, reason: 'the data must produce a "not trained" note to hide');
    expect(fit.structuralBalance, isNotNull, reason: 'the data must produce a Balance card to hide');
    await openProgress(tester);

    expect(find.text(t.strength1rm), findsOneWidget);
    expect(find.text(t.thisWeekTitle.toUpperCase()), findsOneWidget);
    expect(find.text(t.weightLabel.toUpperCase()), findsOneWidget);
    expect(labelled(sentenceCase(t.historyTitle)), findsOneWidget);

    expect(find.text(t.muscleMap), findsNothing);
    expect(find.byType(MuscleRadarCard), findsNothing);
    expect(find.text(t.balanceTitle.toUpperCase()), findsNothing);
    expect(find.text(muscleNote.first.text), findsNothing);
    expect(labelled(t.reportTitle), findsNothing);
    expect(labelled(t.share), findsNothing);
    expect(find.text(t.setupMeasures), findsNothing);
    expect(find.text(t.setupPhoto), findsNothing);
    expect(find.text(t.setupWeight), findsOneWidget, reason: 'body weight is the only step still missing');
  });

  testWidgets('with the switches on, the same month shows the hidden cards', (tester) async {
    GymMin.setAll(true);
    logMonth();
    final muscleNote = fit.weekInsights.where((n) => n.kind == 'muscle').toList();
    await openProgress(tester);

    expect(find.text(t.muscleMap), findsOneWidget);
    expect(find.byType(MuscleRadarCard), findsOneWidget);
    expect(find.text(t.balanceTitle.toUpperCase()), findsOneWidget);
    expect(find.text(muscleNote.first.text), findsOneWidget);
    expect(labelled(t.reportTitle), findsOneWidget);
    expect(labelled(t.share), findsOneWidget);
  });

  testWidgets('once body weight is logged, no setup card is left over', (tester) async {
    logMonth();
    fit.addBodyweight(80);
    await openProgress(tester);

    expect(find.text(t.setupTitle), findsNothing);
  });

  testWidgets('health data does not bring back the health card', (tester) async {
    logMonth();
    fit.healthShown.add(HealthMetric.restingHr);
    await openProgress(tester);

    expect(find.byType(HealthCard), findsNothing);
  });
}
