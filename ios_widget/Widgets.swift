import SwiftUI
import WidgetKit

// MARK: - 색

struct Look {
    let dark: Bool
    var bg: Color { dark ? Color(hex: "#1F2029") : Color(hex: "#FAF7F2") }
    var ink: Color { dark ? Color(hex: "#F1F1F6") : Color(hex: "#2B2D42") }
    var muted: Color { dark ? Color(hex: "#A4A6B8") : Color(hex: "#7D7F92") }
    var soft: Color { dark ? Color(hex: "#2C2E3A") : Color(hex: "#F2EEE7") }
    var good: Color { dark ? Color(hex: "#7FD3B2") : Color(hex: "#3A8F70") }
    var goodBg: Color { dark ? Color(hex: "#25392F") : Color(hex: "#EEF8F3") }
    var dash: Color { dark ? Color(hex: "#5A5D70") : Color(hex: "#A9D5C4") }
    var busy: Color { dark ? Color(hex: "#4A4D5E") : Color(hex: "#D5D0C6") }
    var now: Color { dark ? Color(hex: "#F4A58F") : Color(hex: "#E2705A") }
    var accent: Color { Color(hex: "#909FEA") }
    var chip: Color { dark ? Color(hex: "#34374A") : Color(hex: "#E4E8FB") }
}

extension View {
    func widgetBG(_ c: Color) -> some View {
        containerBackground(c, for: .widget)
    }
}

// MARK: - 공통 조각

struct NeedApp: View {
    let look: Look
    var body: some View {
        VStack(spacing: 6) {
            Text(tr("여백"))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(look.ink)
            Text(tr("앱을 한 번 열면\n여기에 보여요"))
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(look.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct Chip: View {
    let look: Look
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(look.ink)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(look.chip)
            .clipShape(Capsule())
    }
}

/// "20분 후" 처럼 살아 있는 글자
struct UntilText: View {
    let start: Date
    let inProgress: Bool
    let look: Look
    var body: some View {
        if inProgress {
            Chip(look: look, text: tr("진행 중"))
        } else {
            HStack(spacing: 0) {
                Text(Lx.untilPre)
                Text(start, style: .relative)
                Text(Lx.untilSuf)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(look.ink)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(look.chip)
            .clipShape(Capsule())
            .lineLimit(1)
        }
    }
}

/// 하루 막대: 일정은 색, 비는 시간은 점선, 지금은 빨간 선
struct DayBar: View {
    let snap: Snap
    let now: Date
    let look: Look
    var height: CGFloat = 38
    var showEvents = true

    var win: (Date, Date) { snap.window(on: now) }

    func x(_ d: Date, _ w: CGFloat) -> CGFloat {
        let span = max(1, win.1.timeIntervalSince(win.0))
        let f = d.timeIntervalSince(win.0) / span
        return CGFloat(min(1, max(0, f))) * w
    }

    func block(_ a: Date, _ b: Date, _ w: CGFloat) -> (CGFloat, CGFloat) {
        let left = x(a, w)
        return (left, max(3, x(b, w) - left))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8).fill(look.soft)
                if let day = snap.day(on: now) {
                    blocks(day: day, w: geo.size.width)
                }
                if now >= win.0 && now <= win.1 {
                    Rectangle()
                        .fill(look.now)
                        .frame(width: 2, height: height + 10)
                        .offset(x: x(now, geo.size.width) - 1, y: -5)
                }
            }
            .frame(height: height)
        }
        .frame(height: height)
    }

    @ViewBuilder
    func blocks(day: DayS, w: CGFloat) -> some View {
        if showEvents {
            ForEach(Array(day.events.filter { !$0.allDay }.enumerated()), id: \.offset) { _, e in
                let r = block(e.start, e.end, w)
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: e.c))
                    .frame(width: r.1, height: height)
                    .offset(x: r.0)
            }
        } else {
            ForEach(Array(day.busy.enumerated()), id: \.offset) { _, b in
                let r = block(b.start, b.end, w)
                RoundedRectangle(cornerRadius: 5)
                    .fill(look.busy)
                    .frame(width: r.1, height: height)
                    .offset(x: r.0)
            }
        }
        ForEach(Array(day.gaps.filter { $0.end > now }.enumerated()), id: \.offset) { _, g in
            let r = block(max(g.start, now), g.end, w)
            RoundedRectangle(cornerRadius: 5)
                .fill(look.goodBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                )
                .frame(width: r.1, height: height)
                .offset(x: r.0)
        }
    }
}

