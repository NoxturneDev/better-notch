import SwiftUI

struct StatusStripView: View {
    @Bindable var weather: WeatherService
    @Bindable var battery: BatteryService

    var body: some View {
        HStack(spacing: 12) {
            if let temp = weather.temperature {
                HStack(spacing: 4) {
                    Image(systemName: weather.symbolName)
                    Text("\(Int(round(temp)))°")
                }
            }

            if let pct = battery.percent {
                HStack(spacing: 4) {
                    Image(systemName: batterySymbol(percent: pct, isCharging: battery.isCharging))
                    Text("\(pct)%")
                }
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white.opacity(0.8))
        .padding(.trailing, 14)
    }

    private func batterySymbol(percent: Int, isCharging: Bool) -> String {
        if isCharging {
            return "battery.100percent.bolt"
        }
        switch percent {
        case 88...100:
            return "battery.100percent"
        case 63..<88:
            return "battery.75percent"
        case 38..<63:
            return "battery.50percent"
        case 13..<38:
            return "battery.25percent"
        default:
            return "battery.0percent"
        }
    }
}
