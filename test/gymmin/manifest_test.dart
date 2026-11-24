import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'switches.dart';

final _manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

String? _attr(String tag, String name) => RegExp('$name="([^"]*)"').firstMatch(tag)?.group(1);

List<String> _tags(String element) =>
    [for (final m in RegExp('<$element\\b[^>]*>').allMatches(_manifest)) m.group(0)!];

String _component(String name) => [
      for (final kind in ['receiver', 'service', 'activity-alias'])
        for (final tag in _tags(kind))
          if (_attr(tag, 'android:name') == name) tag,
    ].single;

void main() {
  switchesOffInEachTest();

  test('declares only the permissions on the allow-list', () {
    final allowed = File('tool/gymmin_manifest_permissions.txt')
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toSet();
    final declared = {
      for (final tag in _tags('uses-permission'))
        if (_attr(tag, 'tools:node') != 'remove') _attr(tag, 'android:name')!,
    };
    expect(declared, allowed);
    expect(allowed.where((p) => p.contains('.health.') || p.endsWith('.INTERNET')), isEmpty);
  });

  test('declares no NFC or Bluetooth hardware feature', () {
    final features = {for (final tag in _tags('uses-feature')) _attr(tag, 'android:name')};
    expect(features, isNot(contains('android.hardware.nfc')));
    expect(features, isNot(contains('android.hardware.bluetooth')));
  });

  test('has no Health Connect permissions-usage entry', () {
    expect(_manifest, isNot(contains('HealthPermissionsUsage')));
    expect(_manifest, isNot(contains('VIEW_PERMISSION_USAGE')));
    expect(_manifest, isNot(contains('HEALTH_PERMISSIONS')));
  });

  test('disables the body, nutrition and gym-pass surfaces', () {
    for (final name in [
      '.BodyWidgetProvider',
      '.WaterWidgetProvider',
      '.ProteinWidgetProvider',
      '.KcalWidgetProvider',
      '.PassTileService',
    ]) {
      expect(_attr(_component(name), 'android:enabled'), 'false', reason: name);
    }
  });

  test('keeps the training widgets and the Today tile enabled', () {
    for (final name in [
      '.HeatmapWidgetProvider',
      '.StatsWidgetProvider',
      '.TodayWidgetProvider',
      '.WeekWidgetProvider',
      '.TodayTileService',
    ]) {
      expect(_attr(_component(name), 'android:enabled'), isNot('false'), reason: name);
    }
  });
}
