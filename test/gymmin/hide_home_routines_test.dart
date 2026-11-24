import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/gymmin.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/progress_shot.dart';
import 'package:gymmane/screens/home_screen.dart';
import 'package:gymmane/screens/routine_edit_screen.dart';
import 'package:gymmane/screens/routines_screen.dart';
import 'package:gymmane/screens/start_sheet.dart';
import 'package:gymmane/screens/train_screen.dart';
import 'package:gymmane/services/health_steps.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/widgets/body_map.dart';
import 'package:gymmane/widgets/steps_card.dart';
import 'package:gymmane/widgets/ui_kit.dart' show titleCase;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'switches.dart';

const _plan = '{"name":"Day A","exercises":[{"name":"Barbell Bench Press","sets":3,"reps":5}]}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  switchesOffInEachTest();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    fit.session = null;
    fit.resetRoute('home');
    setAppLanguage('en');
  });

  tearDown(() {
    fit.session = null;
    fit.resetRoute('home');
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, void Function() action) async {
    action();
    await tester.pumpAndSettle();
  }

  String routineWithExercises() {
    expect(fit.importPlan(_plan).readable, isTrue);
    return fit.activeRoutines.last.id;
  }

  void photoOverdue() {
    fit.photoIntervalDays = 30;
    fit.shots.add(ProgressEntry(
        id: 'old', date: DateTime.now().subtract(const Duration(days: 60)), shots: const {'front': 'a.jpg'}));
  }

  Finder inTrain(Finder f) => find.descendant(of: find.byType(TrainScreen), matching: f);

  group('Home', () {
    testWidgets('shows no Nutrition folder, Suggested card, steps card, mini body or photo card', (tester) async {
      routineWithExercises();
      fit.nutritionBeta = true;
      fit.showRecommended = true;
      fit.stepsOn = true;
      fit.showMiniBody = true;
      photoOverdue();
      await pumpApp(tester);
      fit.stepsAccess = HealthAccess.granted;
      fit.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text(titleCase(t.nutrition)), findsNothing);
      expect(find.text(titleCase(t.recommended)), findsNothing);
      expect(find.byType(StepsCard), findsNothing);
      expect(find.byType(MiniBody), findsNothing);
      expect(find.text(t.photoDueNow), findsNothing);
    });

    testWidgets('shows the Nutrition folder and Suggested card with their switches on', (tester) async {
      GymMin.nutrition = true;
      GymMin.suggested = true;
      fit.nutritionBeta = true;
      fit.showRecommended = true;
      await pumpApp(tester);
      expect(find.text(titleCase(t.nutrition)), findsOneWidget);
      expect(find.text(titleCase(t.recommended)), findsOneWidget);
    });

    testWidgets('shows the steps card, mini body and photo card with their switches on', (tester) async {
      GymMin.steps = true;
      GymMin.muscleMap = true;
      GymMin.photos = true;
      routineWithExercises();
      fit.stepsOn = true;
      fit.showMiniBody = true;
      photoOverdue();
      await pumpApp(tester);
      fit.stepsAccess = HealthAccess.granted;
      fit.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(StepsCard), findsOneWidget);
      expect(find.byType(MiniBody), findsWidgets);
      expect(find.text(t.photoDueNow), findsOneWidget);
    });

    testWidgets('the focus Start button opens the exercise picker', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text(titleCase(t.startWorkout)));
      await tester.pumpAndSettle();
      expect(fit.route, 'train');
      expect(fit.trainStep, 'review');
      expect(find.byType(BodyMap), findsNothing);
    });

    testWidgets('the focus Start button opens the body map with the muscle map on', (tester) async {
      GymMin.muscleMap = true;
      await pumpApp(tester);
      await tester.tap(find.text(titleCase(t.startWorkout)));
      await tester.pumpAndSettle();
      expect(fit.trainStep, 'select');
      expect(fit.selectedMuscles, fit.suggestedFocus.muscles);
      expect(find.byType(BodyMap), findsOneWidget);
    });
  });

  group('Start sheet', () {
    testWidgets('offers picking exercises and no focus choice', (tester) async {
      await pumpApp(tester);
      showStartSheet(tester.element(find.byType(HomeScreen)));
      await tester.pumpAndSettle();
      expect(find.text(t.chooseFocusOption), findsNothing);
      await tester.tap(find.text(t.pickExercisesOption));
      await tester.pumpAndSettle();
      expect(fit.route, 'train');
      expect(fit.trainStep, 'review');
    });

    testWidgets('offers the focus choice with the muscle map on', (tester) async {
      GymMin.muscleMap = true;
      await pumpApp(tester);
      showStartSheet(tester.element(find.byType(HomeScreen)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.chooseFocusOption));
      await tester.pumpAndSettle();
      expect(fit.trainStep, 'select');
      expect(find.byType(BodyMap), findsOneWidget);
    });
  });

  group('Train', () {
    testWidgets('a workout without a routine starts from the exercise picker', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text(titleCase(t.startWorkout)));
      await tester.pumpAndSettle();
      expect(find.text(t.goBackPick), findsNothing);
      await tester.enterText(inTrain(find.byType(TextField)), 'bench press');
      await tester.pumpAndSettle();
      await tester.tap(inTrain(find.text('Barbell Bench Press')).first);
      await tester.pumpAndSettle();
      expect(fit.sessionPicks, hasLength(1));
      await tester.tap(find.text(titleCase(t.startCount(1))));
      await tester.pumpAndSettle();
      expect(fit.session, isNotNull);
      expect(fit.session!.exercises, hasLength(1));
      fit.discardSession();
      await tester.pumpAndSettle();
    });

    testWidgets('the first step shows no body map and leads to the exercise picker', (tester) async {
      await pumpApp(tester);
      await go(tester, fit.startWorkout);
      expect(fit.trainStep, 'select');
      expect(find.byType(BodyMap), findsNothing);
      expect(inTrain(find.text(t.chooseFocus)), findsNothing);
      expect(inTrain(find.text(t.warmupFocus)), findsOneWidget);
      expect(inTrain(find.text(t.cardioFocus)), findsOneWidget);
      await tester.tap(inTrain(find.text(t.pickExercisesOption)));
      await tester.pumpAndSettle();
      expect(fit.trainStep, 'review');
      expect(fit.route, 'train');
      await go(tester, fit.closeTrain);
      expect(fit.route, 'home');
    });

    testWidgets('the first step keeps the body map with the muscle map on', (tester) async {
      GymMin.muscleMap = true;
      await pumpApp(tester);
      await go(tester, fit.startWorkout);
      expect(find.byType(BodyMap), findsOneWidget);
      expect(inTrain(find.text(t.chooseFocus)), findsOneWidget);
      expect(inTrain(find.text(t.pickExercisesOption)), findsNothing);
    });

    testWidgets('no "Suggested for you" label over the picks', (tester) async {
      await pumpApp(tester);
      await go(tester, fit.startWorkout);
      await tester.tap(inTrain(find.text(t.warmupFocus)));
      await tester.pumpAndSettle();
      expect(fit.pickSeed, isNotEmpty);
      expect(find.text(t.suggestedPicks.toUpperCase()), findsNothing);
      expect(find.text(t.moreOptions.toUpperCase()), findsNothing);
    });

    testWidgets('the "Suggested for you" label shows with its switch on', (tester) async {
      GymMin.suggested = true;
      await pumpApp(tester);
      await go(tester, fit.startWorkout);
      await go(tester, () => fit.startKindWorkout('warmup'));
      expect(find.text(t.suggestedPicks.toUpperCase()), findsOneWidget);
    });
  });

  group('Routines', () {
    testWidgets('shows no sharing and no "Routine with AI"', (tester) async {
      routineWithExercises();
      await pumpApp(tester);
      await go(tester, fit.goRoutines);
      expect(find.byType(RoutinesScreen), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.shareNetwork), findsNothing);
      expect(find.text(t.aiRoutine), findsNothing);
      expect(find.text(t.importRoutines), findsOneWidget);
    });

    testWidgets('shows sharing and "Routine with AI" with their switches on', (tester) async {
      GymMin.sharing = true;
      GymMin.aiRoutine = true;
      routineWithExercises();
      await pumpApp(tester);
      await go(tester, fit.goRoutines);
      expect(find.byIcon(PhosphorIconsRegular.shareNetwork), findsOneWidget);
      expect(find.text(t.aiRoutine), findsOneWidget);
    });

    testWidgets('the routine menu has no share or PDF entry', (tester) async {
      final id = routineWithExercises();
      await pumpApp(tester);
      showRoutineMenu(tester.element(find.byType(HomeScreen)), fit.routineById(id)!);
      await tester.pumpAndSettle();
      expect(find.text(t.duplicateRoutine), findsOneWidget);
      expect(find.text(t.shareRoutine), findsNothing);
      expect(find.text(t.pdfExport), findsNothing);
    });

    testWidgets('the routine menu has share and PDF entries with sharing on', (tester) async {
      GymMin.sharing = true;
      final id = routineWithExercises();
      await pumpApp(tester);
      showRoutineMenu(tester.element(find.byType(HomeScreen)), fit.routineById(id)!);
      await tester.pumpAndSettle();
      expect(find.text(t.shareRoutine), findsOneWidget);
      expect(find.text(t.pdfExport), findsOneWidget);
    });

    testWidgets('the routine editor has no share button', (tester) async {
      final id = routineWithExercises();
      await pumpApp(tester);
      await go(tester, () => fit.openRoutine(id));
      expect(find.byType(RoutineEditScreen), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.shareNetwork), findsNothing);
    });

    testWidgets('the routine editor has a share button with sharing on', (tester) async {
      GymMin.sharing = true;
      final id = routineWithExercises();
      await pumpApp(tester);
      await go(tester, () => fit.openRoutine(id));
      expect(find.byIcon(PhosphorIconsRegular.shareNetwork), findsOneWidget);
    });

    testWidgets('a routine file still imports', (tester) async {
      await pumpApp(tester);
      await go(tester, fit.goRoutines);
      final before = fit.activeRoutines.length;
      await tester.tap(find.text(t.importRoutines));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, _plan);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.addToMyRoutines));
      await tester.pumpAndSettle();
      expect(fit.activeRoutines.length, before + 1);
      expect(fit.activeRoutines.last.exerciseIds, isNotEmpty);
    });
  });
}
