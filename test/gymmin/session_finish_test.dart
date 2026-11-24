import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/gymmin.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/screens/session_photos.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/widgets/body_map.dart';
import 'package:gymmane/widgets/celebration.dart';
import 'package:gymmane/widgets/start_countdown.dart';
import 'package:gymmane/widgets/ui_kit.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'switches.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  switchesOffInEachTest();

  late String bench;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    setAppLanguage('en');
    bench = fit.allExercises.firstWhere((e) => e.primary == 'chest' && fit.modeOf(e.id).isEmpty).id;
    fit.sessions.add(LoggedSession(DateTime.now().subtract(const Duration(days: 3)), 600,
        [LoggedExercise(bench, 'X', 'chest', [LoggedSet(5, 60)])]));
    fit.refreshAwards(silent: true);
    fit.pendingAwards.clear();
  });

  void startBench() {
    final r = fit.createRoutine('Push');
    fit.toggleRoutineExercise(r, bench);
    fit.startRoutine(fit.routines.single);
  }

  void finishWithRecord() {
    startBench();
    fit.setSessionWeight(0, 0, 80);
    fit.setSessionReps(0, 0, 5);
    fit.toggleSet(0, 0);
    fit.finishSession();
    fit.route = 'session';
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const GymManeApp());
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> leave(WidgetTester tester) async {
    if (fit.session != null) fit.saveAndExit();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  }

  group('finish screen', () {
    testWidgets('hides share, sticker, session photos and confetti with switches off', (tester) async {
      finishWithRecord();
      await pumpApp(tester);
      expect(fit.isSessionComplete, isTrue);
      expect(find.text(t.reportRecords.toUpperCase()), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.shareNetwork), findsNothing);
      expect(find.text(t.stickerOpen), findsNothing);
      expect(find.byType(SessionPhotos), findsNothing);
      expect(find.byType(Confetti), findsNothing);
      expect(find.text(t.keepTraining), findsOneWidget);
      await leave(tester);
    });

    testWidgets('shows share and sticker with sharing on', (tester) async {
      GymMin.sharing = true;
      finishWithRecord();
      await pumpApp(tester);
      expect(find.byIcon(PhosphorIconsRegular.shareNetwork), findsOneWidget);
      expect(find.text(t.stickerOpen), findsOneWidget);
      expect(find.byType(SessionPhotos), findsNothing);
      await leave(tester);
    });

    testWidgets('shows session photos with photos on', (tester) async {
      GymMin.photos = true;
      finishWithRecord();
      await pumpApp(tester);
      expect(find.byType(SessionPhotos), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.shareNetwork), findsNothing);
      await leave(tester);
    });

    testWidgets('shows confetti with medals on', (tester) async {
      GymMin.medals = true;
      finishWithRecord();
      await pumpApp(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(Confetti), findsOneWidget);
      await leave(tester);
    });
  });

  group('live session', () {
    testWidgets('has no session muscle map with switches off', (tester) async {
      startBench();
      await pumpApp(tester);
      expect(fit.route, 'session');
      expect(find.byType(MiniBody), findsNothing);
      expect(find.bySemanticsLabel(t.sessionMuscles), findsNothing);
      await leave(tester);
    });

    testWidgets('has the session muscle map with the muscle map on', (tester) async {
      GymMin.muscleMap = true;
      startBench();
      await pumpApp(tester);
      expect(find.byType(MiniBody), findsOneWidget);
      await leave(tester);
    });
  });

  group('past workout view', () {
    LoggedSession withHeartRate() {
      final s = fit.sessions.single..hrAvg = 131;
      fit.resetRoute('history');
      fit.openWorkout(s);
      return s;
    }

    testWidgets('hides the Health Connect heart rate with switches off', (tester) async {
      withHeartRate();
      await pumpApp(tester);
      expect(fit.route, 'workout');
      expect(find.textContaining('131'), findsNothing);
      await leave(tester);
    });

    testWidgets('shows the heart rate with Health Connect on', (tester) async {
      GymMin.healthConnect = true;
      withHeartRate();
      await pumpApp(tester);
      expect(find.textContaining('131'), findsOneWidget);
      await leave(tester);
    });
  });

  testWidgets('a whole session from start to finish runs with switches off', (tester) async {
    expect(GymMin.medals || GymMin.sharing || GymMin.photos || GymMin.muscleMap, isFalse);
    startBench();
    await pumpApp(tester);
    expect(fit.route, 'session');
    final sets = fit.session!.exercises.single.sets.length;
    fit.endCountdown();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(StartCountdown), findsNothing);
    for (var j = 0; j < sets; j++) {
      fit.setSessionWeight(0, j, 80);
      fit.setSessionReps(0, j, 5);
      await tester.pump();
      final done = find.text(titleCase(t.setDone));
      await Scrollable.ensureVisible(tester.element(done), alignment: 0.5);
      await tester.pump();
      await tester.tap(done);
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(fit.session!.exercises.single.sets.every((s) => s.done), isTrue);
    final finish = find.text(titleCase(t.finishSession)).last;
    await Scrollable.ensureVisible(tester.element(finish), alignment: 0.5);
    await tester.pump();
    await tester.tap(finish);
    await tester.pump(const Duration(seconds: 2));
    expect(fit.isSessionComplete, isTrue);
    expect(find.text(t.reportRecords.toUpperCase()), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.shareNetwork), findsNothing);
    expect(find.text(t.stickerOpen), findsNothing);
    expect(find.byType(SessionPhotos), findsNothing);
    expect(find.byType(Confetti), findsNothing);
    await tester.tap(find.text(titleCase(t.done)));
    await tester.pump(const Duration(seconds: 2));
    expect(fit.session, isNull);
    expect(fit.sessions.length, 2);
    expect(tester.takeException(), isNull);
    await leave(tester);
  });
}
