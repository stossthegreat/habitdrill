import Flutter
import UIKit
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Bridges Flutter → AlarmKit (iOS 26+).
///
/// PARTIAL WIRING: For this build we only implement authorization
/// discovery. Actual alarm scheduling still needs Apple's iOS 26 sample
/// code to verify the AlarmConfiguration / AlarmManager.schedule signatures
/// (the WWDC session paraphrase we worked from didn't compile). The Dart
/// wrapper handles the unsupported responses gracefully — every alarm
/// still fires today via the local-notification burst path in AlarmService.
@objc final class AlarmKitBridge: NSObject {
  static let shared = AlarmKitBridge()
  private var channel: FlutterMethodChannel?

  private static let channelName = "habitdrill/alarmkit"

  @objc func register(with binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
    self.channel = channel
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      // Whether the AlarmKit framework is present on this OS. Scheduling
      // is separately gated below.
      if #available(iOS 26.0, *) {
        result(true)
      } else {
        result(false)
      }
    case "authorizationStatus":
      if #available(iOS 26.0, *) {
        result(Self.authorizationString())
      } else {
        result("unsupported")
      }
    case "requestAuthorization":
      if #available(iOS 26.0, *) {
        Task { [weak self] in
          await self?.requestAuthorization(result: result)
        }
      } else {
        result("unsupported")
      }
    case "schedule":
      // Not wired yet — see file header.
      result(FlutterError(code: "unsupported",
                          message: "AlarmKit schedule not wired in this build",
                          details: nil))
    case "cancel":
      // Not wired yet — see file header. Safe no-op.
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - iOS 26+ implementations

  @available(iOS 26.0, *)
  private static func authorizationString() -> String {
    switch AlarmManager.shared.authorizationState {
    case .notDetermined: return "notDetermined"
    case .authorized: return "authorized"
    case .denied: return "denied"
    @unknown default: return "unknown"
    }
  }

  @available(iOS 26.0, *)
  private func requestAuthorization(result: @escaping FlutterResult) async {
    do {
      _ = try await AlarmManager.shared.requestAuthorization()
      result(Self.authorizationString())
    } catch {
      result(FlutterError(code: "auth_failed", message: "\(error)", details: nil))
    }
  }
}
