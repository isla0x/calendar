import SwiftUI
import WidgetKit

// 앱(Dart)이 써 둔 자료를 읽는 부분. 키 이름은 lib/widget_sync.dart 와 같아요.

let kGroup = "group.com.isla0x.yeobaek"

struct EventS: Codable {
    var t: String
    var s: Double
    var e: Double
    var allDay: Bool
    var c: String
    var todo: Bool?
    var start: Date { Date(timeIntervalSince1970: s / 1000) }
    var end: Date { Date(timeIntervalSince1970: e / 1000) }
}

struct SpanS: Codable {
    var s: Double
    var e: Double
    var start: Date { Date(timeIntervalSince1970: s / 1000) }
    var end: Date { Date(timeIntervalSince1970: e / 1000) }
}

struct DayS: Codable {
    var date: String
    var wd: String
    var hol: String?
    var events: [EventS]
    var busy: [SpanS]
    var gaps: [SpanS]
    var free: Int
}

struct TodoS: Codable {
    var id: String
    var t: String
    var m: Int
    var done: Bool
    var due: String?
    var at: Double?
    var plan: Bool
    var atDate: Date? { at.map { Date(timeIntervalSince1970: $0 / 1000) } }
}

struct CheckS: Codable {
    var t: String
    var dday: Int
}

struct ProjS: Codable {
    var name: String
    var c: String
    var start: String
    var end: String
    var dday: Int
    var n: Int
    var total: Int
    var left: Int
    var upcoming: Bool
    var cp: CheckS?
}

struct Snap: Codable {
    var today: String
    var dayStart: Int
    var dayEnd: Int
    var days: [DayS]
    var todos: [TodoS]
    var projects: [ProjS]
}

// MARK: - 날짜 도우미

enum Fmt {
    static let ymd: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static let hm: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    static func time(_ d: Date) -> String { hm.string(from: d) }
    static func day(_ d: Date) -> String { ymd.string(from: d) }

    /// "3시간 50분" / "1시간" / "20분"
    static func dur(_ minutes: Int) -> String {
        let m = max(0, minutes)
        let h = m / 60
        let r = m % 60
        if h == 0 { return "\(r)분" }
        if r == 0 { return "\(h)시간" }
        return "\(h)시간 \(r)분"
    }

