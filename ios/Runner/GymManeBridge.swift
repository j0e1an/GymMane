import CoreHaptics
import Flutter
import Photos
import UIKit

#if canImport(ActivityKit)
import ActivityKit
#endif

/// Native side of the method channels the Flutter app already uses on Android.
/// Channels that are Android-only (the ongoing notification, the watch flag)
/// are answered here so iOS calls fail closed instead of throwing.
final class GymManeBridge: NSObject {
  static let shared = GymManeBridge()
  static let appGroup = "group.com.gymmane.app"
  static let incomingKey = "incoming_text"

  private var incoming: FlutterMethodChannel?
  private var pending: String?
  private var liveChannel: FlutterMethodChannel?
  private var liveReady = false
  private var pendingLiveAction: String?
  private var liveWatching = false
  private var hapticEngine: CHHapticEngine?
  private var savedBrightness: CGFloat?

  private override init() {
    super.init()
    installLiveActions()
  }

  /// Picks up an action saved by the widget process before this app launched.
  func pullStoredLiveAction() {
    guard let id = UserDefaults(suiteName: Self.appGroup)?.string(forKey: LiveActionDispatch.storageKey) else {
      return
    }
    UserDefaults(suiteName: Self.appGroup)?.removeObject(forKey: LiveActionDispatch.storageKey)
    if pendingLiveAction == id && !liveReady { return }
    deliverLiveAction(id)
  }

  func register(messenger: FlutterBinaryMessenger) {
    let haptics = FlutterMethodChannel(name: "gymmane/haptics", binaryMessenger: messenger)
    haptics.setMethodCallHandler { [weak self] call, result in
      guard call.method == "buzz" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.buzz()
      result(nil)
    }

    let incoming = FlutterMethodChannel(name: "gymmane/incoming", binaryMessenger: messenger)
    incoming.setMethodCallHandler { [weak self] call, result in
      guard call.method == "take" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.take())
    }
    self.incoming = incoming

    let gallery = FlutterMethodChannel(name: "gymmane/gallery", binaryMessenger: messenger)
    gallery.setMethodCallHandler { call, result in
      guard call.method == "savePng" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      let name = args?["name"] as? String ?? "gymmane.png"
      guard let data = Self.pngData(args?["bytes"]) else {
        result(FlutterError(code: "no-bytes", message: "missing image", details: nil))
        return
      }
      Self.savePng(data, name: name, result: result)
    }

