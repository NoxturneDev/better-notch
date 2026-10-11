import Foundation

@MainActor
final class AppServices {
    let nowPlaying = NowPlayingService()
    let fileTray = FileTrayStore()
    let timer = TimerService()
    let notes = NotesStore()
    let launcher = LauncherStore()
    let shortcuts = ShortcutsService()
    let battery = BatteryService()
    let systemStats = SystemStatsService()
    let weather = WeatherService()
    let herdr = HerdrService()
    let plans = PlanStore()
    let usage = UsageService()

    var notchAgentsVisible = false
    var popoverVisible = false

    func updateAgentsActivity() {
        let active = notchAgentsVisible || popoverVisible
        herdr.setFastPolling(active)
        if active { plans.start() } else { plans.stop() }
        if popoverVisible { usage.start() } else { usage.stop() }
    }

    var showsClosedIndicators: Bool {
        nowPlaying.track?.isPlaying == true || timer.isRunning || herdr.waitingCount > 0
    }
}