    static func hours(_ minutes: Int) -> String {
        let v = Double(minutes) / 60.0
        if abs(v - v.rounded()) < 0.05 { return "\(Int(v.rounded()))" }
        return String(format: "%.1f", v)
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - 계산

struct Upcoming {
    var event: EventS
    var inProgress: Bool
    var dayLabel: String
}

extension Snap {
    static func load() -> Snap? {
        guard let raw = UserDefaults(suiteName: kGroup)?.string(forKey: "snapshot"),
              let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Snap.self, from: data)
    }

    func day(on d: Date) -> DayS? {
        let key = Fmt.day(d)
        return days.first { $0.date == key }
    }

    /// 그날 보여줄 시간 범위
    func window(on d: Date) -> (Date, Date) {
        let cal = Calendar.current
        let a = cal.date(bySettingHour: dayStart, minute: 0, second: 0, of: d) ?? d
        let b = cal.date(bySettingHour: dayEnd, minute: 0, second: 0, of: d) ?? d
        return (a, b)
    }

    /// 오늘 남은 여유(분): [지금, 하루 끝] 에서 일정이 차지한 시간을 뺀 것
    func freeLeft(now: Date) -> Int {
        guard let day = day(on: now) else { return 0 }
        let (w0, w1) = window(on: now)
        let from = max(now, w0)
        if !w1.timeIntervalSince(from).isFinite || w1 <= from { return 0 }
        var busy = 0.0
        for b in day.busy {
            let s = max(b.start, from)
            let e = min(b.end, w1)
            if e > s { busy += e.timeIntervalSince(s) }
        }
        return max(0, Int((w1.timeIntervalSince(from) - busy) / 60))
    }

    /// 지금 이후 첫 빈 시간 (오늘)
    func nextGap(now: Date) -> (Date, Date)? {
        guard let day = day(on: now) else { return nil }
        for g in day.gaps where g.end > now {
            let s = max(g.start, now)
            if g.end.timeIntervalSince(s) >= 25 * 60 { return (s, g.end) }
        }
        return nil
    }

    /// 진행 중이거나 곧 시작하는 일정부터 몇 개
    func upcoming(now: Date, limit: Int) -> [Upcoming] {
        var out: [Upcoming] = []
        let cal = Calendar.current
        for d in days {
            for e in d.events where !e.allDay && e.end > now {
                let inProg = e.start <= now
                let label: String
                if cal.isDate(e.start, inSameDayAs: now) {
                    label = "오늘"
                } else if let tomorrow = cal.date(byAdding: .day, value: 1, to: now),
                          cal.isDate(e.start, inSameDayAs: tomorrow) {
                    label = "내일"
                } else {
                    label = d.wd
                }
                out.append(Upcoming(event: e, inProgress: inProg, dayLabel: label))
            }
        }
        out.sort { $0.event.start < $1.event.start }
        return Array(out.prefix(limit))
    }

    static func sample(now: Date) -> Snap {
        let cal = Calendar.current
        func at(_ h: Int, _ m: Int = 0) -> Double {
            (cal.date(bySettingHour: h, minute: m, second: 0, of: now) ?? now).timeIntervalSince1970 * 1000
        }
        var days: [DayS] = []
        let names = ["일", "월", "화", "수", "목", "금", "토"]
        let free = [230, 540, 330, 510, 250, 660, 660]
        for i in 0..<7 {
            let d = cal.date(byAdding: .day, value: i, to: now) ?? now
            let w = cal.component(.weekday, from: d) - 1
            let events: [EventS] = i == 0 ? [
                EventS(t: "스프린트 플래닝", s: at(14, 30), e: at(15, 30), allDay: false, c: "#79CDB1", todo: nil),
                EventS(t: "팀 회의", s: at(17, 0), e: at(18, 0), allDay: false, c: "#EF9ABC", todo: nil),
            ] : []
            let busy: [SpanS] = events.map { SpanS(s: $0.s, e: $0.e) }
            let gaps: [SpanS] = i == 0 ? [SpanS(s: at(15, 30), e: at(17, 0)), SpanS(s: at(18, 0), e: at(22, 0))] : []
            days.append(DayS(date: Fmt.day(d), wd: names[w], hol: nil, events: events, busy: busy, gaps: gaps, free: free[i]))
        }
        return Snap(
            today: Fmt.day(now), dayStart: 9, dayEnd: 22, days: days,
            todos: [
                TodoS(id: "1", t: "치과 예약 전화", m: 10, done: true, due: nil, at: at(10, 40), plan: false),
                TodoS(id: "2", t: "영어 공부", m: 30, done: false, due: nil, at: at(14, 30), plan: false),
                TodoS(id: "3", t: "운동", m: 60, done: false, due: nil, at: at(15, 30), plan: false),
            ],
            projects: [
                ProjS(name: "신규 서비스 런칭", c: "#909FEA", start: Fmt.day(now), end: Fmt.day(now),
                      dday: 18, n: 1, total: 15, left: 14, upcoming: false, cp: CheckS(t: "중간 보고", dday: 11)),
            ]
        )
    }
}

// MARK: - 타임라인(시간표) 공급

struct Entry: TimelineEntry {
    let date: Date
    let snap: Snap?
    let isSample: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), snap: Snap.sample(now: Date()), isSample: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let now = Date()
        if context.isPreview {
            completion(Entry(date: now, snap: Snap.sample(now: now), isSample: true))
        } else {
            completion(Entry(date: now, snap: Snap.load(), isSample: false))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date()
        let snap = Snap.load()
        var stamps = Set<TimeInterval>()
        stamps.insert(now.timeIntervalSince1970)
        // 15분마다 (남은 여유 글자가 너무 오래 어긋나지 않게)
        for i in 1...48 {
            stamps.insert(now.addingTimeInterval(Double(i) * 15 * 60).timeIntervalSince1970)
        }
        // 일정이 시작·끝나는 순간
        if let snap {
            for d in snap.days.prefix(2) {
                for e in d.events where !e.allDay {
                    if e.start > now { stamps.insert(e.start.timeIntervalSince1970) }
                    if e.end > now { stamps.insert(e.end.timeIntervalSince1970) }
                }
            }
        }
        let sorted = stamps.sorted().prefix(70)
        let entries = sorted.map { Entry(date: Date(timeIntervalSince1970: $0), snap: snap, isSample: false) }
        let last = entries.last?.date ?? now
        completion(Timeline(entries: entries, policy: .after(last)))
    }
}
