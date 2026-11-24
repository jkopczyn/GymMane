import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/gymmin.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/workout.dart';
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

  testWidgets('a new best lift shows on the finish screen with medals off', (tester) async {
    expect(GymMin.medals, isFalse);
    final id = fit.allExercises.firstWhere((e) => e.primary == 'chest').id;
    fit.sessions.add(LoggedSession(DateTime.now().subtract(const Duration(days: 3)), 600,
        [LoggedExercise(id, 'X', 'chest', [LoggedSet(5, 60)])]));
    fit.startWorkout();
    fit.toggleMuscle('chest');
    fit.trainContinue();
    fit.startSession();
    fit.setSessionWeight(0, 0, 80);
    fit.setSessionReps(0, 0, 5);
    fit.toggleSet(0, 0);
    fit.finishSession();
    expect(fit.summaryPrs, 1);

    fit.route = 'session';
    await tester.pumpWidget(const GymManeApp());
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(t.reportRecords.toUpperCase()), findsOneWidget);
    fit.saveAndExit();
  });
}
