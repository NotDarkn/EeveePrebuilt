import Foundation

final class PerfMeter {
    private let tag: String
    private var passes = 0
    private var ticks: UInt64 = 0
    private var nextReport = 50

    private static let msPerTick: Double = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(timebase.denom) / 1_000_000
    }()

    init(_ tag: String) {
        self.tag = tag
    }

    @discardableResult
    func measure<T>(_ body: () -> T) -> T {
        let start = mach_absolute_time()
        let result = body()
        ticks &+= mach_absolute_time() &- start
        passes += 1
        if passes == nextReport {
            nextReport *= 4
            let total = Double(ticks) * Self.msPerTick
            eeveeLog("[EeveeSpotify][%@] %d passes, %.2f ms total, %.3f ms avg", tag, passes, total, total / Double(passes))
        }
        return result
    }
}
