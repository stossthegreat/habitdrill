import Flutter
import UIKit
#if canImport(AlarmKit)
import AlarmKit
import AppIntents
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
        // ⚠️ Cast fireAtMs via NSNumber, not `as? Int64`. Flutter sends
        // Dart ints as NSNumber; direct `as? Int64` fails on some
        // devices and returns nil — which silently killed every single
        // alarm we scheduled. NSNumber.int64Value is the correct
        // bridge and works everywhere.
        guard let args = call.arguments as? [String: Any],
              let idString = args["id"] as? String,
              let uuid = UUID(uuidString: idString),
              let title = args["title"] as? String,
              let msNumber = args["fireAtMs"] as? NSNumber else {
          result(FlutterError(code: "bad_args",
                              message: "schedule needs id, title, fireAtMs",
                              details: nil))
          return
        }
        let fireAtMs = msNumber.int64Value
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
    case "cancelAll":
      // Enumerate what's ACTUALLY scheduled and stop each — one
      // method-channel round trip from Dart no matter how many
      // alarms exist. Replaces the old Dart-side blind sweep of
      // 200 slots × 7 days × N habits (thousands of channel calls,
      // froze the UI for minutes and got the app watchdog-killed).
      if #available(iOS 26.0, *) {
        Task {
          var stopped = 0
          do {
            let alarms = try AlarmManager.shared.alarms
            for alarm in alarms {
              try? await AlarmManager.shared.stop(id: alarm.id)
              stopped += 1
            }
          } catch {
            NSLog("AlarmKit cancelAll failed: \(error)")
          }
          result(stopped)
        }
      } else {
        result(0)
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
      let schedule = Alarm.Schedule.fixed(fireAt)

      // Two buttons on the alert:
      //   STOP  (X)     — dismisses the ring
      //   OPEN  (arrow) — opens HabitDrill straight into punishment
      //
      // The OPEN button uses a minimal parameter-less
      // LiveActivityIntent. openAppWhenRun does the heavy lift; when
      // the app foregrounds, PunishmentGate's every-build wake check
      // catches the due habit and swaps to the punishment screen.
      let stopButton = AlarmButton(
        text: "STOP",
        textColor: .white,
        systemImageName: "xmark.circle.fill"
      )
      let openButton = AlarmButton(
        text: "OPEN",
        textColor: .white,
        systemImageName: "arrow.right.circle.fill"
      )
      let alert = AlarmPresentation.Alert(
        title: LocalizedStringResource(stringLiteral: title),
        stopButton: stopButton,
        secondaryButton: openButton,
        secondaryButtonBehavior: .custom
      )
      let presentation = AlarmPresentation(alert: alert)

      let attributes = AlarmAttributes<HabitDrillMetadata>(
        presentation: presentation,
        metadata: HabitDrillMetadata(habitId: habitId),
        tintColor: .red
      )

      let config = AlarmManager.AlarmConfiguration(
        countdownDuration: nil,
        schedule: schedule,
        attributes: attributes,
        secondaryIntent: OpenAppIntent(),
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

/// Minimal intent for the OPEN button on the alarm alert. No
/// parameters, no widget-extension surface, no @Parameter storage —
/// keeps the config schedulable everywhere. openAppWhenRun launches
/// HabitDrill; PunishmentGate's build-time wake check then routes
/// straight into the MorningAlarmScreen.
@available(iOS 26.0, *)
struct OpenAppIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Open"
  static var openAppWhenRun: Bool = true

  init() {}

  func perform() async throws -> some IntentResult {
    return .result()
  }
}
#endif
