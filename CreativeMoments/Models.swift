import Foundation

struct PlannerMonth: Identifiable, Hashable {
    let year: Int
    let month: Int
    var id: String { String(format: "%04d-%02d", year, month) }
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        value.firstWeekday = 2
        return value
    }
    var date: Date { Self.calendar.date(from: DateComponents(year: year, month: month, day: 1))! }
    var dayCount: Int { Self.calendar.range(of: .day, in: .month, for: date)!.count }
    var leadingBlanks: Int { (Self.calendar.component(.weekday, from: date) + 5) % 7 }
    var title: String {
        let formatter = DateFormatter()
        formatter.calendar = Self.calendar
        formatter.timeZone = Self.calendar.timeZone
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    var theme: String { Self.themes[month - 1] }
    static let themes = ["Winter Stillness", "Quiet Connections", "Fresh Beginnings", "Rain & Renewal", "In Full Bloom", "Lakeside Light", "Coastal Calm", "Golden Fields", "Orchard Abundance", "Autumn Color", "A Quiet Pause", "Winter Wonder"]

    // The original 18 months are retained for compatibility with previous planner data.
    // New years are browsed via the year picker without changing existing record keys.
    static let all: [PlannerMonth] = (0..<18).map { offset in
        let index = 2026 * 12 + 11 + offset
        return PlannerMonth(year: index / 12, month: index % 12 + 1)
    }
    static func forDate(_ date: Date) -> PlannerMonth {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return PlannerMonth(year: components.year!, month: components.month!)
    }
    var previous: PlannerMonth { month == 1 ? PlannerMonth(year: year - 1, month: 12) : PlannerMonth(year: year, month: month - 1) }
}

/// Calendar-local day identifier. A date-only key avoids shifting deadlines across time zones.
struct PlannerDay: Hashable, Comparable {
    let year: Int
    let month: Int
    let day: Int
    var key: String { String(format: "%04d-%02d-%02d", year, month, day) }
    var monthValue: PlannerMonth { PlannerMonth(year: year, month: month) }
    init(date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year!; month = parts.month!; day = parts.day!
    }
    init?(key: String) {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        let candidate = PlannerMonth.calendar.date(from: DateComponents(year: y, month: m, day: d))
        guard let candidate, PlannerMonth.calendar.component(.month, from: candidate) == m,
              PlannerMonth.calendar.component(.day, from: candidate) == d else { return nil }
        year = y; month = m; day = d
    }
    var date: Date {
        // Noon minimizes ambiguity around local daylight saving transitions.
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
    static func < (lhs: PlannerDay, rhs: PlannerDay) -> Bool { lhs.key < rhs.key }
}

/// Saved in its owning month; the optional due-date key may refer to another month.
/// Legacy v1 JSON omitted `dueDateKey`, so decoding it must remain optional.
struct PlannerTask: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var completed: Bool
    var dueDateKey: String?

    init(id: UUID = UUID(), title: String, completed: Bool = false, dueDateKey: String? = nil) {
        self.id = id; self.title = title; self.completed = completed; self.dueDateKey = dueDateKey
    }
    private enum CodingKeys: String, CodingKey { case id, title, completed, dueDateKey }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        completed = try values.decode(Bool.self, forKey: .completed)
        dueDateKey = try values.decodeIfPresent(String.self, forKey: .dueDateKey)
    }
}

struct MonthRecord: Codable, Equatable {
    var focus = ""
    var days: [String: String] = [:]
    var tasks: [PlannerTask] = []
    var notes = ""
    var joy = ""
    var carryForward = ""
}
struct PlannerDocument: Codable {
    var schemaVersion = 1
    var coverName = "My Creative Moments"
    var months: [String: MonthRecord] = [:]
}

struct PlannerTaskItem: Identifiable {
    let month: PlannerMonth
    let task: PlannerTask
    var id: UUID { task.id }
}

enum DoodleSection: Int, CaseIterable, Identifiable {
    case season, sketch, patterns, free
    var id: Int { rawValue }
    var title: String { ["Color the season", "Sketch an idea", "Explore patterns", "Free doodle"][rawValue] }
    var subtitle: String { ["Make the seasonal scene your own.", "A shape, object, place, or possibility.", "Repeat a line, leaf, curve, or motif.", "Follow your hand and see what appears."][rawValue] }
}

/// A reference to an existing drawing file; no new persisted format or duplicate artwork.
struct SavedDrawing: Identifiable, Equatable {
    let month: PlannerMonth
    let section: DoodleSection
    var id: String { "\(month.id)-\(section.rawValue)" }
}
