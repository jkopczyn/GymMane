import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/gymmin.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/services/media_store.dart';
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
    MediaStore.directory = '/media';
    fit.exerciseMedia[kBgPhotoId] = 'bg.jpg';
  });

  tearDown(() => MediaStore.directory = null);

  test('a stored background photo is not shown with photos off', () {
    expect(fit.bgPhotoPath, isNull);
  });

  test('a stored background photo is shown as before with photos on', () {
    GymMin.photos = true;
    expect(fit.bgPhotoPath, '/media/bg.jpg');
  });
}
