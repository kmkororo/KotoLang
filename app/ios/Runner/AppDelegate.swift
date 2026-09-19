import AVFoundation
import CoreHaptics
import Flutter
import UIKit

/// The iOS half of what `MainActivity.kt` does on Android, for the question
/// screen:
///
/// - **What cuts the listening short** (`kotolang/audio`). Headphones pulled
///   out, or the sound taken by a call or another app. A line half-heard on a
///   train is not a line missed, so the question stops and waits. Reported
///   only while a line is being heard or answered.
/// - **The taps under the voice** (`kotolang/feel`). Core Haptics, which needs
///   no permission on iOS, played for the lengths the Dart side asks for.
///
/// Neither needs an entry in Info.plist.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audioChannel: FlutterMethodChannel?
  private var holding = false
  private var haptics: CHHapticEngine?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KotoLangNative")
    else { return }
    let messenger = registrar.messenger()

    let audio = FlutterMethodChannel(name: "kotolang/audio", binaryMessenger: messenger)
    audio.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "hold":
        self?.holding = true
        result(nil)
      case "release":
        self?.holding = false
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    audioChannel = audio
    NotificationCenter.default.addObserver(
      self, selector: #selector(interrupted(_:)),
      name: AVAudioSession.interruptionNotification, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(routeChanged(_:)),
      name: AVAudioSession.routeChangeNotification, object: nil)

    let feel = FlutterMethodChannel(name: "kotolang/feel", binaryMessenger: messenger)
    feel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "vibrate", let pattern = call.arguments as? [NSNumber] else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.vibrate(pattern.map { $0.doubleValue / 1000 }) ?? false)
    }
  }

  /// A call, an alarm, another app taking the sound.
  @objc private func interrupted(_ note: Notification) {
    guard holding,
      let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      AVAudioSession.InterruptionType(rawValue: raw) == .began
    else { return }
    DispatchQueue.main.async { self.audioChannel?.invokeMethod("interrupted", arguments: "focus") }
  }

  /// Headphones pulled out: the route the sound was on went away.
  @objc private func routeChanged(_ note: Notification) {
    guard holding,
      let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
      AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable
    else { return }
    DispatchQueue.main.async { self.audioChannel?.invokeMethod("interrupted", arguments: "noisy") }
  }

  /// Plays [pattern] — on, off, on, … in seconds — as Core Haptics events.
  /// A phone without the Taptic Engine gets one plain tap instead.
  private func vibrate(_ pattern: [Double]) -> Bool {
    guard !pattern.isEmpty else { return false }
    guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      return false
    }
    do {
      if haptics == nil {
        let engine = try CHHapticEngine()
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = { [weak self] in try? self?.haptics?.start() }
        haptics = engine
      }
      guard let engine = haptics else { return false }
      try engine.start()
      var events: [CHHapticEvent] = []
      var at = 0.0
      for (i, length) in pattern.enumerated() {
        if i % 2 == 0 {
          events.append(
            CHHapticEvent(
              eventType: .hapticContinuous,
              parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
              ],
              relativeTime: at,
              duration: length))
        }
        at += length
      }
      let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
      try player.start(atTime: CHHapticTimeImmediate)
      return true
    } catch {
      return false
    }
  }
}
