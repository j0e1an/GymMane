import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(AppIntents)
import AppIntents
#endif

/// Lock-screen workout card. The Flutter app sends the same fields the
/// Android live notification shows, including the rest-timer actions.
enum LiveActionDispatch {
  static let appGroup = "group.com.gymmane.app"
  static let storageKey = "live_action"
  static let darwinName = "com.gymmane.app.liveAction" as CFString
  static let allowed: Set<String> = ["done", "pause", "add", "skip", "next"]

  /// Set in the app process. The widget process leaves this nil and posts
  /// the action through the app group instead.
  static var deliver: ((String) -> Void)?

  static func send(_ id: String) {
    guard allowed.contains(id) else { return }
    if let deliver {
      deliver(id)
      return
    }
    UserDefaults(suiteName: appGroup)?.set(id, forKey: storageKey)
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(darwinName),
      nil,
      nil,
      true
    )
  }
}

#if canImport(ActivityKit)
@available(iOS 16.1, *)
struct WorkoutAttributes: ActivityAttributes {
  struct LiveAction: Codable, Hashable, Identifiable {
    var id: String
    var label: String
  }

  struct ContentState: Codable, Hashable {
    var exercise: String
    var detail: String
    var index: Int
    var total: Int
    var restEnd: Date?
    var restLabel: String
    var paused: Bool
    var actions: [LiveAction]

    init(
      exercise: String,
      detail: String,
      index: Int,
      total: Int,
      restEnd: Date?,
      restLabel: String,
      paused: Bool,
      actions: [LiveAction] = []
    ) {
      self.exercise = exercise
      self.detail = detail
      self.index = index
      self.total = total
      self.restEnd = restEnd
      self.restLabel = restLabel
      self.paused = paused
      self.actions = actions
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      exercise = try container.decode(String.self, forKey: .exercise)
      detail = try container.decode(String.self, forKey: .detail)
      index = try container.decode(Int.self, forKey: .index)
      total = try container.decode(Int.self, forKey: .total)
      restEnd = try container.decodeIfPresent(Date.self, forKey: .restEnd)
      restLabel = try container.decode(String.self, forKey: .restLabel)
      paused = try container.decode(Bool.self, forKey: .paused)
      actions = try container.decodeIfPresent([LiveAction].self, forKey: .actions) ?? []
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(exercise, forKey: .exercise)
      try container.encode(detail, forKey: .detail)
      try container.encode(index, forKey: .index)
      try container.encode(total, forKey: .total)
      try container.encodeIfPresent(restEnd, forKey: .restEnd)
      try container.encode(restLabel, forKey: .restLabel)
      try container.encode(paused, forKey: .paused)
      try container.encode(actions, forKey: .actions)
    }

    private enum CodingKeys: String, CodingKey {
      case exercise, detail, index, total, restEnd, restLabel, paused, actions
    }
  }

  var title: String
}

@available(iOS 17.0, *)
struct WorkoutActionIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Workout action"
  static var openAppWhenRun: Bool = false

  @Parameter(title: "Action")
  var actionId: String

  init() {
    actionId = ""
  }

  init(actionId: String) {
    self.actionId = actionId
  }

  func perform() async throws -> some IntentResult {
    LiveActionDispatch.send(actionId)
    return .result()
  }
}
#endif
