import Darwin
import Foundation
import Observation

@MainActor
@Observable
final class SystemStatsService {
    var cpuUsage: Double = 0
    var memoryUsed: UInt64 = 0
    let memoryTotal = ProcessInfo.processInfo.physicalMemory
    var downloadBytesPerSecond: Double = 0
    var uploadBytesPerSecond: Double = 0

    private var pollTask: Task<Void, Never>?

    private struct Baseline {
        var user: UInt32 = 0
        var system: UInt32 = 0
        var idle: UInt32 = 0
        var nice: UInt32 = 0
        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var time: Date = Date()
        var hasBaseline = false
    }

    private var baseline = Baseline()

    func start() {
        stop()
        sample()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if Task.isCancelled { break }
                self?.sample()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        baseline.hasBaseline = false
    }

    private func sample() {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let cpuResult = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        var stats = vm_statistics64()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let vmResult = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount)
            }
        }
        if vmResult == KERN_SUCCESS {
            let pages = UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
            memoryUsed = pages * UInt64(vm_kernel_page_size)
        }

        var first: UnsafeMutablePointer<ifaddrs>?
        var currentRx: UInt64 = 0
        var currentTx: UInt64 = 0
        if getifaddrs(&first) == 0 {
            defer { freeifaddrs(first) }
            var cursor = first
            while let entry = cursor {
                defer { cursor = entry.pointee.ifa_next }
                guard let address = entry.pointee.ifa_addr,
                      address.pointee.sa_family == UInt8(AF_LINK),
                      String(cString: entry.pointee.ifa_name).hasPrefix("en"),
                      let raw = entry.pointee.ifa_data else { continue }
                let data = raw.assumingMemoryBound(to: if_data.self).pointee
                currentRx += UInt64(data.ifi_ibytes)
                currentTx += UInt64(data.ifi_obytes)
            }
        }

        let now = Date()

        if cpuResult == KERN_SUCCESS {
            let user = info.cpu_ticks.0
            let sys = info.cpu_ticks.1
            let idle = info.cpu_ticks.2
            let nice = info.cpu_ticks.3

            if baseline.hasBaseline {
                let dUser = Double(user >= baseline.user ? user - baseline.user : 0)
                let dSys = Double(sys >= baseline.system ? sys - baseline.system : 0)
                let dIdle = Double(idle >= baseline.idle ? idle - baseline.idle : 0)
                let dNice = Double(nice >= baseline.nice ? nice - baseline.nice : 0)
                let dTotal = dUser + dSys + dIdle + dNice
                if dTotal > 0 {
                    cpuUsage = max(0, min(1, (dUser + dSys + dNice) / dTotal))
                }

                let dt = now.timeIntervalSince(baseline.time)
                if dt > 0 {
                    let dRx = currentRx >= baseline.rx ? currentRx - baseline.rx : 0
                    let dTx = currentTx >= baseline.tx ? currentTx - baseline.tx : 0
                    downloadBytesPerSecond = Double(dRx) / dt
                    uploadBytesPerSecond = Double(dTx) / dt
                }
            }

            baseline.user = user
            baseline.system = sys
            baseline.idle = idle
            baseline.nice = nice
            baseline.rx = currentRx
            baseline.tx = currentTx
            baseline.time = now
            baseline.hasBaseline = true
        }
    }
}