    let screen = FlutterMethodChannel(name: "gymmane/screen", binaryMessenger: messenger)
    screen.setMethodCallHandler { [weak self] call, result in
      let on = Self.boolValue((call.arguments as? [String: Any])?["on"])
      switch call.method {
      case "keepOn":
        self?.keepOn(on)
        result(nil)
      case "dim":
        self?.dim(on)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let live = FlutterMethodChannel(name: "gymmane/live_activity", binaryMessenger: messenger)
    liveChannel = live
    live.setMethodCallHandler { [weak self] call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "update":
        Self.updateLive(args, result: result)
      case "end":
        Self.endLive(result: result)
      case "takeAction":
        result(self?.takeLiveAction())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let device = FlutterMethodChannel(name: "gymmane/device", binaryMessenger: messenger)
    device.setMethodCallHandler { call, result in
      guard call.method == "isWatch" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(false)
    }
  }

  func consume(url: URL) {
    if url.scheme == "gymmane" {
      if url.host == "live-action" {
        let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
          .queryItems?
          .first(where: { $0.name == "id" })?
          .value
        if let id { LiveActionDispatch.send(id) }
        return
      }
      if let stored = takeStored() {
        deliver(stored)
      }
      return
    }
    guard url.isFileURL else { return }
    let scoped = url.startAccessingSecurityScopedResource()
    defer {
      if scoped { url.stopAccessingSecurityScopedResource() }
    }
    guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
          data.count <= 2_000_000,
          let text = String(data: data, encoding: .utf8) else {
      return
    }
    deliver(text)
  }

  func storeIncoming(_ text: String) {
    UserDefaults(suiteName: Self.appGroup)?.set(text, forKey: Self.incomingKey)
  }

  private func deliver(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.utf8.count <= 2_000_000 else { return }
    if let incoming {
      incoming.invokeMethod("incoming", arguments: trimmed)
    } else {
      pending = trimmed
    }
  }

  private func take() -> String? {
    if let pending {
      self.pending = nil
      return pending
    }
    return takeStored()
  }

  private func takeStored() -> String? {
    let defaults = UserDefaults(suiteName: Self.appGroup)
    guard let text = defaults?.string(forKey: Self.incomingKey) else { return nil }
    defaults?.removeObject(forKey: Self.incomingKey)
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func keepOn(_ on: Bool) {
    DispatchQueue.main.async {
      UIApplication.shared.isIdleTimerDisabled = on
    }
  }

  private func dim(_ on: Bool) {
    DispatchQueue.main.async {
      if on {
        if self.savedBrightness == nil {
          self.savedBrightness = UIScreen.main.brightness
        }
        UIScreen.main.brightness = 0.02
      } else if let saved = self.savedBrightness {
        UIScreen.main.brightness = saved
        self.savedBrightness = nil
      }
    }
  }

  /// Same gaps as the Android waveform: 350 on, 180 off, 350 on, 180 off, 600 on.
  private func buzz() {
    let sharp = CHHapticEvent(
      eventType: .hapticTransient,
      parameters: [],
      relativeTime: 0
    )
    let mid = CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0.53)
    let last = CHHapticEvent(
      eventType: .hapticContinuous,
      parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)],
      relativeTime: 1.06,
      duration: 0.60
    )
    do {
      if hapticEngine == nil {
        hapticEngine = try CHHapticEngine()
      }
      let engine = hapticEngine!
      try engine.start()
      let pattern = try CHHapticPattern(events: [sharp, mid, last], parameters: [])
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: 0)
    } catch {
      UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
  }

  private static func pngData(_ raw: Any?) -> Data? {
    if let typed = raw as? FlutterStandardTypedData { return typed.data }
    if let data = raw as? Data { return data }
    return nil
  }

