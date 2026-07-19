import Foundation

/// Detects the current operating system and returns appropriate platform backend
class PlatformDetector {
    
    /// Detected platform type
    static let current: Platform = {
        #if os(macOS)
        return .macOS
        #elseif os(Linux)
        return .linux
        #elseif os(Windows)
        return .windows
        #else
        return .unknown
        #endif
    }()
    
    /// Platform types
    enum Platform: String, CaseIterable {
        case macOS = "macOS"
        case linux = "Linux"
        case windows = "Windows"
        case unknown = "Unknown"
        
        var displayName: String { rawValue }
    }
    
    /// Get platform-specific display controller
    static func displayController() -> DisplayControllerProtocol {
        switch current {
        case .macOS:
            return MacDisplayController()
        case .linux:
            return LinuxDisplayController()
        case .windows:
            return WindowsDisplayController()
        case .unknown:
            return MacDisplayController() // Fallback
        }
    }
    
    /// Get platform-specific ambient light sensor
    static func ambientLightSensor() -> AmbientLightProtocol {
        switch current {
        case .macOS:
            return MacOSAmbientLightSensor()
        case .linux:
            return LinuxAmbientLightSensor()
        case .windows:
            return WindowsAmbientLightSensor()
        case .unknown:
            return MacOSAmbientLightSensor() // Fallback
        }
    }
    
    /// Get platform-specific color profile manager
    static func colorProfileManager() -> ColorProfileProtocol {
        switch current {
        case .macOS:
            return MacOSColorProfileManager()
        case .linux:
            return LinuxColorProfileManager()
        case .windows:
            return WindowsColorProfileManager()
        case .unknown:
            return MacOSColorProfileManager() // Fallback
        }
    }
}
