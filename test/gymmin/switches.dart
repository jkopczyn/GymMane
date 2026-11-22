import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/gymmin.dart';

const suiteSwitches = !bool.fromEnvironment('GYMMIN_OFF');

void switchesOffInEachTest() {
  setUp(() => GymMin.setAll(false));
  tearDown(() => GymMin.setAll(suiteSwitches));
}
