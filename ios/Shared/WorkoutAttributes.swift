import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Lock-screen workout card. The Flutter app sends the same fields the
/// Android live notification shows: the current exercise, the set line,
/// and the rest deadline.
@available(iOS 16.1, *)
struct WorkoutAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var exercise: String
    var detail: String
    var index: Int
    var total: Int
    var restEnd: Date?
    var restLabel: String
    var paused: Bool
  }

  var title: String
}
#endif
