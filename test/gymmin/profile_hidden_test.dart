import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/gymmin.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/widgets/medal_shelf.dart';
import 'package:gymmane/widgets/photo_source_sheet.dart';
import 'package:gymmane/widgets/profile_avatar.dart';
import 'package:gymmane/widgets/ui_kit.dart' show sentenceCase;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'switches.dart';

final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  switchesOffInEachTest();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.clearProfilePhoto();
    fit.clearProfileBanner();
    fit.onboarded = true;
    setAppLanguage('en');
  });

  void logMonth() {
    final now = DateTime.now();
    final id = fit.allExercises.firstWhere((e) => e.primary == 'chest').id;
    for (var back = 28; back >= 1; back -= 3) {
      fit.sessions.add(LoggedSession(now.subtract(Duration(days: back)), 3600,
          [LoggedExercise(id, 'X', 'chest', [LoggedSet(5, 60)])]));
    }
    fit.refreshAwards();
  }

  Future<void> openProfile(WidgetTester tester) async {
    fit.route = 'settings';
    await tester.pumpWidget(const GymManeApp());
    await tester.pump(const Duration(seconds: 2));
  }

  Finder imagesIn(Finder of) => find.descendant(of: of, matching: find.byType(Image));

  Finder coverImages() => find.byWidgetPredicate(
      (w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).image != null);

  void expectHidden() {
    expect(find.text(t.awardsTitle), findsNothing);
    expect(find.byType(MedalShelf), findsNothing);
    expect(find.text(t.snapshots.toUpperCase()), findsNothing);
    expect(find.text(t.addPhoto), findsNothing);
    expect(find.text(t.gymPass), findsNothing);
    expect(find.text(t.levelShort(fit.athleteLevel)), findsNothing);
    expect(find.byType(ProfileAvatar), findsWidgets, reason: 'a placeholder avatar stays');
    expect(imagesIn(find.byType(ProfileAvatar)), findsNothing, reason: 'no avatar photo, not even the stock one');
    expect(coverImages(), findsNothing, reason: 'no cover photo');
  }

  testWidgets('a brand-new user sees a placeholder avatar and no medals, photos or pass', (tester) async {
    await openProfile(tester);

    expectHidden();
    expect(find.text(fit.profile.name), findsWidgets);
    expect(find.text(t.historyTitle), findsOneWidget);
    expect(find.text(t.editProfile), findsOneWidget);
  });

  testWidgets('a month of sessions and a stored photo still show no hidden box', (tester) async {
    logMonth();
    fit.passOn = true;
    fit.setProfilePhoto(_png);
    fit.setProfileBanner(_png);
    await openProfile(tester);

    expectHidden();
    expect(find.text(t.historyTitle), findsOneWidget);
    expect(find.text('${fit.sessions.length}'), findsWidgets);
  });

  for (final on in [false, true]) {
    testWidgets('tapping the cover area ${on ? 'opens' : 'does not open'} the photo picker', (tester) async {
      if (on) GymMin.setAll(true);
      await openProfile(tester);

      await tester.tapAt(const Offset(200, 80));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(PhotoSourceSheet), on ? findsOneWidget : findsNothing);
    });
  }

  for (final on in [false, true]) {
    testWidgets('the edit sheet ${on ? 'offers' : 'does not offer'} a way to set a photo or cover', (tester) async {
      if (on) GymMin.setAll(true);
      fit.setProfilePhoto(_png);
      fit.setProfileBanner(_png);
      await openProfile(tester);

      await tester.tap(find.text(t.editProfile));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(t.nameLabel), findsOneWidget);
      expect(find.text(sentenceCase(t.ageLabel)), findsOneWidget);
      expect(find.text(sentenceCase(t.heightLabel)), findsOneWidget);
      final matcher = on ? findsOneWidget : findsNothing;
      Finder chip(IconData icon) => find.byWidgetPredicate((w) => w is Icon && w.icon == icon && w.size == 14);
      expect(chip(PhosphorIconsRegular.camera), matcher);
      expect(chip(PhosphorIconsRegular.image), matcher);
      expect(find.text(t.removePhoto), matcher);
      expect(find.text(t.removeCover), matcher);
    });
  }

  testWidgets('with the switches on, the avatar and cover photos come back', (tester) async {
    GymMin.setAll(true);
    await openProfile(tester);

    expect(imagesIn(find.byType(ProfileAvatar)), findsWidgets);
    expect(coverImages(), findsWidgets);
    expect(find.text(t.addPhoto), findsOneWidget);
  });
}
