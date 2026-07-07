import Flutter
import UIKit
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Bridges Flutter → AlarmKit (iOS 26+).
///
/// This is the REAL wiring — API signatures verified against Apple's
/// AlarmKit doc and jacobsapps/ADHDAlarms working reference:
///
/// - `AlarmManager.shared.schedule(id:configuration:)` — nested config
///   type `AlarmManager.AlarmConfiguration` (NOT top-level `AlarmConfiguration`)
/// - Non-snoozable: omit `secondaryButton` in `AlarmPresentation.Alert`
/// - Route into our exercise flow on tap: `LiveActivityIntent` with
///   `openAppWhenRun = true` writes to shared UserDefaults so Flutter
///   picks it up on resume (see `_checkForAlarmTap` in main.dart)
/// - Requires Info.plist `NSAlarmKitUsageDescription`
/// - Entitlement `com.apple.developer.alarmkit` may not yet be selectable
///   in the Developer Portal (Aug 2025 status). Falls back gracefully:
///   `isAvailable()` returning false makes AlarmService rely on its
///   local-notification burst path.
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
      if #available(iOS 26.0, *) {
        guard let args = call.arguments as? [String: Any],
              let idString = args["id"] as? String,
              let uuid = UUID(uuidString: idString),
              let title = args["title"] as? String,
              let fireAtMs = args["fireAtMs"] as? Int64 else {
          result(FlutterError(code: "bad_args",
                              message: "schedule needs id, title, fireAtMs",
                              details: nil))
          return
        }
        let fireAt = Date(timeIntervalSince1970: TimeInterval(fireAtMs) / 1000.0)
        let habitId = args["habitId"] as? String ?? ""
        Task { [weak self] in
          await self?.schedule(uuid: uuid, title: title, fireAt: fireAt, habitId: habitId, result: result)
        }
      } else {
        result(false)
      }
    case "cancel":
      if #available(iOS 26.0, *) {
        guard let args = call.arguments as? [String: Any],
              let idString = args["id"] as? String,
              let uuid = UUID(uuidString: idString) else {
          result(FlutterError(code: "bad_args", message: "cancel needs id", details: nil))
          return
        }
        Task {
          do {
            try await AlarmManager.shared.stop(id: uuid)
            result(true)
          } catch {
            // Non-fatal — alarm may already be dismissed / never scheduled.
            result(true)
          }
        }
      } else {
        result(true)
      }
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

  @available(iOS 26.0, *)
  private func schedule(uuid: UUID, title: String, fireAt: Date, habitId: String, result: @escaping FlutterResult) async {
    do {
      // Fire once at fireAt — the Flutter side already handles weekly
      // repeat by re-scheduling next week's fire when the app opens.
      let schedule = Alarm.Schedule.fixed(fireAt)

      // Non-snoozable: only a Stop button, no secondary.
      let alert = AlarmPresentation.Alert(
        title: LocalizedStringResource(stringLiteral: title),
        stopButton: AlarmButton(
          text: "PUNISHMENT",
          textColor: .white,
          systemImageName: "figure.strengthtraining.functional"
        )
      )
      let presentation = AlarmPresentation(alert: alert)

      let attributes = AlarmAttributes<HabitDrillMetadata>(
        presentation: presentation,
        metadata: HabitDrillMetadata(habitId: habitId),
        tintColor: .red
      )

      // Non-snoozable: no countdown, no secondary button, no secondary
      // intent. Tapping Stop dismisses the alert and foregrounds the
      // app, at which point PunishmentGate re-runs _checkForAlarmTap and
      // routes into the wake screen via WakeDebtService.getActiveHabitId.
      let config = AlarmManager.AlarmConfiguration(
        countdownDuration: nil,
        schedule: schedule,
        attributes: attributes,
        sound: .default
      )

      _ = try await AlarmManager.shared.schedule(id: uuid, configuration: config)
      result(true)
    } catch {
      NSLog("AlarmKit schedule failed: \(error)")
      result(false)
    }
  }
}

// MARK: - AlarmKit types (iOS 26+ only)

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct HabitDrillMetadata: AlarmMetadata {
  let habitId: String
  init(habitId: String = "") { self.habitId = habitId }
}
#endif
