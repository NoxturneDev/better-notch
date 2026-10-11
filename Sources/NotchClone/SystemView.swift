import SwiftUI

struct SystemView: View {
    @Bindable var stats: SystemStatsService
    @Bindable var weather: WeatherService
    @Bindable var model: NotchViewModel

    @State private var cityInput: String = ""
    @FocusState private var isCityFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            // Column 1: CPU & Memory
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("CPU")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(round(stats.cpuUsage * 100)))%")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    ProgressView(value: max(0, min(1, stats.cpuUsage)))
                        .progressViewStyle(.linear)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Memory")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text("\(formatMemory(stats.memoryUsed)) / \(formatMemory(stats.memoryTotal))")
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    let ratio = stats.memoryTotal > 0 ? Double(stats.memoryUsed) / Double(stats.memoryTotal) : 0
                    ProgressView(value: max(0, min(1, ratio)))
                        .progressViewStyle(.linear)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()
                .overlay(Color.white.opacity(0.12))

            // Column 2: Network
            VStack(alignment: .leading, spacing: 8) {
                Text("Network")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))

                HStack(spacing: 6) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                    Text(formatRate(stats.downloadBytesPerSecond))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }

                HStack(spacing: 6) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.blue)
                    Text(formatRate(stats.uploadBytesPerSecond))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .overlay(Color.white.opacity(0.12))

            // Column 3: Weather
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: weather.symbolName)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                    if let temp = weather.temperature {
                        Text("\(Int(round(temp)))°C")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text(weather.summary)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }

                if let place = weather.placeName ?? weather.errorText {
                    Text(place)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(weather.errorText != nil ? .red.opacity(0.8) : .white.opacity(0.5))
                        .lineLimit(1)
                }

                TextField("City", text: $cityInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .focused($isCityFocused)
                    .onSubmit {
                        weather.setCity(cityInput)
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear {
            cityInput = weather.city
        }
        .onChange(of: isCityFocused) { _, focused in
            model.setEditingText(focused)
        }
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useGB]
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formatRate(_ bytesPerSec: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytesPerSec)) + "/s"
    }
}
