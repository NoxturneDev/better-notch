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

    var showsClosedIndicators: Bool {
        nowPlaying.track?.isPlaying == true || timer.isRunning || herdr.waitingCount > 0
    }
}
