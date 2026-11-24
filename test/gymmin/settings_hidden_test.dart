import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/gymmin.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/screens/settings_screen.dart';
import 'package:gymmane/services/health_steps.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/services/nfc_tags.dart';
import 'package:gymmane/services/watch_link.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:gymmane/widgets/gym_pass_card.dart';
import 'package:gymmane/widgets/home_widget_views.dart';
import 'package:gymmane/widgets/home_cards_panel.dart';
import 'package:gymmane/widgets/medal.dart';
import 'package:gymmane/widgets/profile_avatar.dart';
import 'package:gymmane/widgets/quick_tiles_sheet.dart';
import 'package:gymmane/widgets/settings_showcase.dart';
import 'package:gymmane/widgets/widget_showcase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'switches.dart';

List<String> hiddenRows() => [
      t.languageLabel,
      t.nfcRow,
      t.miniBodySetting,
      t.homeRecommended,
      health(t.stepsSetting),
      t.healthSetting,
      t.gamificationSetting,
      t.gymPass,
      t.addBodyWidget,
      t.nutritionBeta,
      t.recoveryTitle,
      t.reportTitle,
      t.watchRow,
    ];

List<String> keptRows() => [
      t.theme,
      t.unitsLabel,
      t.background,
      t.restTimer,
      t.effortSetting,
      t.weightStepSetting,
      t.autoProgressSetting,
      t.voiceSetting,
      t.checkInSetting,
      t.tuneSetting,
      t.levelHintsSetting,
      t.multiPlanSetting,
      t.placesLabel,
      t.trainReminder,
      t.alarmSound,
      t.focusCard,
      t.homeRoutines,
      t.homeWeekStats,
      t.exportCsv,
      t.exportBackup,
      t.importBackup,
      t.autoBackup,
      t.importFromApp,
      t.stravaRow,
      t.aboutGymmane,
    ];

Future<void> pumpPage(WidgetTester tester, Widget child, {Size size = const Size(600, 4000)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final report = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!details.exceptionAsString().contains('overflowed')) report?.call(details);
  };
  addTearDown(() => FlutterError.onError = report);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: AnimatedBuilder(animation: fit, builder: (_, _) => Scaffold(body: child)),
  ));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

