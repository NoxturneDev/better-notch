import SwiftUI

struct TimerView: View {
    @Bindable var service: TimerService

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $service.mode) {
                Text("Timer").tag(TimerService.Mode.countdown)
                Text("Stopwatch").tag(TimerService.Mode.stopwatch)
                Text("Pomodoro").tag(TimerService.Mode.pomodoro)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)

            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                VStack(spacing: 4) {
                    if service.mode == .countdown && service.didFinish {
                        Text("Done")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        let timeString = displayTime(at: timeline.date)
                        Text(timeString)
                            .font(.system(size: 34, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }

                    if service.mode == .pomodoro {
                        let phaseName = service.pomodoroPhase == .focus ? "Focus" : "Break"
                        Text("\(phaseName) • Completed: \(service.completedFocusCount)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }

            if service.mode == .countdown {
                HStack(spacing: 8) {
                    Button("−") { service.adjustCountdown(by: -60) }
                        .disabled(service.isRunning)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(service.isRunning ? 0.05 : 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    ForEach([5, 10, 15, 25], id: \.self) { mins in
                        Button("\(mins)m") {
                            service.setCountdownLength(TimeInterval(mins * 60))
                        }
                        .disabled(service.isRunning)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(service.isRunning ? 0.05 : 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Button("+") { service.adjustCountdown(by: 60) }
                        .disabled(service.isRunning)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(service.isRunning ? 0.05 : 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
            }

            HStack(spacing: 16) {
                Button {
                    if service.isRunning {
                        service.pause()
                    } else {
                        service.start()
                    }
                } label: {
                    Text(service.isRunning ? "Pause" : "Start")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    service.reset()
                } label: {
                    Text("Reset")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 6)
    }

    private func displayTime(at now: Date) -> String {
        switch service.mode {
        case .countdown, .pomodoro:
            return formatSeconds(service.remaining(at: now), roundUp: true)
        case .stopwatch:
            return formatSeconds(service.elapsed(at: now), roundUp: false)
        }
    }

    private func formatSeconds(_ seconds: TimeInterval, roundUp: Bool) -> String {
        let total = max(0, Int(roundUp ? ceil(seconds) : seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}
