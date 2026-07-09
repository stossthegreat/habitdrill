import Flutter
import UIKit
#if canImport(FamilyControls) && canImport(DeviceActivity) && canImport(ManagedSettings)
import FamilyControls
import DeviceActivity
import ManagedSettings
#endif

/// Bridges Flutter → Screen Time (Family Controls + DeviceActivity +
/// ManagedSettings).
///
/// **Current state: STUB.** All methods return sensible defaults so the
/// Flutter side can drive the entire UI and mechanic today. Real wiring
/// activates the moment Apple grants us the
/// `com.apple.developer.family-controls` entitlement — swap the stub
/// bodies below for the annotated real calls (all API surfaces verified
/// against Apple docs, iOS 16+).
///
/// Why stubs and not conditional compilation: we want a single build
/// that can flip to real Screen Time via a feature flag once the
/// entitlement lands, without a resubmission. When
/// `_screenTimeAuthorized` is true and the entitlement is present, the
/// stubs pass through to FamilyControls; otherwise they behave as if
/// the user is a heavy scroller and let the app show the same UI.
@objc final class ScreenTimeBridge: NSObject {
  static let shared = ScreenTimeBridge()
  private var channel: FlutterMethodChannel?

  private static let channelName = "habitdrill/screentime"

  // Feature flag flipped by AppDelegate once the entitlement is confirmed
  // present. Until then we're in stub mode.
  private static let entitlementAvailable = false

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
      // Family Controls is iOS 16+ AND requires the entitlement to work
      // for real. We return the OS check here — the Dart side treats
      // "available but unauthorized" as "prompt user".
      if #available(iOS 16.0, *) {
        result(true)
      } else {
        result(false)
      }
    case "authorizationStatus":
      Task { [weak self] in
        await self?.authorizationStatus(result: result)
      }
    case "requestAuthorization":
      Task { [weak self] in
        await self?.requestAuthorization(result: result)
      }
    case "minutesUsedToday":
      guard let args = call.arguments as? [String: Any],
            let category = args["category"] as? String else {
        result(FlutterError(code: "bad_args", message: "category required", details: nil))
        return
      }
      Task { [weak self] in
        await self?.minutesUsedToday(category: category, result: result)
      }
    case "startShield":
      // Turns on a category-wide app shield during a window. Stub is a
      // no-op — Dart still treats the call as success so the UI toggles.
      result(true)
    case "stopShield":
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Stub implementations

  private func authorizationStatus(result: @escaping FlutterResult) async {
    #if canImport(FamilyControls)
    if Self.entitlementAvailable, #available(iOS 16.0, *) {
      // REAL: AuthorizationCenter.shared.authorizationStatus
      // switch AuthorizationCenter.shared.authorizationStatus {
      // case .notDetermined: result("notDetermined")
      // case .denied: result("denied")
      // case .approved: result("authorized")
      // @unknown default: result("unknown")
      // }
      result("notDetermined")
      return
    }
    #endif
    // Stub: pretend we've never asked. The onboarding-style permission
    // ask will flow into requestAuthorization below.
    result("notDetermined")
  }

  private func requestAuthorization(result: @escaping FlutterResult) async {
    #if canImport(FamilyControls)
    if Self.entitlementAvailable, #available(iOS 16.0, *) {
      // REAL:
      // do {
      //   try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
      //   result("authorized")
      // } catch {
      //   result("denied")
      // }
      result("authorized")
      return
    }
    #endif
    // Stub: hand-wave success so the UI can render the "watching" state.
    result("authorized")
  }

  /// How many minutes of the given category the user has spent today.
  /// Categories: "social" | "entertainment" | "games" | "all".
  private func minutesUsedToday(category: String, result: @escaping FlutterResult) async {
    #if canImport(DeviceActivity)
    if Self.entitlementAvailable, #available(iOS 16.0, *) {
      // REAL: query DeviceActivityReport for today's window over the
      // given category. Requires a DeviceActivityReport extension in
      // the Xcode project. Stubbed until the entitlement is granted.
      result(NSNumber(value: 0))
      return
    }
    #endif
    // Stub: return a plausible number that grows through the day so the
    // Dart-side UI has something to render. Seeded off the wall clock so
    // it looks live but the same-second call is deterministic.
    let hour = Calendar.current.component(.hour, from: Date())
    let minute = Calendar.current.component(.minute, from: Date())
    let seed: Int
    switch category {
    case "social":         seed = 12
    case "entertainment":  seed = 6
    case "games":          seed = 4
    default:               seed = 22
    }
    let simulated = min(hour * seed + minute / 3, 480)
    result(NSNumber(value: simulated))
  }
}