  private static func savePng(_ data: Data, name: String, result: @escaping FlutterResult) {
    let finish: (Bool) -> Void = { ok in
      DispatchQueue.main.async { result(ok) }
    }
    let write = {
      PHPhotoLibrary.shared().performChanges({
        let request = PHAssetCreationRequest.forAsset()
        let options = PHAssetResourceCreationOptions()
        options.originalFilename = name
        request.addResource(with: .photo, data: data, options: options)
      }) { ok, error in
        if error != nil {
          DispatchQueue.main.async {
            result(FlutterError(code: "save-failed", message: error?.localizedDescription, details: nil))
          }
        } else {
          finish(ok)
        }
      }
    }
    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        guard status == .authorized || status == .limited else {
          finish(false)
          return
        }
        write()
      }
    } else {
      PHPhotoLibrary.requestAuthorization { status in
        guard status == .authorized else {
          finish(false)
          return
        }
        write()
      }
    }
  }

  private static func boolValue(_ raw: Any?) -> Bool {
    if let value = raw as? Bool { return value }
    if let value = raw as? NSNumber { return value.boolValue }
    return false
  }

  private static func intValue(_ raw: Any?) -> Int? {
    if raw is NSNull || raw == nil { return nil }
    if let value = raw as? Int { return value }
    if let value = raw as? NSNumber { return value.intValue }
    return nil
  }

  private static func updateLive(_ args: [String: Any], result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    let exercise = args["exercise"] as? String ?? "GymMane"
    let detail = args["detail"] as? String ?? ""
    let index = intValue(args["index"]) ?? 0
    let total = intValue(args["total"]) ?? 0
    let paused = boolValue(args["paused"])
    let restLabel = args["restLabel"] as? String ?? ""
    let restEnd = intValue(args["restEnd"]).map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
    let state = WorkoutAttributes.ContentState(
      exercise: exercise,
      detail: detail,
      index: index,
      total: total,
      restEnd: restEnd,
      restLabel: restLabel,
      paused: paused,
      actions: liveActions(args["actions"])
    )
    Task {
      do {
        try await LiveActivityClient.push(state)
        await MainActor.run { result(nil) }
      } catch {
        await MainActor.run {
          result(FlutterError(code: "live", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func installLiveActions() {
    guard !liveWatching else { return }
    liveWatching = true
    LiveActionDispatch.deliver = { [weak self] id in
      DispatchQueue.main.async { self?.deliverLiveAction(id) }
    }
    CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque(),
      liveActionDarwinCallback,
      LiveActionDispatch.darwinName,
      nil,
      .deliverImmediately
    )
  }

  private var lastLiveActionId = ""
  private var lastLiveActionAt = Date.distantPast

  private func deliverLiveAction(_ id: String) {
    guard LiveActionDispatch.allowed.contains(id) else { return }
    let now = Date()
    if id == lastLiveActionId && now.timeIntervalSince(lastLiveActionAt) < 0.4 { return }
    lastLiveActionId = id
    lastLiveActionAt = now
    if liveReady, let liveChannel {
      pendingLiveAction = nil
      UserDefaults(suiteName: Self.appGroup)?.removeObject(forKey: LiveActionDispatch.storageKey)
      liveChannel.invokeMethod("action", arguments: id)
    } else {
      pendingLiveAction = id
      UserDefaults(suiteName: Self.appGroup)?.set(id, forKey: LiveActionDispatch.storageKey)
    }
  }

  private func takeLiveAction() -> String? {
    liveReady = true
    let stored = UserDefaults(suiteName: Self.appGroup)?.string(forKey: LiveActionDispatch.storageKey)
    UserDefaults(suiteName: Self.appGroup)?.removeObject(forKey: LiveActionDispatch.storageKey)
    let id = pendingLiveAction ?? stored
    pendingLiveAction = nil
    guard let id, LiveActionDispatch.allowed.contains(id) else { return nil }
    return id
  }

  @available(iOS 16.1, *)
  private static func liveActions(_ raw: Any?) -> [WorkoutAttributes.LiveAction] {
    guard let list = raw as? [Any] else { return [] }
    return list.compactMap { item in
      guard let map = item as? [String: Any],
            let id = map["id"] as? String,
            let label = map["label"] as? String,
            LiveActionDispatch.allowed.contains(id) else { return nil }
      return WorkoutAttributes.LiveAction(id: id, label: label)
    }
  }

  private static func endLive(result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    Task {
      await LiveActivityClient.end()
      await MainActor.run { result(nil) }
    }
  }
}

@available(iOS 16.1, *)
private enum LiveActivityClient {
  static func push(_ state: WorkoutAttributes.ContentState) async throws {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    if let current = Activity<WorkoutAttributes>.activities.first {
      await update(current, state: state)
      return
    }
    let attributes = WorkoutAttributes(title: "GymMane")
    if #available(iOS 16.2, *) {
      _ = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: state, staleDate: state.restEnd),
        pushType: nil
      )
    } else {
      _ = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
    }
  }

  static func end() async {
    for activity in Activity<WorkoutAttributes>.activities {
      if #available(iOS 16.2, *) {
        await activity.end(nil, dismissalPolicy: .immediate)
      } else {
        await activity.end(using: nil, dismissalPolicy: .immediate)
      }
    }
  }

  private static func update(
    _ activity: Activity<WorkoutAttributes>,
    state: WorkoutAttributes.ContentState
  ) async {
    if #available(iOS 16.2, *) {
      await activity.update(ActivityContent(state: state, staleDate: state.restEnd))
    } else {
      await activity.update(using: state)
    }
  }
}

private func liveActionDarwinCallback(
  _ center: CFNotificationCenter?,
  _ observer: UnsafeMutableRawPointer?,
  _ name: CFNotificationName?,
  _ object: UnsafeRawPointer?,
  _ userInfo: CFDictionary?
) {
  guard let observer else { return }
  let bridge = Unmanaged<GymManeBridge>.fromOpaque(observer).takeUnretainedValue()
  DispatchQueue.main.async { bridge.pullStoredLiveAction() }
}