// MARK: - ① 오늘의 여백 (작은)

struct TodayView: View {
    let entry: Entry
    @Environment(\.colorScheme) var scheme

    var body: some View {
        let look = Look(dark: scheme == .dark)
        Group {
            if let snap = entry.snap {
                let left = snap.freeLeft(now: entry.date)
                let next = snap.upcoming(now: entry.date, limit: 1).first
                VStack(alignment: .leading, spacing: 0) {
                    Text(tr("오늘 남은 여유"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(look.muted)
                    Text(Fmt.dur(left))
                        .font(.system(size: 25, weight: .bold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .foregroundColor(look.good)
                        .padding(.top, 2)
                    DayBar(snap: snap, now: entry.date, look: look, height: 10, showEvents: false)
                        .padding(.top, 8)
                    Spacer(minLength: 4)
                    if let next {
                        UntilText(start: next.event.start, inProgress: next.inProgress, look: look)
                        Text(next.event.t)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(look.ink)
                            .lineLimit(1)
                            .padding(.top, 4)
                    } else {
                        Text(tr("남은 일정이 없어요"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(look.ink)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                NeedApp(look: look)
            }
        }
        .padding(16)
        .widgetBG(look.bg)
        .widgetURL(URL(string: "yeobaek://today"))
    }
}

struct TodayWidget: Widget {
    let kind = "YeobaekToday"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { TodayView(entry: $0) }
            .configurationDisplayName(tr("오늘의 여백"))
            .description(tr("오늘 남은 여유 시간과 다음 일정이 보여요."))
            .supportedFamilies([.systemSmall])
            .contentMarginsDisabled()
    }
}

// MARK: - ② 하루 타임라인 (중간)

struct TimelineView2: View {
    let entry: Entry
    @Environment(\.colorScheme) var scheme

    var body: some View {
        let look = Look(dark: scheme == .dark)
        Group {
            if let snap = entry.snap {
                let now = entry.date
                let cal = Calendar.current
                let title = tr("오늘 · {0}/{1} {2}", "\(cal.component(.month, from: now))", "\(cal.component(.day, from: now))", Lx.wdShort[max(0, min(6, cal.component(.weekday, from: now) - 1))])
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(look.ink)
                        Spacer()
                        Text(tr("남은 여유 {0}", Fmt.dur(snap.freeLeft(now: now))))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(look.good)
                    }
                    DayBar(snap: snap, now: now, look: look, height: 38)
                        .padding(.top, 12)
                    HStack {
                        ForEach([9, 12, 15, 18, 21], id: \.self) { h in
                            Text("\(h)")
                            if h != 21 { Spacer() }
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundColor(look.muted)
                    .padding(.top, 8)
                    Spacer(minLength: 6)
                    gapRow(snap: snap, now: now, look: look)
                }
            } else {
                NeedApp(look: look)
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .widgetBG(look.bg)
        .widgetURL(URL(string: "yeobaek://today"))
    }

    @ViewBuilder
    func gapRow(snap: Snap, now: Date, look: Look) -> some View {
        if let g = snap.nextGap(now: now) {
            Link(destination: URL(string: "yeobaek://add?from=\(Int(g.0.timeIntervalSince1970 * 1000))")!) {
                HStack {
                    Text(tr("다음 빈 시간 {0}–{1}", Fmt.time(g.0), Fmt.time(g.1)))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(look.good)
                        .lineLimit(1)
                    Spacer()
                    Text(tr("+ 추가"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(look.ink)
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .background(RoundedRectangle(cornerRadius: 14).fill(look.goodBg))
                )
            }
        } else {
            Text(tr("오늘은 더 비는 시간이 없어요"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(look.muted)
                .frame(maxWidth: .infinity, minHeight: 40)
        }
    }
}

struct TimelineWidget: Widget {
    let kind = "YeobaekTimeline"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { TimelineView2(entry: $0) }
            .configurationDisplayName(tr("하루 타임라인"))
            .description(tr("오늘 일정과 비는 시간을 한 줄로 보고, 빈 시간에 바로 추가해요."))
            .supportedFamilies([.systemMedium])
            .contentMarginsDisabled()
    }
}

// MARK: - ③ 프로젝트 (중간)

struct ProjectView: View {
    let entry: Entry
    @Environment(\.colorScheme) var scheme

    var body: some View {
        let look = Look(dark: scheme == .dark)
        Group {
            if let snap = entry.snap, let p = snap.projects.first {
                HStack(spacing: 16) {
                    ring(p: p, look: look)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(p.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(look.ink)
                            .lineLimit(1)
                        Text(tr("{0} – {1} · 남은 근무일 {2}일", shortDate(p.start), shortDate(p.end), "\(p.left)"))
                            .font(.system(size: 12))
                            .foregroundColor(look.muted)
                            .lineLimit(1)
                            .padding(.top, 2)
                        cells(p: p, look: look)
                            .padding(.top, 10)
                        if let cp = p.cp {
                            HStack {
                                Text(cp.t)
                                Spacer()
                                Text(cp.dday == 0 ? "D-day" : "D-\(cp.dday)")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(look.ink)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(look.chip)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.top, 10)
                        }
                    }
                }
            } else if entry.snap != nil {
                VStack(spacing: 6) {
                    Text(tr("진행 중인 프로젝트가 없어요"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(look.ink)
                    Text(tr("눌러서 프로젝트 만들기"))
                        .font(.system(size: 12))
                        .foregroundColor(look.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NeedApp(look: look)
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .widgetBG(look.bg)
        .widgetURL(URL(string: "yeobaek://projects"))
    }

    func shortDate(_ ymd: String) -> String {
        let parts = ymd.split(separator: "-")
        guard parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) else { return ymd }
        return "\(m)/\(d)"
    }

    func ring(p: ProjS, look: Look) -> some View {
        let frac = p.total == 0 ? 0 : min(1, max(0, Double(p.n) / Double(p.total)))
        let big = p.dday > 0 ? "D-\(p.dday)" : (p.dday == 0 ? "D-day" : "D+\(-p.dday)")
        let small = p.upcoming ? tr("시작 전") : tr("{0}일째", "\(p.n)")
        return ZStack {
            Circle().stroke(look.chip, lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(0.02, frac))
                .stroke(Color(hex: p.c), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(big)
                    .font(.system(size: 22, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundColor(look.ink)
                Text(small)
                    .font(.system(size: 11))
                    .foregroundColor(look.muted)
            }
            .padding(.horizontal, 12)
        }
        .frame(width: 100, height: 100)
    }

    func cells(p: ProjS, look: Look) -> some View {
        let n = min(15, max(1, p.total))
        let filled = p.total == 0 ? 0 : Int((Double(p.n) / Double(p.total) * Double(n)).rounded(.up))
        return HStack(spacing: 2) {
            ForEach(0..<n, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(i < filled ? Color(hex: p.c) : look.chip)
                    .frame(height: 12)
            }
        }
    }
}

struct ProjectWidget: Widget {
    let kind = "YeobaekProject"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { ProjectView(entry: $0) }
            .configurationDisplayName(tr("프로젝트"))
            .description(tr("가장 먼저 끝나는 프로젝트의 D-day와 진행 상황이 보여요."))
            .supportedFamilies([.systemMedium])
            .contentMarginsDisabled()
    }
}

// MARK: - ④ 할 일 (중간)

struct TodoView: View {
    let entry: Entry
    @Environment(\.colorScheme) var scheme

    var body: some View {
        let look = Look(dark: scheme == .dark)
        Group {
            if let snap = entry.snap {
                let rows = ordered(snap.todos, now: entry.date)
                let left = snap.todos.filter { !$0.done }.count
                let unplaced = snap.todos.filter { !$0.done && $0.plan }.count
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(tr("오늘 할 일"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(look.ink)
                        Spacer()
                        Text(left == 0 ? tr("다 했어요") : tr("{0}개 남음", "\(left)"))
                            .font(.system(size: 12))
                            .foregroundColor(look.muted)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(rows.prefix(3).enumerated()), id: \.offset) { _, t in
                            row(t, look: look, now: entry.date)
                        }
                    }
                    .padding(.top, 6)
                    Spacer(minLength: 4)
                    if unplaced > 0 {
                        Text(tr("자리 못 찾은 할 일 {0}개 · 눌러서 자리 찾기", "\(unplaced)"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(look.good)
                            .lineLimit(1)
                    } else if rows.isEmpty {
                        Text(tr("할 일이 없어요"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(look.muted)
                    }
                }
            } else {
                NeedApp(look: look)
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .widgetBG(look.bg)
        .widgetURL(URL(string: "yeobaek://todos"))
    }

    /// 오늘 자리가 있는 것 → 자리 없는 것 → 끝낸 것
    func ordered(_ todos: [TodoS], now: Date) -> [TodoS] {
        let cal = Calendar.current
        func today(_ t: TodoS) -> Bool {
            if let d = t.atDate { return cal.isDate(d, inSameDayAs: now) }
            return false
        }
        let a = todos.filter { !$0.done && today($0) }.sorted { ($0.at ?? 0) < ($1.at ?? 0) }
        let b = todos.filter { !$0.done && !today($0) }
        let c = todos.filter { $0.done }
        return a + b + c
    }

    func row(_ t: TodoS, look: Look, now: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: t.done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundColor(t.done ? look.good : look.muted)
            Text(t.t)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(t.done ? look.muted : look.ink)
                .strikethrough(t.done)
                .lineLimit(1)
            Spacer()
            Text(sub(t, now: now))
                .font(.system(size: 12))
                .foregroundColor(look.muted)
        }
        .frame(height: 30)
    }

    func sub(_ t: TodoS, now: Date) -> String {
        if let d = t.atDate {
            if Calendar.current.isDate(d, inSameDayAs: now) { return Fmt.time(d) }
            let c = Calendar.current.dateComponents([.month, .day], from: d)
            return "\(c.month ?? 0)/\(c.day ?? 0)"
        }
        if let due = t.due {
            let parts = due.split(separator: "-")
            if parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) { return tr("{0}/{1}까지", "\(m)", "\(d)") }
        }
        return Fmt.dur(t.m)
    }
}

struct TodoWidget: Widget {
    let kind = "YeobaekTodos"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { TodoView(entry: $0) }
            .configurationDisplayName(tr("할 일"))
            .description(tr("오늘 할 일과 정해진 시각이 보여요."))
            .supportedFamilies([.systemMedium])
            .contentMarginsDisabled()
    }
}

// MARK: - ⑤ 이번 주 여유 (큰)

struct WeekView2: View {
    let entry: Entry
    @Environment(\.colorScheme) var scheme

    var body: some View {
        let look = Look(dark: scheme == .dark)
        Group {
            if let snap = entry.snap {
                let days = Array(snap.days.prefix(7))
                let bestIdx = bestDay(days)
                let winMin = max(60, (snap.dayEnd - snap.dayStart) * 60)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(tr("이번 주 여유"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(look.ink)
                        Spacer()
                        Text(tr("하루 중 비는 시간"))
                            .font(.system(size: 12))
                            .foregroundColor(look.muted)
                    }
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                            bar(d, best: i == bestIdx, first: i == 0, winMin: winMin, look: look)
                        }
                    }
                    .padding(.top, 10)
                    if let bi = bestIdx {
                        Text(tr("가장 여유로운 날 · {0} {1}", days[bi].wdLong, Fmt.dur(days[bi].free)))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(look.good)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                            .background(look.goodBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.top, 10)
                    }
                    Text(tr("다음 일정"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(look.muted)
                        .padding(.top, 8)
                    ForEach(Array(snap.upcoming(now: entry.date, limit: 3).enumerated()), id: \.offset) { _, u in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 2).fill(Color(hex: u.event.c)).frame(width: 4, height: 24)
                            Text(u.event.t)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(look.ink)
                                .lineLimit(1)
                            Spacer()
                            Text("\(u.dayLabel) \(Fmt.time(u.event.start))")
                                .font(.system(size: 12))
                                .foregroundColor(look.muted)
                        }
                        .frame(height: 34)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                NeedApp(look: look)
            }
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 14, trailing: 16))
        .widgetBG(look.bg)
        .widgetURL(URL(string: "yeobaek://today"))
    }

    func bestDay(_ days: [DayS]) -> Int? {
        var best: Int?
        for (i, d) in days.enumerated() {
            // 주말은 늘 비니까 평일 중에서 골라요
            if d.wdIdx == 6 || d.wdIdx == 0 { continue }
            if best == nil || d.free > days[best!].free { best = i }
        }
        return best
    }

    func bar(_ d: DayS, best: Bool, first: Bool, winMin: Int, look: Look) -> some View {
        let frac = min(1, max(0.02, Double(d.free) / Double(winMin)))
        return VStack(spacing: 4) {
            Text(Fmt.hours(d.free))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(best ? look.good : look.muted)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 10).fill(look.soft)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(best ? look.good : look.dash)
                        .frame(height: geo.size.height * CGFloat(frac))
                }
            }
            .frame(height: 100)
            Text(d.wdShort)
                .font(.system(size: 12, weight: first ? .bold : .medium))
                .foregroundColor(d.wdIdx == 0 ? Color(hex: "#D67171") : (first ? look.ink : look.muted))
        }
        .frame(maxWidth: .infinity)
    }
}

struct WeekWidget: Widget {
    let kind = "YeobaekWeek"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { WeekView2(entry: $0) }
            .configurationDisplayName(tr("이번 주 여유"))
            .description(tr("요일마다 비는 시간과 다음 일정이 보여요."))
            .supportedFamilies([.systemLarge])
            .contentMarginsDisabled()
    }
}

// MARK: - ⑥ 잠금화면

struct LockView: View {
    let entry: Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if let snap = entry.snap {
                let now = entry.date
                let left = snap.freeLeft(now: now)
                let next = snap.upcoming(now: now, limit: 1).first
                switch family {
                case .accessoryCircular:
                    let total = max(1, (snap.dayEnd - snap.dayStart) * 60)
                    Gauge(value: Double(min(left, total)), in: 0...Double(total)) {
                        Text(tr("여유"))
                    } currentValueLabel: {
                        Text("\(left / 60):\(String(format: "%02d", left % 60))")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .gaugeStyle(.accessoryCircular)
                case .accessoryRectangular:
                    VStack(alignment: .leading, spacing: 1) {
                        if let next {
                            if next.inProgress {
                                Text(tr("진행 중")).font(.system(size: 11, weight: .bold))
                            } else {
                                HStack(spacing: 0) {
                                    Text(Lx.untilPre)
                                    Text(next.event.start, style: .relative)
                                    Text(Lx.untilSuf)
                                }
                                .font(.system(size: 11, weight: .bold))
                            }
                            Text(next.event.t).font(.system(size: 14, weight: .bold)).lineLimit(1)
                        } else {
                            Text(tr("남은 일정이 없어요")).font(.system(size: 14, weight: .bold))
                        }
                        if let g = snap.nextGap(now: now) {
                            Text(tr("다음 빈 시간 {0} · {1}", Fmt.time(g.0), Fmt.dur(Int(g.1.timeIntervalSince(g.0) / 60))))
                                .font(.system(size: 11))
                                .lineLimit(1)
                        } else {
                            Text(tr("남은 여유 {0}", Fmt.dur(left))).font(.system(size: 11))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                default:
                    Text(tr("남은 여유 {0}", Fmt.dur(left)))
                }
            } else {
                Text(tr("여백"))
            }
        }
        .widgetBG(.clear)
        .widgetURL(URL(string: "yeobaek://today"))
    }
}

struct LockWidget: Widget {
    let kind = "YeobaekLock"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { LockView(entry: $0) }
            .configurationDisplayName(tr("잠금화면 여유"))
            .description(tr("잠금화면에서 남은 여유와 다음 일정을 봐요."))
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - 묶음

@main
struct YeobaekWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        TimelineWidget()
        ProjectWidget()
        TodoWidget()
        WeekWidget()
        LockWidget()
    }
}
