/// The platform folders are hand-maintained and cannot be exercised from a
/// Dart test, so these check the two things about them that would otherwise
/// only be found on a device: that the interface languages are declared where
/// the platform can see them, and that neither platform has quietly acquired a
/// permission the app does not need.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotolang/core/l10n/languages.dart';
import 'package:kotolang/features/ai_links.dart';

/// iOS spells two of these differently from the app's own BCP-47 tags.
const _iosSpelling = <String, String>{'zh-CN': 'zh-Hans'};

String _read(String path) {
  final f = File(path);
  expect(f.existsSync(), isTrue, reason: '$path is missing');
  return f.readAsStringSync();
}

void main() {
  test('iOS declares every interface language the app ships', () {
    // iOS hands an app only the locales its bundle claims to support. A
    // language missing from this list is a language the device will never
    // report, so the first screen preselects English for someone whose phone
    // is set to Japanese — and nothing about it is visible on Android.
    final plist = _read('ios/Runner/Info.plist');
    final block = RegExp(
            r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
            dotAll: true)
        .firstMatch(plist);
    expect(block, isNotNull, reason: 'Info.plist declares no localizations');

    final declared = RegExp(r'<string>([^<]+)</string>')
        .allMatches(block!.group(1)!)
        .map((m) => m.group(1)!)
        .toSet();

    final missing = [
      for (final l in supportedLanguages)
        if (!declared.contains(_iosSpelling[l.code] ?? l.code)) l.code
    ];
    expect(missing, isEmpty, reason: 'not declared in Info.plist: $missing');
  });

  test('neither platform asks for a permission', () {
    // The privacy policy promises no permissions at all, not even internet.
    // Plugins arrive with README snippets that add them, so this is the guard.
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    final asked = RegExp(r'<uses-permission[^>]*android:name="([^"]+)"')
        .allMatches(manifest)
        .map((m) => m.group(1)!)
        .toList();
    expect(asked, isEmpty, reason: 'Android now requests: $asked');

    final plist = _read('ios/Runner/Info.plist');
    final usage = RegExp(r'<key>(NS\w*UsageDescription)</key>')
        .allMatches(plist)
        .map((m) => m.group(1)!)
        .toList();
    expect(usage, isEmpty, reason: 'iOS now requests: $usage');
  });


  test('both platforms can see the assistants the app tries to open', () {
    // url_launcher asks the system whether a scheme can be opened before it
    // opens it, and both platforms answer "no" for a scheme the app has not
    // declared. Undeclared, the setup screens silently fall back to the web
    // address for ever, with the assistant's own app installed and unused.
    final wanted = [
      for (final a in aiServices)
        if (a.scheme != null) a.scheme!
    ];
    expect(wanted, isNotEmpty, reason: 'the fixture must have schemes in it');

    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    for (final s in wanted) {
      expect(manifest, contains('android:scheme="$s"'),
          reason: '$s is missing from the Android <queries> block');
    }

    final plist = _read('ios/Runner/Info.plist');
    final block = RegExp(
            r'<key>LSApplicationQueriesSchemes</key>\s*<array>(.*?)</array>',
            dotAll: true)
        .firstMatch(plist);
    expect(block, isNotNull, reason: 'Info.plist declares no query schemes');
    for (final s in wanted) {
      expect(block!.group(1), contains('<string>$s</string>'),
          reason: '$s is missing from LSApplicationQueriesSchemes');
    }
  });

  test('both platforms carry the same identity', () {
    expect(_read('ios/Runner.xcodeproj/project.pbxproj'),
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.kmkor.kotolang;'));
    expect(_read('android/app/build.gradle.kts'),
        contains('com.kmkor.kotolang'));
  });
}
