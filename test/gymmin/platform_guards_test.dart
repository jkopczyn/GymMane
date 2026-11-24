import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/gymmin.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/health_metrics.dart';
import 'package:gymmane/services/health_steps.dart';
import 'package:gymmane/services/host.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/services/nfc_tags.dart';
import 'package:gymmane/services/watch_link.dart';
import 'package:gymmane/services/watch_phone.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'switches.dart';

final calls = <String>[];

Object? _reply(MethodCall call) => switch (call.method) {
      'status' => 'granted',
      'request' || 'requestMetrics' || 'writeWorkout' || 'deleteWorkout' || 'openSettings' || 'takeUsage' => true,
      'readSteps' => [for (final _ in (call.arguments as Map)['ranges'] as List) 1000],
      'metricsGranted' => ['steps', 'weight', 'workoutHr', 'writeWorkouts', 'sleep'],
      'readMetric' => <Object?>[],
      'state' => {'available': false, 'enabled': false},
      _ => null,
    };

void _mock(String channel) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    MethodChannel(channel),
    (call) async {
      calls.add('$channel ${call.method}');
      return _reply(call);
    },
  );
}

Future<void> _useHealthServices() async {
  await HealthSteps.takeUsage();
  await HealthSteps.access();
  await HealthSteps.request();
  await HealthSteps.openSettings();
  await HealthSteps.read([DateTime(2026, 11, 20)]);
  await HealthMetrics.granted();
  await HealthMetrics.request([HealthMetric.sleep]);
  await HealthMetrics.grantedKeys();
  await HealthMetrics.requestKeys(['weight']);
  await HealthMetrics.writeWorkout(
      id: 'x', start: DateTime(2026, 11, 20, 8), end: DateTime(2026, 11, 20, 9), type: 'strength', title: 'A');
  await HealthMetrics.deleteWorkout('x');
  await HealthMetrics.read(HealthMetric.sleep, DateTime(2026, 11, 19), DateTime(2026, 11, 20));
  await HealthMetrics.readKey('weight', DateTime(2026, 11, 19), DateTime(2026, 11, 20));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  switchesOffInEachTest();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    calls.clear();
    debugOnAndroid = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    for (final c in ['gymmane/health', 'gymmane/nfc', 'gymmane/watchlink']) {
      _mock(c);
    }
  });

  tearDown(() {
    debugOnAndroid = null;
    debugDefaultTargetPlatformOverride = null;
    WatchLink.instance
      ..outgoing = null
      ..onRequest = null
      ..onReply = null
      ..onResumed = null;
  });

  group('health services', () {
    test('make no platform call with steps and Health Connect off', () async {
      await _useHealthServices();
      expect(calls, isEmpty);
    });

    test('call the platform as before with both switches on', () async {
      GymMin.steps = GymMin.healthConnect = true;
      await _useHealthServices();
      expect(calls, hasLength(13));
    });

    test('steps calls follow the steps switch', () async {
      GymMin.steps = true;
      await HealthSteps.access();
      await HealthMetrics.grantedKeys();
      expect(calls, ['gymmane/health status']);
    });

    test('Health Connect calls follow the Health Connect switch', () async {
      GymMin.healthConnect = true;
      await HealthSteps.access();
      await HealthMetrics.grantedKeys();
      expect(calls, ['gymmane/health metricsGranted']);
    });
  });

  test('state restored with every health option on makes no platform call', () async {
    final session = LoggedSession(DateTime.now().subtract(const Duration(hours: 1)), 1800, []);
    fit.sessions.add(session);
    fit
      ..hcWrite = true
      ..hcWeights = true
      ..hcHeart = true
      ..healthShown.add(HealthMetric.sleep);
    await fit.refreshSteps();
    await fit.refreshHealth();
    await fit.setStepsOn(true);
    await fit.askStepsAccess();
    fit.healthSave(session);
    fit.healthForget(session);
    await fit.setHcWrite(true);
    await fit.setHcWeights(true);
    await fit.setHealthMetric(HealthMetric.restingHr, true);
    await fit.allowAllHealth();
    await pumpEventQueue();
    expect(calls, isEmpty);
  });

  group('NFC', () {
    test('load and state make no platform call with NFC off', () async {
      await NfcTags.load();
      final s = await NfcTags.state();
      expect(calls, isEmpty);
      expect(NfcTags.available, isFalse);
      expect(s.available, isFalse);
    });

    test('load asks the platform as before with NFC on', () async {
      GymMin.nfc = true;
      await NfcTags.load();
      expect(calls, ['gymmane/nfc state']);
    });
  });

  group('watch link', () {
    test('init does not start the link with the watch switch off', () async {
      await WatchPhone.init();
      expect(WatchLink.instance.outgoing, isNull);
      expect(calls, isEmpty);
    });

    test('init sets up the link as before with the watch switch on', () async {
      GymMin.watch = true;
      await WatchPhone.init();
      expect(WatchLink.instance.outgoing, isNotNull);
    });
  });
}
