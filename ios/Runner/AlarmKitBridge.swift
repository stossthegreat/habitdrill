import Flutter
import UIKit
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Bridges Flutter → AlarmKit (iOS 26+). Rings through the silent switch by
/// design — no Critical Alerts entitlement required. Anything older than iOS
/// 26 returns `unsupported` and the Dart side falls back to notifications.
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
              let title = args["title"] as? String,
              let epochSeconds = args["fireAtEpochSeconds"] as? Double
        else {
          result(FlutterError(code: "bad_args", message: "id, title, fireAtEpochSeconds required", details: nil))
          return
        }
        Task { [weak self] in
          await self?.schedule(idString: idString, title: title, fireAt: epochSeconds, result: result)
        }
      } else {
        result(FlutterError(code: "unsupported", message: "iOS 26 required", details: nil))
      }
    case "cancel":
      if #available(iOS 26.0, *) {
        guard let args = call.arguments as? [String: Any],
              let idString = args["id"] as? String,
              let uuid = UUID(uuidString: idString)
        else {
          result(FlutterError(code: "bad_args", message: "id required", details: nil))
          return
        }
        Task {
          do {
            try await AlarmManager.shared.cancel(id: uuid)
            result(true)
          } catch {
            result(FlutterError(code: "cancel_failed", message: "\(error)", details: nil))
          }
        }
      } else {
        result(FlutterError(code: "unsupported", message: "iOS 26 required", details: nil))
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
  private func schedule(idString: String, title: String, fireAt: Double, result: @escaping FlutterResult) async {
    guard let uuid = UUID(uuidString: idString) else {
      result(FlutterError(code: "bad_id", message: "id must be a UUID string", details: nil))
      return
    }
    do {
      let fireDate = Date(timeIntervalSince1970: fireAt)
      let stopButton = AlarmButton(
        text: "OPEN & DISMISS",
        textColor: .white,
        systemImageName: "figure.strengthtraining.functional"
      )
      let alertPresentation = AlarmPresentation.Alert(
        title: LocalizedStringResource(stringLiteral: title),
        stopButton: stopButton
      )
      let attributes = AlarmAttributes<HabitDrillAlarmMetadata>(
        presentation: AlarmPresentation(alert: alertPresentation),
        tintColor: .green
      )
      let schedule = Alarm.Schedule.fixed(fireDate)
      let configuration = AlarmConfiguration(
        schedule: schedule,
        attributes: attributes,
        stopIntent: OpenHabitDrillIntent(alarmID: idString)
      )
      _ = try await AlarmManager.shared.schedule(id: uuid, configuration: configuration)
      result(true)
    } catch {
      result(FlutterError(code: "schedule_failed", message: "\(error)", details: nil))
    }
  }
}

// MARK: - Alarm metadata + intent

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct HabitDrillAlarmMetadata: AlarmMetadata {
  // Empty for now — we don't need custom appearance data.
}
#endif

#if canImport(AppIntents)
import AppIntents

/// Fires when the user taps the stop button. `openAppWhenRun` forces the app
/// into the foreground so we can present the MorningAlarm screen and force
/// completion of the punishment.
@available(iOS 26.0, *)
public struct OpenHabitDrillIntent: LiveActivityIntent {
  public static var title: LocalizedStringResource = "Open HabitDrill"
  public static var openAppWhenRun: Bool = true

  @Parameter(title: "alarmID")
  public var alarmID: String

  public init() { self.alarmID = "" }

  public init(alarmID: String) { self.alarmID = alarmID }

  public func perform() async throws -> some IntentResult {
    return .result()
  }
}
#endif
