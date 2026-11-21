import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final appId = RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle)!.group(1)!;

  test('the fork installs beside upstream GymMane', () {
    expect(appId, isNot('com.gymmane.app'));
  });

  test('the application ID is one Android accepts', () {
    expect(appId, matches(RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$')));
  });

  test('every launcher icon is labelled GymMin', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final labels = RegExp(r'android:label="([^"@][^"]*)"').allMatches(manifest).map((m) => m.group(1));
    expect(labels, isNotEmpty);
    expect(labels, everyElement('GymMin'));
  });

  test('the launcher shortcut opens this app', () {
    final shortcuts = File('android/app/src/main/res/xml/shortcuts.xml').readAsStringSync();
    final targets = RegExp(r'android:targetPackage="([^"]+)"').allMatches(shortcuts).map((m) => m.group(1));
    expect(targets, isNotEmpty);
    expect(targets, everyElement(appId));
  });
}
