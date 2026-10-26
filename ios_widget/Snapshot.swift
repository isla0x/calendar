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

    /// 요일 번호 (일요일 = 0). 글자는 폰 언어로 직접 만들어요.
    var wdIdx: Int {
        guard let d = Fmt.ymd.date(from: date) else { return 0 }
        return max(0, min(6, Calendar.current.component(.weekday, from: d) - 1))
    }
    var wdShort: String { Lx.wdShort[wdIdx] }
    var wdLong: String { Lx.wdLong[wdIdx] }
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
        if h == 0 { return tr("{0}분", "\(r)") }
        if r == 0 { return tr("{0}시간", "\(h)") }
        return tr("{0}시간 {1}분", "\(h)", "\(r)")
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
                    label = tr("오늘")
                } else if let tomorrow = cal.date(byAdding: .day, value: 1, to: now),
                          cal.isDate(e.start, inSameDayAs: tomorrow) {
                    label = tr("내일")
                } else {
                    label = d.wdShort
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
                EventS(t: tr("스프린트 플래닝"), s: at(14, 30), e: at(15, 30), allDay: false, c: "#79CDB1", todo: nil),
                EventS(t: tr("팀 회의"), s: at(17, 0), e: at(18, 0), allDay: false, c: "#EF9ABC", todo: nil),
            ] : []
            let busy: [SpanS] = events.map { SpanS(s: $0.s, e: $0.e) }
            let gaps: [SpanS] = i == 0 ? [SpanS(s: at(15, 30), e: at(17, 0)), SpanS(s: at(18, 0), e: at(22, 0))] : []
            days.append(DayS(date: Fmt.day(d), wd: names[w], hol: nil, events: events, busy: busy, gaps: gaps, free: free[i]))
        }
        return Snap(
            today: Fmt.day(now), dayStart: 9, dayEnd: 22, days: days,
            todos: [
                TodoS(id: "1", t: tr("치과 예약 전화"), m: 10, done: true, due: nil, at: at(10, 40), plan: false),
                TodoS(id: "2", t: tr("영어 공부"), m: 30, done: false, due: nil, at: at(14, 30), plan: false),
                TodoS(id: "3", t: tr("운동"), m: 60, done: false, due: nil, at: at(15, 30), plan: false),
            ],
            projects: [
                ProjS(name: tr("신규 서비스 런칭"), c: "#909FEA", start: Fmt.day(now), end: Fmt.day(now),
                      dday: 18, n: 1, total: 15, left: 14, upcoming: false, cp: CheckS(t: tr("중간 보고"), dday: 11)),
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


// MARK: - 언어

/// 폰 언어에 맞춘 글 (한국어·영어·프랑스어·중국어·일본어)
enum Lx {
    static let code: String = {
        let p = Locale.preferredLanguages.first ?? "en"
        if p.hasPrefix("ko") { return "ko" }
        if p.hasPrefix("fr") { return "fr" }
        if p.hasPrefix("zh") { return "zh" }
        if p.hasPrefix("ja") { return "ja" }
        return "en"
    }()

    static let wdShort: [String] = {
        switch code {
        case "ko": return ["일", "월", "화", "수", "목", "금", "토"]
        case "en": return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        case "fr": return ["dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."]
        case "zh": return ["日", "一", "二", "三", "四", "五", "六"]
        case "ja": return ["日", "月", "火", "水", "木", "金", "土"]
        default: return []
        }
    }()

    static let wdLong: [String] = {
        switch code {
        case "ko": return ["일요일", "월요일", "화요일", "수요일", "목요일", "금요일", "토요일"]
        case "en": return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        case "fr": return ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        case "zh": return ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        case "ja": return ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]
        default: return []
        }
    }()

    /// 남은 시간 글자 앞뒤: "20분 후" / "in 20 min" / "dans 20 min" / "20分钟后"
    static var untilPre: String { code == "en" ? "in " : (code == "fr" ? "dans " : "") }
    static var untilSuf: String { code == "ko" ? " 후" : (code == "zh" ? "后" : (code == "ja" ? "後" : "")) }

    static let table: [String: [String: String]] = [
        "en": [
            "여백": "Yeobaek",
            "앱을 한 번 열면\n여기에 보여요": "Open the app once\nand it shows up here",
            "진행 중": "In progress",
            "오늘 남은 여유": "Free time left today",
            "남은 일정이 없어요": "No events left",
            "오늘의 여백": "Today's Free Time",
            "오늘 남은 여유 시간과 다음 일정이 보여요.": "Shows your free time left today and your next event.",
            "오늘 · {0}/{1} {2}": "Today · {0}/{1} {2}",
            "남은 여유 {0}": "{0} free",
            "다음 빈 시간 {0}–{1}": "Next free {0}–{1}",
            "+ 추가": "+ Add",
            "오늘은 더 비는 시간이 없어요": "No more free time today",
            "하루 타임라인": "Day Timeline",
            "오늘 일정과 비는 시간을 한 줄로 보고, 빈 시간에 바로 추가해요.": "See today's events and free time in one line, and add to a free slot right away.",
            "{0} – {1} · 남은 근무일 {2}일": "{0} – {1} · {2} work days left",
            "진행 중인 프로젝트가 없어요": "No projects in progress",
            "눌러서 프로젝트 만들기": "Tap to create a project",
            "시작 전": "Not started",
            "{0}일째": "Day {0}",
            "프로젝트": "Project",
            "가장 먼저 끝나는 프로젝트의 D-day와 진행 상황이 보여요.": "Shows the D-day and progress of the project ending first.",
            "오늘 할 일": "Today's to-dos",
            "다 했어요": "All done",
            "{0}개 남음": "{0} left",
            "자리 못 찾은 할 일 {0}개 · 눌러서 자리 찾기": "{0} to-dos without a slot · tap to find one",
            "할 일이 없어요": "No to-dos",
            "{0}/{1}까지": "by {0}/{1}",
            "할 일": "To-dos",
            "오늘 할 일과 정해진 시각이 보여요.": "Shows today's to-dos and their set times.",
            "이번 주 여유": "Free Time This Week",
            "하루 중 비는 시간": "Free time per day",
            "가장 여유로운 날 · {0} {1}": "Freest day · {0} {1}",
            "다음 일정": "Next event",
            "요일마다 비는 시간과 다음 일정이 보여요.": "Shows free time for each day and your next events.",
            "여유": "Free",
            "다음 빈 시간 {0} · {1}": "Next free {0} · {1}",
            "잠금화면 여유": "Lock Screen Free Time",
            "잠금화면에서 남은 여유와 다음 일정을 봐요.": "See your free time left and next event on the Lock Screen.",
            "오늘": "Today",
            "내일": "Tomorrow",
            "{0}분": "{0} min",
            "{0}시간": "{0} hr",
            "{0}시간 {1}분": "{0} hr {1} min",
            "스프린트 플래닝": "Sprint planning",
            "팀 회의": "Team meeting",
            "치과 예약 전화": "Call the dentist",
            "영어 공부": "Study English",
            "운동": "Workout",
            "신규 서비스 런칭": "New service launch",
            "중간 보고": "Mid-point report",
        ],
        "fr": [
            "여백": "Yeobaek",
            "앱을 한 번 열면\n여기에 보여요": "Ouvrez l'app une fois\npour afficher ici",
            "진행 중": "En cours",
            "오늘 남은 여유": "Temps libre restant",
            "남은 일정이 없어요": "Plus d'événements",
            "오늘의 여백": "Le temps libre du jour",
            "오늘 남은 여유 시간과 다음 일정이 보여요.": "Affiche le temps libre restant et le prochain événement.",
            "오늘 · {0}/{1} {2}": "Aujourd’hui · {0}/{1} {2}",
            "남은 여유 {0}": "{0} libres",
            "다음 빈 시간 {0}–{1}": "Prochain créneau {0}–{1}",
            "+ 추가": "+ Ajouter",
            "오늘은 더 비는 시간이 없어요": "Plus de temps libre aujourd'hui",
            "하루 타임라인": "Chronologie du jour",
            "오늘 일정과 비는 시간을 한 줄로 보고, 빈 시간에 바로 추가해요.": "Voyez les événements et le temps libre du jour sur une ligne, et ajoutez directement dans un créneau libre.",
            "{0} – {1} · 남은 근무일 {2}일": "{0} – {1} · {2} jours ouvrés restants",
            "진행 중인 프로젝트가 없어요": "Aucun projet en cours",
            "눌러서 프로젝트 만들기": "Touchez pour créer un projet",
            "시작 전": "À venir",
            "{0}일째": "Jour {0}",
            "프로젝트": "Projet",
            "가장 먼저 끝나는 프로젝트의 D-day와 진행 상황이 보여요.": "Affiche le compte à rebours et l'avancement du projet qui se termine en premier.",
            "오늘 할 일": "Tâches du jour",
            "다 했어요": "Tout est fait",
            "{0}개 남음": "{0} restantes",
            "자리 못 찾은 할 일 {0}개 · 눌러서 자리 찾기": "{0} tâches sans créneau · touchez pour en trouver",
            "할 일이 없어요": "Aucune tâche",
            "{0}/{1}까지": "pour le {1}/{0}",
            "할 일": "Tâches",
            "오늘 할 일과 정해진 시각이 보여요.": "Affiche les tâches du jour et leurs horaires.",
            "이번 주 여유": "Temps libre de la semaine",
            "하루 중 비는 시간": "Temps libre par jour",
            "가장 여유로운 날 · {0} {1}": "Jour le plus libre · {0} {1}",
            "다음 일정": "Prochain événement",
            "요일마다 비는 시간과 다음 일정이 보여요.": "Affiche le temps libre de chaque jour et les prochains événements.",
            "여유": "Libre",
            "다음 빈 시간 {0} · {1}": "Prochain créneau {0} · {1}",
            "잠금화면 여유": "Temps libre (écran verrouillé)",
            "잠금화면에서 남은 여유와 다음 일정을 봐요.": "Voyez le temps libre restant et le prochain événement sur l'écran verrouillé.",
            "오늘": "Aujourd’hui",
            "내일": "Demain",
            "{0}분": "{0} min",
            "{0}시간": "{0} h",
            "{0}시간 {1}분": "{0} h {1} min",
            "스프린트 플래닝": "Planification du sprint",
            "팀 회의": "Réunion d’équipe",
            "치과 예약 전화": "Appeler le dentiste",
            "영어 공부": "Étudier l’anglais",
            "운동": "Sport",
            "신규 서비스 런칭": "Lancement du nouveau service",
            "중간 보고": "Rapport intermédiaire",
        ],
        "zh": [
            "여백": "Yeobaek",
            "앱을 한 번 열면\n여기에 보여요": "打开一次应用\n这里就会显示",
            "진행 중": "进行中",
            "오늘 남은 여유": "今天剩余空闲",
            "남은 일정이 없어요": "没有剩余日程",
            "오늘의 여백": "今日空闲",
            "오늘 남은 여유 시간과 다음 일정이 보여요.": "显示今天剩余的空闲时间和下一个日程。",
            "오늘 · {0}/{1} {2}": "今天 · {0}/{1} {2}",
            "남은 여유 {0}": "剩余空闲 {0}",
            "다음 빈 시간 {0}–{1}": "下个空档 {0}–{1}",
            "+ 추가": "+ 添加",
            "오늘은 더 비는 시간이 없어요": "今天没有更多空闲时间了",
            "하루 타임라인": "一日时间线",
            "오늘 일정과 비는 시간을 한 줄로 보고, 빈 시간에 바로 추가해요.": "一行查看今天的日程和空闲时间，并直接在空档添加。",
            "{0} – {1} · 남은 근무일 {2}일": "{0} – {1} · 剩余工作日 {2} 天",
            "진행 중인 프로젝트가 없어요": "没有进行中的项目",
            "눌러서 프로젝트 만들기": "点按创建项目",
            "시작 전": "未开始",
            "{0}일째": "第 {0} 天",
            "프로젝트": "项目",
            "가장 먼저 끝나는 프로젝트의 D-day와 진행 상황이 보여요.": "显示最先结束的项目的倒计时和进度。",
            "오늘 할 일": "今日待办",
            "다 했어요": "全部完成",
            "{0}개 남음": "剩余 {0} 项",
            "자리 못 찾은 할 일 {0}개 · 눌러서 자리 찾기": "有 {0} 项待办没找到时间 · 点按查找",
            "할 일이 없어요": "没有待办",
            "{0}/{1}까지": "{0}/{1} 前",
            "할 일": "待办",
            "오늘 할 일과 정해진 시각이 보여요.": "显示今天的待办和设定的时间。",
            "이번 주 여유": "本周空闲",
            "하루 중 비는 시간": "每天的空闲时间",
            "가장 여유로운 날 · {0} {1}": "最空闲的一天 · {0} {1}",
            "다음 일정": "下一个日程",
            "요일마다 비는 시간과 다음 일정이 보여요.": "显示每天的空闲时间和接下来的日程。",
            "여유": "空闲",
            "다음 빈 시간 {0} · {1}": "下个空档 {0} · {1}",
            "잠금화면 여유": "锁屏空闲",
            "잠금화면에서 남은 여유와 다음 일정을 봐요.": "在锁屏上查看剩余空闲和下一个日程。",
            "오늘": "今天",
            "내일": "明天",
            "{0}분": "{0}分钟",
            "{0}시간": "{0}小时",
            "{0}시간 {1}분": "{0}小时{1}分钟",
            "스프린트 플래닝": "迭代规划",
            "팀 회의": "团队会议",
            "치과 예약 전화": "给牙医打电话",
            "영어 공부": "学英语",
            "운동": "运动",
            "신규 서비스 런칭": "新服务上线",
            "중간 보고": "中期汇报",
        ],
        "ja": [
            "여백": "Yeobaek",
            "앱을 한 번 열면\n여기에 보여요": "アプリを一度開くと\nここに表示されます",
            "진행 중": "進行中",
            "오늘 남은 여유": "今日の残り余裕",
            "남은 일정이 없어요": "残りの予定はありません",
            "오늘의 여백": "今日の余白",
            "오늘 남은 여유 시간과 다음 일정이 보여요.": "今日の残りの余裕時間と次の予定を表示します。",
            "오늘 · {0}/{1} {2}": "今日 · {0}/{1} {2}",
            "남은 여유 {0}": "残り余裕 {0}",
            "다음 빈 시간 {0}–{1}": "次の空き {0}–{1}",
            "+ 추가": "+ 追加",
            "오늘은 더 비는 시간이 없어요": "今日はこれ以上空き時間がありません",
            "하루 타임라인": "一日タイムライン",
            "오늘 일정과 비는 시간을 한 줄로 보고, 빈 시간에 바로 추가해요.": "今日の予定と空き時間を一行で見て、空いている時間にすぐ追加できます。",
            "{0} – {1} · 남은 근무일 {2}일": "{0} – {1} · 残り勤務日 {2}日",
            "진행 중인 프로젝트가 없어요": "進行中のプロジェクトはありません",
            "눌러서 프로젝트 만들기": "タップしてプロジェクトを作成",
            "시작 전": "開始前",
            "{0}일째": "{0}日目",
            "프로젝트": "プロジェクト",
            "가장 먼저 끝나는 프로젝트의 D-day와 진행 상황이 보여요.": "最初に終わるプロジェクトの D-day と進み具合を表示します。",
            "오늘 할 일": "今日のタスク",
            "다 했어요": "すべて完了",
            "{0}개 남음": "残り {0} 件",
            "자리 못 찾은 할 일 {0}개 · 눌러서 자리 찾기": "時間が見つからないタスク {0}件 · タップして探す",
            "할 일이 없어요": "タスクはありません",
            "{0}/{1}까지": "{0}/{1}まで",
            "할 일": "タスク",
            "오늘 할 일과 정해진 시각이 보여요.": "今日のタスクと決まった時刻を表示します。",
            "이번 주 여유": "今週の余裕",
            "하루 중 비는 시간": "一日の空き時間",
            "가장 여유로운 날 · {0} {1}": "一番余裕のある日 · {0} {1}",
            "다음 일정": "次の予定",
            "요일마다 비는 시간과 다음 일정이 보여요.": "曜日ごとの空き時間と次の予定を表示します。",
            "여유": "余裕",
            "다음 빈 시간 {0} · {1}": "次の空き {0} · {1}",
            "잠금화면 여유": "ロック画面の余裕",
            "잠금화면에서 남은 여유와 다음 일정을 봐요.": "ロック画面で残りの余裕と次の予定を確認できます。",
            "오늘": "今日",
            "내일": "明日",
            "{0}분": "{0}分",
            "{0}시간": "{0}時間",
            "{0}시간 {1}분": "{0}時間{1}分",
            "스프린트 플래닝": "スプリント計画",
            "팀 회의": "チーム会議",
            "치과 예약 전화": "歯医者に電話",
            "영어 공부": "英語の勉強",
            "운동": "運動",
            "신규 서비스 런칭": "新サービスのローンチ",
            "중간 보고": "中間報告",
        ],
    ]
}

/// 한국어 원문을 폰 언어로. {0} {1} 자리에 [args] 가 들어가요.
func tr(_ ko: String, _ args: String...) -> String {
    var s = Lx.code == "ko" ? ko : (Lx.table[Lx.code]?[ko] ?? ko)
    for (i, a) in args.enumerated() { s = s.replacingOccurrences(of: "{\(i)}", with: a) }
    return s
}
