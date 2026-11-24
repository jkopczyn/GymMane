import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/gymmin.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'switches.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  switchesOffInEachTest();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    setAppLanguage('en');
    fit.language = 'en';
  });

  void expectEnglish() {
    expect(fit.language, 'en');
    expect(fit.locale, const Locale('en'));
    expect(appLanguage, 'en');
    expect(Intl.defaultLocale, 'en');
    expect(t.localeName, 'en');
  }

  Map<String, dynamic> savedInSpanish() {
    GymMin.languages = true;
    fit.setLanguage('es');
    final saved = jsonDecode(jsonEncode(fit.toJson())) as Map<String, dynamic>;
    GymMin.languages = false;
    expect(saved['language'], 'es');
    return saved;
  }

  test('a fresh install is in English', () {
    fit.loadFromStore();
    expectEnglish();
  });

  test('the language setter leaves the app in English', () {
    fit.setLanguage('es');
    expectEnglish();
    fit.setLanguage('zh-TW');
    expectEnglish();
  });

  test('a saved state in Spanish loads in English', () async {
    await Store.instance.save(savedInSpanish());
    fit.loadFromStore();
    expectEnglish();
  });

  test('an imported backup in Spanish leaves the app in English', () {
    final backup = savedInSpanish();
    fit.applyBackup(backup);
    expectEnglish();
  });

  test('the next save stores English', () async {
    await Store.instance.save(savedInSpanish());
    fit.loadFromStore();
    expect(fit.toJson()['language'], 'en');
  });

  test('with languages on, Spanish is applied as before', () {
    GymMin.languages = true;
    fit.setLanguage('es');
    expect(fit.language, 'es');
    expect(fit.locale, const Locale('es'));
    expect(appLanguage, 'es');
    setAppLanguage('en');
  });
}