final emptyCard = find.byWidgetPredicate((w) => w is Container && w.child is Column && (w.child as Column).children.isEmpty);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  switchesOffInEachTest();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    setAppLanguage('en');
    NfcTags.available = true;
    WatchLink.instance.available = true;
    fit.stepsAccess = HealthAccess.granted;
  });

  tearDown(() {
    NfcTags.available = false;
    WatchLink.instance.available = false;
    fit.stepsAccess = HealthAccess.unsupported;
  });

  group('settings categories and search index', () {
    test('hidden rows are absent with switches off', () {
      final labels = const SettingsScreen().searchRows.map((r) => r.$2).toSet();
      for (final label in hiddenRows()) {
        expect(labels, isNot(contains(label)), reason: label);
      }
      expect(const SettingsScreen().searchRows.map((r) => r.$1), isNot(contains('beta')));
    });

    test('kept rows are present with switches off', () {
      final labels = const SettingsScreen().searchRows.map((r) => r.$2).toSet();
      for (final label in keptRows()) {
        expect(labels, contains(label), reason: label);
      }
    });

    test('hidden rows come back with switches on', () {
      GymMin.setAll(true);
      final labels = const SettingsScreen().searchRows.map((r) => r.$2).toSet();
      for (final label in hiddenRows().where((l) => l != t.addBodyWidget)) {
        expect(labels, contains(label), reason: label);
      }
    });
  });

  group('settings pages', () {
    for (final id in ['general', 'training', 'alerts', 'home', 'widgets', 'data', 'support']) {
      testWidgets('$id opens with no hidden row and no empty card', (tester) async {
        await pumpPage(tester, SettingsScreen(section: id));
        expect(tester.takeException(), isNull);
        for (final label in [...hiddenRows(), t.homeCardSteps, t.homeCardRecommended]) {
          expect(find.text(label), findsNothing, reason: '$id: $label');
        }
        expect(emptyCard, findsNothing, reason: id);
      });
    }

    testWidgets('kept rows show on their pages', (tester) async {
      await pumpPage(tester, const SettingsScreen(section: 'training'));
      for (final label in [t.tuneSetting, t.levelHintsSetting, t.voiceSetting, t.checkInSetting, t.autoProgressSetting]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await pumpPage(tester, const SettingsScreen(section: 'widgets'));
      for (final label in [t.addActivityWidget, t.addStatsWidget, t.addTodayWidget, t.addWeekWidget]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text(t.widgetHintBody), findsNothing);
      expect(find.text(t.widgetHintWeek), findsOneWidget);
      await pumpPage(tester, const SettingsScreen(section: 'data'));
      for (final label in [t.exportCsv, t.exportBackup, t.importBackup, t.stravaRow, t.resetData]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('hidden rows show on their pages with switches on', (tester) async {
      GymMin.setAll(true);
      await pumpPage(tester, const SettingsScreen(section: 'home'));
      for (final label in [t.healthSetting, t.gamificationSetting, t.gymPass, t.homeCardSteps, t.homeCardRecommended]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      await pumpPage(tester, const SettingsScreen(section: 'data'));
      expect(find.text(t.reportTitle), findsOneWidget);
      expect(find.text(t.watchRow), findsOneWidget);
    });
  });

  group('sheets', () {
    testWidgets('the background sheet offers no photo', (tester) async {
      await pumpPage(tester, const SettingsScreen(section: 'general'));
      await tester.tap(find.text(t.background));
      await tester.pumpAndSettle();
      expect(find.text(t.bgDots), findsWidgets);
      expect(find.text(t.bgPhotoPick), findsNothing);
      expect(find.text(t.bgPhotoHint), findsNothing);
    });

    testWidgets('the profile sheet has no photo, cover or activity level', (tester) async {
      await pumpPage(tester, Builder(
        builder: (context) => TextButton(onPressed: () => showProfileSheet(context), child: const Text('open')),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(t.nameLabel.toUpperCase()), findsOneWidget);
      expect(find.byType(ProfileAvatar), findsNothing);
      expect(find.text(t.activityLabel.toUpperCase()), findsNothing);
    });

    testWidgets('the quick settings sheet has no gym pass tile', (tester) async {
      await pumpPage(tester, Builder(
        builder: (context) => TextButton(onPressed: () => showQuickTilesSheet(context), child: const Text('open')),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(t.qsToday), findsOneWidget);
      expect(find.text(t.qsPass), findsNothing);
    });

    testWidgets('the home order sheet does not list Suggested', (tester) async {
      await pumpPage(tester, HomeCardsPanel(onSteps: () {}));
      await tester.tap(find.text(t.homeOrderRow));
      await tester.pumpAndSettle();
      expect(find.text(t.homeCardRoutines), findsWidgets);
      expect(find.text(t.homeCardRecommended), findsNothing);
    });
  });

  group('showcases', () {
    testWidgets('the alerts showcase has no photo, measurement, food or steps tile', (tester) async {
      await pumpPage(tester, const AlertsShowcase(), size: const Size(1000, 1000));
      expect(find.text(t.restOverTitle), findsOneWidget);
      for (final label in [t.notifPhotoTitle, t.notifMeasureTitle, t.suppCreatine, '6 240', '2 L', '5 g']) {
        expect(find.text(label), findsNothing, reason: label);
      }
    });

    testWidgets('the home extras showcase has no medal, pass, steps or health tile', (tester) async {
      await pumpPage(tester, const HomeExtrasShowcase(), size: const Size(1000, 1000));
      expect(find.text(t.streakCaps), findsWidgets);
      expect(find.byType(Medal), findsNothing);
      expect(find.byType(GymPassCard), findsNothing);
      for (final label in [t.homeCardSteps, t.healthRestingHr, t.healthBpm, 'kcal', '2,1 L']) {
        expect(find.text(label), findsNothing, reason: label);
      }
    });

    testWidgets('the widgets showcase has no muscle map or food widget', (tester) async {
      await pumpPage(tester, const WidgetShowcase(), size: const Size(1000, 1000));
      expect(find.byType(HeatmapWidgetView), findsOneWidget);
      expect(find.byType(BodyWidgetView), findsNothing);
      expect(find.byType(KcalWidgetView), findsNothing);
      expect(find.text(t.waterLabel), findsNothing);
      expect(find.text(t.macroProtein), findsNothing);
    });
  });
}
