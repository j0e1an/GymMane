import AppIntents
import SwiftUI
import UIKit
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit
#endif

/// Home-screen widgets. Flutter renders each card to a PNG in the shared
/// app group; this extension shows that image, and rolls today/week forward
/// at midnight the same way the Android providers do.
enum WidgetStore {
  static let suite = "group.com.gymmane.app"

  static var defaults: UserDefaults {
    UserDefaults(suiteName: suite) ?? .standard
  }

  static var theme: String {
    defaults.string(forKey: "widget_theme") ?? "system"
  }

  static func image(_ key: String) -> UIImage? {
    guard let path = defaults.string(forKey: key), !path.isEmpty else { return nil }
    return UIImage(contentsOfFile: path)
  }

  static func dayStamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  /// Monday = 0, matching Android's `(DAY_OF_WEEK + 5) % 7`.
  static func weekdayIndex(_ date: Date) -> Int {
    let weekday = Calendar.current.component(.weekday, from: date)
    return (weekday + 5) % 7
  }

  static var nextMidnight: Date {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: Date())
    return calendar.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(5)
      ?? Date().addingTimeInterval(3600)
  }

  static func todayKey(now: Date = Date()) -> String {
    let saved = defaults.string(forKey: "today_stamp")
    let week = defaults.string(forKey: "today_week") ?? ""
    let index = weekdayIndex(now)
    let planned = index < week.count && week[week.index(week.startIndex, offsetBy: index)] == "1"
    let key: String
    if saved == nil || saved == dayStamp(now) {
      key = "today_img"
    } else if planned {
      key = "today_plan_img"
    } else {
      key = "today_idle_img"
    }
    if defaults.string(forKey: key) == nil { return "today_img" }
    return key
  }

  static func weekBaseKey(now: Date = Date()) -> String {
    let index = weekdayIndex(now)
    let calendar = Calendar.current
    let monday = calendar.date(byAdding: .day, value: -index, to: now) ?? now
    let saved = defaults.string(forKey: "week_start")
    let fresh = saved != nil && saved != dayStamp(monday)
    if fresh && defaults.string(forKey: "week_fresh_img") != nil {
      return "week_fresh_img"
    }
    return "week_img"
  }

  static func weekDoneToday(now: Date = Date()) -> Bool {
    let index = weekdayIndex(now)
    let calendar = Calendar.current
    let monday = calendar.date(byAdding: .day, value: -index, to: now) ?? now
    let saved = defaults.string(forKey: "week_start")
    let fresh = saved != nil && saved != dayStamp(monday)
    if fresh { return false }
    let done = defaults.string(forKey: "week_done") ?? ""
    return index < done.count && done[done.index(done.startIndex, offsetBy: index)] == "1"
  }

  static func weekImage(night: Bool, now: Date = Date()) -> UIImage? {
    let base = weekBaseKey(now: now)
    let key = night ? "\(base)_night" : base
    guard let image = image(key) ?? (night ? image(base) : nil) else { return nil }
    if weekDoneToday(now: now) { return image }
    guard let geo = defaults.string(forKey: "week_geo")?
      .split(separator: ",")
      .compactMap({ Double($0) }), geo.count >= 5 else {
      return image
    }
    let ring = defaults.string(forKey: night ? "week_ring_night" : "week_ring")
    return drawRing(image, geo: geo, day: weekdayIndex(now), color: parseHex(ring))
  }

  private static func drawRing(_ image: UIImage, geo: [Double], day: Int, color: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = image.scale
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: image.size))
      let width = image.size.width
      let center = CGPoint(
        x: (geo[0] + geo[1] * Double(day)) * width,
        y: geo[2] * image.size.height
      )
      let path = UIBezierPath(
        arcCenter: center,
        radius: geo[3] * width,
        startAngle: 0,
        endAngle: .pi * 2,
        clockwise: true
      )
      path.lineWidth = geo[4] * width
      color.setStroke()
      path.stroke()
    }
  }

  private static func parseHex(_ raw: String?) -> UIColor {
    guard var hex = raw?.trimmingCharacters(in: .whitespacesAndNewlines), hex.hasPrefix("#") else {
      return .white
    }
    hex.removeFirst()
    var value: UInt64 = 0
    guard Scanner(string: hex).scanHexInt64(&value) else { return .white }
    if hex.count == 8 {
      return UIColor(
        red: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: CGFloat((value >> 24) & 0xFF) / 255
      )
    }
    if hex.count == 6 {
      return UIColor(
        red: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: 1
      )
    }
    return .white
  }
}

