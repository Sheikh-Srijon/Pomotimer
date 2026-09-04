import AppKit
import Combine
import Foundation

enum TimerSection: String, Codable, CaseIterable {
    case stopwatch
    case timer
}

enum PanelBehavior: String, Codable, CaseIterable, Identifiable {
    case autoHide
    case stayActive
    case alwaysOnTop

    var id: Self { self }

    var title: String {
        switch self {
        case .autoHide: "Auto Hide"
        case .stayActive: "Stay Active"
        case .alwaysOnTop: "Always on Top"
        }
    }

    var symbol: String {
        switch self {
        case .autoHide: "gearshape"
        case .stayActive: "pin"
        case .alwaysOnTop: "square.on.square"
        }
    }
}

@MainActor
final class TimekeepingModel: ObservableObject {
    struct Snapshot: Codable {
        var section: TimerSection = .stopwatch
        var behavior: PanelBehavior = .autoHide
        var stopwatchAccumulated: TimeInterval = 0
        var stopwatchStartedAt: Date?
        var timerDuration: TimeInterval = 25 * 60
        var timerRemaining: TimeInterval = 25 * 60
        var timerEndsAt: Date?
    }

    @Published var section: TimerSection { didSet { persist() } }
    @Published var behavior: PanelBehavior { didSet { persist() } }
    @Published private(set) var stopwatchAccumulated: TimeInterval
    @Published private(set) var stopwatchStartedAt: Date?
    @Published var timerDuration: TimeInterval { didSet { persist() } }
    @Published var hideCountdownWhenIdle = false
    @Published private(set) var timerRemaining: TimeInterval
    @Published private(set) var timerEndsAt: Date?
    @Published private(set) var now: Date
    @Published var completionMessage: String?

    private let defaults: UserDefaults
    private let storageKey = "TimekeepingSnapshot.v1"
    private var ticker: AnyCancellable?

    init(defaults: UserDefaults = .standard, now: Date = Date()) {
        self.defaults = defaults
        self.now = now

        let snapshot: Snapshot
        if let data = defaults.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = stored
        } else {
            snapshot = Snapshot()
        }

        section = snapshot.section
        behavior = snapshot.behavior
        stopwatchAccumulated = snapshot.stopwatchAccumulated
        stopwatchStartedAt = snapshot.stopwatchStartedAt
        timerDuration = snapshot.timerDuration
        timerRemaining = snapshot.timerRemaining
        timerEndsAt = snapshot.timerEndsAt

        reconcile(at: now, notify: false)
        ticker = Timer.publish(every: 0.03, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.tick(at: date) }
    }

    var isStopwatchRunning: Bool { stopwatchStartedAt != nil }
    var isTimerRunning: Bool { timerEndsAt != nil }

    var stopwatchElapsed: TimeInterval {
        stopwatchAccumulated + (stopwatchStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    var displayedTimerRemaining: TimeInterval {
        guard let timerEndsAt else { return max(0, timerRemaining) }
        return max(0, timerEndsAt.timeIntervalSince(now))
    }

    func toggleStopwatch() {
        if let startedAt = stopwatchStartedAt {
            stopwatchAccumulated += max(0, now.timeIntervalSince(startedAt))
            stopwatchStartedAt = nil
        } else {
            stopwatchStartedAt = now
        }
        objectWillChange.send()
        persist()
    }

    func resetStopwatch() {
        stopwatchAccumulated = 0
        stopwatchStartedAt = isStopwatchRunning ? now : nil
        persist()
    }

    func setTimerDuration(hours: Int, minutes: Int, seconds: Int) {
        let total = TimeInterval(max(0, hours) * 3_600 + max(0, minutes) * 60 + max(0, seconds))
        setTimerDuration(total)
    }

    func setTimerDuration(_ duration: TimeInterval) {
        guard !isTimerRunning else { return }
        let total = min(max(0, duration.rounded(.down)), 86_399)
        timerDuration = total
        timerRemaining = total
        completionMessage = nil
        persist()
    }

    func adjustTimer(by offset: TimeInterval) {
        guard !isTimerRunning else { return }
        setTimerDuration(timerRemaining + offset)
    }

    static func parseTimerDuration(_ text: String) -> TimeInterval? {
        let parts = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false)
        let values = parts.compactMap { Int($0) }

        guard parts.count == 2 || parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              values.count == parts.count else {
            return nil
        }

        let hours: Int
        let minutes: Int
        let seconds: Int
        if values.count == 2 {
            hours = 0
            minutes = values[0]
            seconds = values[1]
        } else {
            hours = values[0]
            minutes = values[1]
            seconds = values[2]
        }

        guard hours < 24,
              minutes >= 0,
              seconds >= 0,
              seconds < 60,
              values.count == 2 || minutes < 60 else {
            return nil
        }

        let total = hours * 3_600 + minutes * 60 + seconds
        guard total <= 86_399 else { return nil }
        return TimeInterval(total)
    }

    func toggleTimer() {
        completionMessage = nil
        if let end = timerEndsAt {
            timerRemaining = max(0, end.timeIntervalSince(now))
            timerEndsAt = nil
        } else {
            if timerRemaining <= 0 { timerRemaining = timerDuration }
            guard timerRemaining > 0 else { return }
            timerEndsAt = now.addingTimeInterval(timerRemaining)
        }
        persist()
    }

    func resetTimer() {
        timerEndsAt = nil
        setTimerDuration(0)
    }

    func tick(at date: Date) {
        now = date
        reconcile(at: date, notify: true)
    }

    func persist() {
        let remaining = timerEndsAt.map { max(0, $0.timeIntervalSince(now)) } ?? timerRemaining
        let snapshot = Snapshot(
            section: section,
            behavior: behavior,
            stopwatchAccumulated: stopwatchAccumulated,
            stopwatchStartedAt: stopwatchStartedAt,
            timerDuration: timerDuration,
            timerRemaining: remaining,
            timerEndsAt: timerEndsAt
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func reconcile(at date: Date, notify: Bool) {
        guard let end = timerEndsAt, end <= date else { return }
        timerEndsAt = nil
        timerRemaining = 0
        completionMessage = "Timer complete"
        persist()
        guard notify else { return }
        NSSound(named: "Glass")?.play()
        NSApp.requestUserAttention(.informationalRequest)
    }
}
