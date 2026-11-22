import 'dart:async';

import 'package:gymmane/gymmin.dart';

import 'gymmin/switches.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GymMin.setAll(suiteSwitches);
  await testMain();
}