struct ThemedEntry: TimelineEntry {
  let date: Date
  let light: UIImage?
  let dark: UIImage?
  let theme: String
}

struct ThemedImage: View {
  let light: UIImage?
  let dark: UIImage?
  let theme: String

  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let night = theme == "dark" || (theme != "light" && scheme == .dark)
    let image = night ? (dark ?? light) : (light ?? dark)
    Group {
      if let image {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
      } else {
        ZStack {
          Color(red: 12 / 255, green: 11 / 255, blue: 10 / 255)
          Text("GymMane")
            .font(.headline)
            .foregroundStyle(Color(red: 217 / 255, green: 161 / 255, blue: 132 / 255))
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .gymmaneWidget()
  }
}

extension View {
  @ViewBuilder func gymmaneWidget() -> some View {
    if #available(iOS 17.0, *) {
      self.containerBackground(for: .widget) { Color.clear }
        .contentMarginsDisabled()
    } else {
      self
    }
  }
}

struct StaticImageProvider: TimelineProvider {
  let key: String

  func placeholder(in context: Context) -> ThemedEntry {
    ThemedEntry(date: Date(), light: nil, dark: nil, theme: "system")
  }

  func getSnapshot(in context: Context, completion: @escaping (ThemedEntry) -> Void) {
    completion(entry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ThemedEntry>) -> Void) {
    completion(Timeline(entries: [entry()], policy: .after(WidgetStore.nextMidnight)))
  }

  private func entry() -> ThemedEntry {
    ThemedEntry(
      date: Date(),
      light: WidgetStore.image(key),
      dark: WidgetStore.image("\(key)_night") ?? WidgetStore.image(key),
      theme: WidgetStore.theme
    )
  }
}

struct TodayProvider: TimelineProvider {
  func placeholder(in context: Context) -> ThemedEntry {
    ThemedEntry(date: Date(), light: nil, dark: nil, theme: "system")
  }

  func getSnapshot(in context: Context, completion: @escaping (ThemedEntry) -> Void) {
    completion(entry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ThemedEntry>) -> Void) {
    completion(Timeline(entries: [entry()], policy: .after(WidgetStore.nextMidnight)))
  }

  private func entry() -> ThemedEntry {
    let key = WidgetStore.todayKey()
    return ThemedEntry(
      date: Date(),
      light: WidgetStore.image(key),
      dark: WidgetStore.image("\(key)_night") ?? WidgetStore.image(key),
      theme: WidgetStore.theme
    )
  }
}

struct WeekProvider: TimelineProvider {
  func placeholder(in context: Context) -> ThemedEntry {
    ThemedEntry(date: Date(), light: nil, dark: nil, theme: "system")
  }

  func getSnapshot(in context: Context, completion: @escaping (ThemedEntry) -> Void) {
    completion(entry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ThemedEntry>) -> Void) {
    completion(Timeline(entries: [entry()], policy: .after(WidgetStore.nextMidnight)))
  }

  private func entry() -> ThemedEntry {
    ThemedEntry(
      date: Date(),
      light: WidgetStore.weekImage(night: false),
      dark: WidgetStore.weekImage(night: true),
      theme: WidgetStore.theme
    )
  }
}

struct TodayWidget: Widget {
  let kind = "TodayWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
      ThemedImage(light: entry.light, dark: entry.dark, theme: entry.theme)
    }
    .configurationDisplayName("Today")
    .description("Today done or not")
    .supportedFamilies([.systemSmall])
  }
}

struct StatsWidget: Widget {
  let kind = "StatsWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StaticImageProvider(key: "stats_img")) { entry in
      ThemedImage(light: entry.light, dark: entry.dark, theme: entry.theme)
    }
    .configurationDisplayName("Stats")
    .description("Streak, this week, and your goal")
    .supportedFamilies([.systemSmall])
  }
}

