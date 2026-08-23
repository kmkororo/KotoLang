# Running KotoLang on a MacBook (iOS)

Everything in `app/lib` is already shared with the Android build and is covered
by 74 tests. What has never been compiled is the iOS half, because Xcode only
runs on macOS. This is the sequence from a clean Mac to a running iPhone app.

---

## 1. Install the toolchain

```bash
# Xcode — from the App Store (large, ~10 GB). Then, once:
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept

# Command line tools + CocoaPods
xcode-select --install
brew install cocoapods       # or: sudo gem install cocoapods

# Flutter (Homebrew is the simplest route)
brew install --cask flutter
```

Confirm the iOS toolchain is healthy — this is the check that fails on Windows:

```bash
flutter doctor
```

You want ticks next to **Xcode** and **CocoaPods**. Ignore any Android
complaints if you are not building Android on the Mac.

## 2. Get the code

```bash
git clone <the repository URL> KotoLang
cd KotoLang/app
flutter pub get
```

Then resolve the iOS native dependencies. This step is macOS-only, which is why
`ios/Podfile.lock` is absent from the repository:

```bash
cd ios && pod install && cd ..
```

If CocoaPods complains about the repo being out of date:

```bash
pod repo update && pod install
```

## 3. Run on the simulator

```bash
open -a Simulator          # boots the default iPhone
flutter devices            # confirm it appears
flutter run                # or: flutter run -d "iPhone 16"
```

The simulator is enough to check layout, navigation, the ten interface
languages and the whole learning flow.

**It is not enough to judge audio.** The simulator uses the Mac's own speech
voices, which are not what an iPhone ships with. Treat any verdict on voice
quality from the simulator as provisional.

## 4. Run on a real iPhone

This is the run that matters, because text-to-speech is the one part that
genuinely differs per device.

1. Connect the iPhone by cable and tap **Trust** on the phone.
2. Open the Xcode workspace — **the workspace, not the project**:
   ```bash
   open ios/Runner.xcworkspace
   ```
3. Select the **Runner** target → **Signing & Capabilities**.
4. Tick **Automatically manage signing** and choose your Team. A free Apple ID
   works: it grants a 7-day provisioning profile, which is fine for testing.
   The bundle identifier `com.kmkor.kotolang` may need a suffix if someone else
   has already claimed it on the developer portal.
5. Back in the terminal:
   ```bash
   flutter run --release
   ```
6. On the phone, first launch only: **Settings → General → VPN & Device
   Management → Developer App → Trust**.

## 5. Run the tests

```bash
flutter test                                   # 96 host tests, no device needed
flutter test integration_test/device_test.dart # on the connected iPhone
```

The integration suite is the one worth watching. It checks three things that
only hardware can answer:

- the speech engine exposes an English voice, and speaking does not throw
- SQLite genuinely opens a file-backed database on the device
- a question can be answered end to end and the streak is recorded

It prints the voice count and the chosen voice. On Android hardware this was
51 voices and `en-us-x-iom-network`. iOS uses AVSpeechSynthesizer instead, so
expect entirely different names — Apple's are like `com.apple.voice.compact.en-US.Samantha`.

> The integration runner uninstalls the app when it finishes. Reinstall with
> `flutter run --release` afterwards if you want to keep using it.

## 6. Build for the App Store

```bash
flutter build ipa --release
```

The archive lands in `build/ios/archive/`. Upload it with Xcode's Organizer or
`xcrun altool`. This needs a paid Apple Developer account (USD 99/year); a free
Apple ID can only sideload to your own device.

---

## Things to check first on the Mac

These are the places where iOS is most likely to behave differently from the
Android build that is already verified.

### Text-to-speech

`flutter_tts` wraps AVSpeechSynthesizer on iOS. The voice-ranking logic in
`lib/core/speech.dart` scores names containing *neural*, *natural*, *google*,
*enhanced* and *network* — those words come from Android. Apple's naming is
different (*Compact*, *Enhanced*, *Premium*, *Siri*).

Run the integration test, read the printed voice list, and adjust `_score()` if
the chosen voice sounds poor. Apple's *Enhanced* and *Premium* voices are the
good ones and are downloaded on demand under **Settings → Accessibility →
Spoken Content → Voices**.

### SQLite

`package:sqlite3` 3.x supplies its own native build; `sqlite3_flutter_libs` is
now an intentional no-op shim. Verified working on Android. The iOS path uses
the same mechanism but has not been exercised — the integration test will say
so immediately if it fails.

### Share sheet on iPad

Already handled: `sharePositionOrigin` is passed when exporting, without which
iPadOS either throws or anchors the popover in the wrong corner. Worth a quick
check on an iPad if you have one.

### Privacy manifest

Recent App Store submissions require `ios/Runner/PrivacyInfo.xcprivacy`
declaring "required reason" API usage. KotoLang collects nothing and makes no
network requests, but the file must still exist and declare the APIs its
dependencies touch — typically file timestamps (`C617.1`) and user defaults
(`CA92.1`). Xcode will tell you at validation time if anything is missing.

### Share target — Android only so far

On Android, KotoLang registers as a `text/plain` share target so a long AI
reply can be sent to it directly, without being copied by hand. That is an
`intent-filter` plus a `MethodChannel` in `MainActivity.kt`, and it has no iOS
equivalent: iOS would need a separate **Share Extension** target in Xcode with
an app group to pass the text through.

Nothing is broken by its absence — `lib/core/share_intake.dart` returns null on
every platform but Android, and the clipboard path works as before. The
piecewise paste box and the truncation rescue, which are the parts that matter
most on a phone, are pure Dart and work identically on iOS.

Worth adding later if iOS becomes the primary platform.

### Permissions

None are needed. KotoLang plays audio but never records, so there is no
microphone entry, and there is no location, camera or contacts access. If Xcode
ever asks you to add a usage description, something has been pulled in that
should not have been — check the new dependency before adding it.

---

## If something goes wrong

| Symptom | Cause |
|---|---|
| `pod install` fails on Apple Silicon | `sudo arch -x86_64 gem install ffi`, then `arch -x86_64 pod install` |
| "Signing for Runner requires a development team" | Step 4 above was skipped |
| App installs then immediately closes | The developer certificate is untrusted — step 6 above |
| No sound, no error | No English voice downloaded on the phone. Settings → Accessibility → Spoken Content → Voices → English |
| `CocoaPods could not find compatible versions` | `pod repo update`, then `pod install` again |
