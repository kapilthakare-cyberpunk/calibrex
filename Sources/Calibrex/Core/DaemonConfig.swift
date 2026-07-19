import Foundation

/// Daemon configuration loaded from JSON config file
struct DaemonConfig {
    let pollIntervalLux: Double
    let pollIntervalColorTemp: Double
    let pollIntervalTemperature: Double
    let transitionDuration: Double
    let luxChangeThreshold: Double
    let colorTempChangeThreshold: Double
    
    static let `default` = DaemonConfig(
        pollIntervalLux: 60,
        pollIntervalColorTemp: 120,
        pollIntervalTemperature: 300,
        transitionDuration: 2.0,
        luxChangeThreshold: 0.15,
        colorTempChangeThreshold: 200
    )
    
    static func load(from path: String? = nil) -> DaemonConfig {
        // Load from config file or return defaults
        guard let path = path,
              let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let daemon = json["daemon"] as? [String: Any] else {
            return .default
        }
        
        return DaemonConfig(
            pollIntervalLux: daemon["poll_interval_lux"] as? Double ?? 60,
            pollIntervalColorTemp: daemon["poll_interval_color_temp"] as? Double ?? 120,
            pollIntervalTemperature: daemon["poll_interval_temperature"] as? Double ?? 300,
            transitionDuration: daemon["transition_duration"] as? Double ?? 2.0,
            luxChangeThreshold: daemon["lux_change_threshold"] as? Double ?? 0.15,
            colorTempChangeThreshold: daemon["color_temp_change_threshold"] as? Double ?? 200
        )
    }
}