struct HeatmapWidget: Widget {
  let kind = "HeatmapWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StaticImageProvider(key: "heatmap_img")) { entry in
      ThemedImage(light: entry.light, dark: entry.dark, theme: entry.theme)
    }
    .configurationDisplayName("Activity")
    .description("Your training heatmap")
    .supportedFamilies([.systemMedium])
  }
}

struct WeekWidget: Widget {
  let kind = "WeekWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: WeekProvider()) { entry in
      ThemedImage(light: entry.light, dark: entry.dark, theme: entry.theme)
    }
    .configurationDisplayName("Week")
    .description("This week's sessions")
    .supportedFamilies([.systemMedium])
  }
}

struct BodyWidget: Widget {
  let kind = "BodyWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StaticImageProvider(key: "body_img")) { entry in
      ThemedImage(light: entry.light, dark: entry.dark, theme: entry.theme)
    }
    .configurationDisplayName("Muscle map")
    .description("Where you trained this week")
    .supportedFamilies([.systemLarge])
  }
}

@available(iOS 16.1, *)
struct WorkoutLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkoutAttributes.self) { context in
      VStack(alignment: .leading, spacing: 4) {
        Text(context.state.exercise)
          .font(.headline)
          .lineLimit(1)
        Text(context.state.detail)
          .font(.subheadline)
          .lineLimit(2)
        if let end = context.state.restEnd, !context.state.paused, end > Date() {
          HStack {
            Text(context.state.restLabel)
            Text(timerInterval: Date()...end, countsDown: true)
              .monospacedDigit()
          }
          .font(.title3.weight(.semibold))
        }
        if context.state.total > 0 {
          Text("\(context.state.index + 1)/\(context.state.total)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        LiveActionButtons(actions: context.state.actions)
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(context.state.exercise).font(.headline).lineLimit(1)
        }
        DynamicIslandExpandedRegion(.trailing) {
          if let end = context.state.restEnd, !context.state.paused, end > Date() {
            Text(timerInterval: Date()...end, countsDown: true).monospacedDigit()
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            Text(context.state.detail).lineLimit(2)
            LiveActionButtons(actions: context.state.actions)
          }
        }
      } compactLeading: {
        Image(systemName: "figure.strengthtraining.traditional")
      } compactTrailing: {
        if let end = context.state.restEnd, !context.state.paused, end > Date() {
          Text(timerInterval: Date()...end, countsDown: true).monospacedDigit()
        } else if context.state.total > 0 {
          Text("\(context.state.index + 1)/\(context.state.total)")
        }
      } minimal: {
        Image(systemName: "figure.strengthtraining.traditional")
      }
    }
  }
}

@available(iOS 16.1, *)
struct LiveActionButtons: View {
  let actions: [WorkoutAttributes.LiveAction]

  var body: some View {
    if !actions.isEmpty {
      HStack(spacing: 6) {
        ForEach(actions) { action in
          LiveActionButton(action: action)
        }
      }
      .font(.caption.weight(.semibold))
    }
  }
}

@available(iOS 16.1, *)
struct LiveActionButton: View {
  let action: WorkoutAttributes.LiveAction

  var body: some View {
    if #available(iOS 17.0, *) {
      Button(intent: WorkoutActionIntent(actionId: action.id)) {
        Text(action.label).lineLimit(1).minimumScaleFactor(0.65)
      }
      .buttonStyle(.bordered)
    } else if let url = Self.url(action.id) {
      Link(destination: url) {
        Text(action.label).lineLimit(1).minimumScaleFactor(0.65)
      }
    }
  }

  private static func url(_ id: String) -> URL? {
    var parts = URLComponents()
    parts.scheme = "gymmane"
    parts.host = "live-action"
    parts.queryItems = [URLQueryItem(name: "id", value: id)]
    return parts.url
  }
}

@main
struct GymManeWidgetBundle: WidgetBundle {
  var body: some Widget {
    TodayWidget()
    StatsWidget()
    HeatmapWidget()
    WeekWidget()
    BodyWidget()
    if #available(iOS 16.1, *) {
      WorkoutLiveActivity()
    }
  }
}
