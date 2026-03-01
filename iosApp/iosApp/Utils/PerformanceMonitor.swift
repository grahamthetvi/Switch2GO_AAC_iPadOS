import Foundation
import Combine
import os.log

/// Performance monitoring utilities
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private let logger = OSLog(subsystem: "com.switch2go", category: "Performance")
    private var timers: [String: CFAbsoluteTime] = [:]
    
    private init() {}
    
    /// Start timing an operation
    func startTimer(_ operation: String) {
        timers[operation] = CFAbsoluteTimeGetCurrent()
    }
    
    /// End timing and log duration
    func endTimer(_ operation: String) {
        guard let startTime = timers[operation] else { return }
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // ms
        os_log(.info, log: logger, "%{public}s took %.2fms", operation, duration)
        
        timers.removeValue(forKey: operation)
        
        // Warn if operation is slow
        if duration > 16.67 { // More than one frame at 60fps
            os_log(.default, log: logger, "⚠️ %{public}s exceeded frame budget (%.2fms)", operation, duration)
        }
    }
    
    /// Measure memory usage
    func logMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryMB = Double(info.resident_size) / 1_048_576.0
            os_log(.info, log: logger, "Memory usage: %.2f MB", memoryMB)
            
            if memoryMB > 500 {
                os_log(.default, log: logger, "⚠️ High memory usage: %.2f MB", memoryMB)
            }
        }
    }
    
    /// Log FPS
    func logFPS(_ fps: Double) {
        if fps < 50 {
            os_log(.default, log: logger, "⚠️ Low FPS: %.1f", fps)
        }
    }
}

/// FPS Counter for monitoring frame rate
class FPSCounter: ObservableObject {
    @Published var currentFPS: Double = 60.0
    
    private var frameTimestamps: [CFAbsoluteTime] = []
    private let maxSamples = 60
    
    func recordFrame() {
        let now = CFAbsoluteTimeGetCurrent()
        frameTimestamps.append(now)
        
        // Keep only recent frames
        if frameTimestamps.count > maxSamples {
            frameTimestamps.removeFirst()
        }
        
        // Calculate FPS
        if frameTimestamps.count > 1 {
            let duration = frameTimestamps.last! - frameTimestamps.first!
            if duration > 0 {
                currentFPS = Double(frameTimestamps.count - 1) / duration
            }
        }
    }
}
