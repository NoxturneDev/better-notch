import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class TimerService {
    enum Mode: String, CaseIterable {
        case countdown
        case stopwatch
        case pomodoro
    }

    enum PomodoroPhase {
        case focus
        case rest
    }

    var mode: Mode = .countdown {
        didSet {
            if oldValue != mode {
                reset()
            }
        }
    }

    var countdownLength: TimeInterval = 300
    private(set) var isRunning = false
    private(set) var didFinish = false
    private(set) var pomodoroPhase: PomodoroPhase = .focus
    private(set) var completedFocusCount = 0

    private var endDate: Date?
    private var pausedRemaining: TimeInterval?
    private var startDate: Date?
    private var accumulated: TimeInterval = 0
    private var finishTask: Task<Void, Never>?

    func remaining(at now: Date) -> TimeInterval {
        switch mode {
        case .countdown:
            if isRunning {
                guard let end = endDate else { return countdownLength }
                return max(0, end.timeIntervalSince(now))
            } else if let paused = pausedRemaining {
                return max(0, paused)
            } else {
                return countdownLength
            }
        case .pomodoro:
            if isRunning {
                guard let end = endDate else { return currentPomodoroLength }
                return max(0, end.timeIntervalSince(now))
            } else if let paused = pausedRemaining {
                return max(0, paused)
            } else {
                return currentPomodoroLength
            }
        case .stopwatch:
            return 0
        }
    }

    func elapsed(at now: Date) -> TimeInterval {
        if isRunning {
            guard let start = startDate else { return accumulated }
            return accumulated + now.timeIntervalSince(start)
        } else {
            return accumulated
        }
    }

    private var currentPomodoroLength: TimeInterval {
        switch pomodoroPhase {
        case .focus:
            return 1500 // 25 min
        case .rest:
            return (completedFocusCount > 0 && completedFocusCount % 4 == 0) ? 900 : 300 // 15 min or 5 min
        }
    }

    func setCountdownLength(_ length: TimeInterval) {
        guard !isRunning else { return }
        countdownLength = min(5400, max(60, length))
        didFinish = false
        pausedRemaining = nil
    }

    func adjustCountdown(by delta: TimeInterval) {
        setCountdownLength(countdownLength + delta)
    }

    func start() {
        guard !isRunning else { return }
        didFinish = false
        isRunning = true

        switch mode {
        case .countdown:
            let seconds = pausedRemaining ?? countdownLength
            pausedRemaining = nil
            endDate = Date().addingTimeInterval(seconds)
            scheduleFinish(after: seconds)
        case .pomodoro:
            let seconds = pausedRemaining ?? currentPomodoroLength
            pausedRemaining = nil
            endDate = Date().addingTimeInterval(seconds)
            scheduleFinish(after: seconds)
        case .stopwatch:
            startDate = Date()
        }
    }

    func pause() {
        guard isRunning else { return }
        finishTask?.cancel()
        finishTask = nil
        isRunning = false

        switch mode {
        case .countdown, .pomodoro:
            pausedRemaining = remaining(at: Date())
            endDate = nil
        case .stopwatch:
            if let start = startDate {
                accumulated += Date().timeIntervalSince(start)
            }
            startDate = nil
        }
    }

    func reset() {
        finishTask?.cancel()
        finishTask = nil
        isRunning = false
        didFinish = false
        endDate = nil
        pausedRemaining = nil
        startDate = nil
        accumulated = 0
        if mode == .pomodoro {
            pomodoroPhase = .focus
            completedFocusCount = 0
        }
    }

    private func scheduleFinish(after seconds: TimeInterval) {
        finishTask?.cancel()
        finishTask = Task { [weak self] in
            try? await Task.sleep(until: .now + .seconds(seconds), clock: .continuous)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private func finish() {
        NSSound(named: "Glass")?.play()

        switch mode {
        case .countdown:
            isRunning = false
            didFinish = true
            endDate = nil
            pausedRemaining = 0
        case .pomodoro:
            switch pomodoroPhase {
            case .focus:
                completedFocusCount += 1
                pomodoroPhase = .rest
            case .rest:
                pomodoroPhase = .focus
            }
            let nextSeconds = currentPomodoroLength
            endDate = Date().addingTimeInterval(nextSeconds)
            pausedRemaining = nil
            scheduleFinish(after: nextSeconds)
        case .stopwatch:
            break
        }
    }

    func closedLabel(at now: Date) -> String? {
        guard isRunning else { return nil }
        let seconds: Int
        switch mode {
        case .countdown, .pomodoro:
            seconds = Int(ceil(remaining(at: now)))
        case .stopwatch:
            seconds = Int(elapsed(at: now))
        }
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var closedLabel: String? {
        closedLabel(at: Date())
    }
}
