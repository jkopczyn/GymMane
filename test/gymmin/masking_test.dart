import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/gymmin.dart';
import 'package:gymmane/models/progress_shot.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'switches.dart';

typedef Masked = ({bool Function() read, void Function(bool) write, void Function(bool) turn});

final Map<String, Masked> masked = {
  'nutritionBeta': (read: () => fit.nutritionBeta, write: (v) => fit.nutritionBeta = v, turn: (on) => GymMin.nutrition = on),
  'recoveryOn': (read: () => fit.recoveryOn, write: (v) => fit.recoveryOn = v, turn: (on) => GymMin.recovery = on),
  'passOn': (read: () => fit.passOn, write: (v) => fit.passOn = v, turn: (on) => GymMin.gymPass = on),
  'showMiniBody': (read: () => fit.showMiniBody, write: (v) => fit.showMiniBody = v, turn: (on) => GymMin.muscleMap = on),
  'showRecommended': (
    read: () => fit.showRecommended,
    write: (v) => fit.showRecommended = v,
    turn: (on) => GymMin.suggested = on
  ),
  'gamification': (read: () => fit.gamification, write: (v) => fit.gamification = v, turn: (on) => GymMin.medals = on),
  'stepsOn': (read: () => fit.stepsOn, write: (v) => fit.stepsOn = v, turn: (on) => GymMin.steps = on),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  switchesOffInEachTest();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
  });

  Map<String, dynamic> savedWithEverythingOn() {
    GymMin.setAll(true);
    for (final m in masked.values) {
      m.write(true);
    }
    final saved = jsonDecode(jsonEncode(fit.toJson())) as Map<String, dynamic>;
    GymMin.setAll(false);
    return saved;
  }

  for (final MapEntry(key: name, value: m) in masked.entries) {
    group(name, () {
      test('reads false with its switch off', () {
        expect(m.read(), isFalse);
      });

      test('stays false after its setter is called with true', () {
        m.write(true);
        expect(m.read(), isFalse);
      });

      test('stays false after loading a saved state that has it on', () async {
        final saved = savedWithEverythingOn();
        expect(saved, isNotEmpty);
        await Store.instance.save(saved);
        fit.loadFromStore();
        expect(m.read(), isFalse);
        fit.applyBackup(saved);
        expect(m.read(), isFalse);
      });

      test('works as before with its switch on', () {
        m.turn(true);
        m.write(true);
        expect(m.read(), isTrue);
        m.write(false);
        expect(m.read(), isFalse);
      });
    });
  }

  group('medal popups', () {
    test('nothing is celebrated with medals off', () {
      fit.pendingAwards.add(AwardId.firstStep);
      expect(fit.nextCelebration, isNull);
      GymMin.medals = true;
      fit.gamification = true;
      expect(fit.nextCelebration, AwardId.firstStep);
    });

    test('finishing onboarding queues no firstStep popup', () {
      fit.onboarded = true;
      fit.refreshAwards();
      expect(fit.pendingAwards, isEmpty);
      expect(fit.nextCelebration, isNull);
    });
  });

  group('photo-due prompt', () {
    setUp(() {
      fit.photoIntervalDays = 30;
      fit.shots.add(ProgressEntry(
          id: 'old', date: DateTime.now().subtract(const Duration(days: 60)), shots: const {'front': 'a.jpg'}));
    });

    test('is never due with photos off', () {
      expect(fit.photoDue, isFalse);
    });

    test('is due as before with photos on', () {
      GymMin.photos = true;
      expect(fit.photoDue, isTrue);
    });
  });
}
