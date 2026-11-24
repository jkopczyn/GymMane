import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/desktop.dart';
import 'package:gymmane/gymmin.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/exercise.dart';
import 'package:gymmane/screens/exercise_detail_screen.dart';
import 'package:gymmane/screens/exercises_screen.dart';
import 'package:gymmane/screens/help_topics.dart';
import 'package:gymmane/screens/tool_detail_screen.dart';
import 'package:gymmane/screens/tools_screen.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/services/nfc_tags.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:gymmane/widgets/body_map.dart';
import 'package:gymmane/widgets/ui_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'switches.dart';

const _hidden = ['bmi', 'bf', 'ffmi', 'cal', 'protein', 'water'];
const _kept = ['rm', 'plate', 'warmup', 'rpe', 'dots', 'wilks'];

Widget _host(Widget Function() screen, {bool wide = false}) => MaterialApp(
      theme: AppTheme.dark,
      home: DesktopScope(
        wide: wide,
        child: AnimatedBuilder(
          animation: fit,
          builder: (_, _) => Scaffold(body: screen()),
        ),
      ),
    );

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

  group('Tools', () {
    testWidgets('the phone grid shows only the strength tools', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_host(ToolsScreen.new));
      await tester.pumpAndSettle();
      for (final id in _kept) {
        expect(find.text(t.toolName(id)), findsOneWidget, reason: id);
      }
      for (final id in _hidden) {
        expect(find.text(t.toolName(id)), findsNothing, reason: id);
      }
      expect(find.text(t.calculatorsCount(_kept.length)), findsOneWidget);
    });

    testWidgets('each kept tool opens from the grid', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final id in _kept) {
        fit.route = 'tools';
        await tester.pumpWidget(_host(ToolsScreen.new));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.toolName(id)));
        await tester.pump();
        expect(fit.route, 'tools-detail', reason: id);
        expect(fit.activeToolId, id);
        await tester.pumpWidget(_host(ToolDetailScreen.new));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(t.toolTitle(id)), findsWidgets, reason: id);
      }
    });

    testWidgets('the desktop list leaves out the body and nutrition groups', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      fit.activeToolId = 'bmi';
      await tester.pumpWidget(_host(ToolsScreen.new, wide: true));
      await tester.pumpAndSettle();
      expect(find.text(t.kindStrength), findsOneWidget);
      expect(find.text(t.toolGroupBody), findsNothing);
      expect(find.text(t.nutrition), findsNothing);
      for (final id in _hidden) {
        expect(find.text(t.toolName(id)), findsNothing, reason: id);
      }
      expect(fit.activeToolId, 'rm');
    });

    testWidgets('a hidden tool id does not open its calculator', (tester) async {
      for (final id in _hidden) {
        fit.openTool(id);
        await tester.pumpWidget(_host(ToolDetailScreen.new));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(t.toolTitle(id)), findsNothing, reason: id);
        expect(find.text(t.toolTitle('rm')), findsOneWidget, reason: id);
      }
    });

    testWidgets('with the switches on every tool is listed', (tester) async {
      GymMin.bodyComposition = true;
      GymMin.nutrition = true;
      await tester.binding.setSurfaceSize(const Size(400, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_host(ToolsScreen.new));
      await tester.pumpAndSettle();
      for (final id in [..._kept, ..._hidden]) {
        expect(find.text(t.toolName(id)), findsOneWidget, reason: id);
      }
    });
  });

  group('Help', () {
    test('no topic for a hidden feature is offered', () {
      NfcTags.available = true;
      addTearDown(() => NfcTags.available = false);
      final ids = helpTopics().map((h) => h.id).toSet();
      for (final id in ['pass', 'nfc', 'steps', 'clean', 'fast']) {
        expect(ids, isNot(contains(id)), reason: id);
      }
      for (final id in ['superset', 'range', 'dayOff', 'lb', 'import', 'phone', 'slow', 'rest', 'sides', 'pair',
          'keep', 'race', 'plates', 'homeOrder', 'custom', 'warmup']) {
        expect(ids, contains(id), reason: id);
      }
    });

    test('the gym pass and NFC topics come back with their switches', () {
      NfcTags.available = true;
      addTearDown(() => NfcTags.available = false);
      GymMin.gymPass = true;
      GymMin.nfc = true;
      final ids = helpTopics().map((h) => h.id).toSet();
      expect(ids, containsAll(['pass', 'nfc']));
    });
  });

  group('Exercise detail', () {
    testWidgets('offers no way to attach an own photo or video', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      fit.openExercise(fit.allExercises.first.id);
      await tester.pumpWidget(_host(() => const ExerciseDetailScreen()));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(t.addMedia), findsNothing);
      expect(find.text(t.primaryLabel), findsWidgets);
    });

    testWidgets('the attach button returns with the photos switch', (tester) async {
      GymMin.photos = true;
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      fit.openExercise(fit.allExercises.first.id);
      await tester.pumpWidget(_host(() => const ExerciseDetailScreen()));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(t.addMedia), findsOneWidget);
    });

    testWidgets('the new exercise sheet has no media picker', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_host(() => Builder(
            builder: (context) => TextButton(
              onPressed: () => showCreateExerciseSheet(context),
              child: const Text('open'),
            ),
          )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final advanced = find.text(titleCase(t.advanced));
      await tester.ensureVisible(advanced);
      await tester.tap(advanced);
      await tester.pumpAndSettle();
      expect(find.text(t.aliasesLabel.toUpperCase()), findsOneWidget);
      expect(find.text(t.demoMedia.toUpperCase()), findsNothing);
      expect(find.text(t.addMedia), findsNothing);
    });

    testWidgets('the muscle filter sheet lists muscles without the body drawing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_host(() => Builder(
            builder: (context) => TextButton(
              onPressed: () => showBodyZones(context),
              child: const Text('open'),
            ),
          )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BodyZoneArt), findsNothing);
      expect(find.text(muscleLabel(fit.allExercises.first.primary)), findsWidgets);
    });

    testWidgets('the body drawing returns with the muscle map switch', (tester) async {
      GymMin.muscleMap = true;
      await tester.binding.setSurfaceSize(const Size(400, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_host(() => Builder(
            builder: (context) => TextButton(
              onPressed: () => showBodyZones(context),
              child: const Text('open'),
            ),
          )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BodyZoneArt), findsWidgets);
    });
  });
}
