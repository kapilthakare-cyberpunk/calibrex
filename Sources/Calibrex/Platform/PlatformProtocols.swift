import Foundation

// MARK: - Display Controller Protocol

/// Cross-platform display control interface
protocol DisplayControllerProtocol {
    
    /// Get current display brightness (0.0 - 1.0)
    func getBrightness() -> Double
    
    /// Set display brightness (0.0 - 1.0)
    func setBrightness(_ level: Double) -> Bool
    
    /// Get current white point temperature (Kelvin)
    func getWhitePoint() -> Double
    
    /// Set white point temperature (Kelvin)
    func setWhitePoint(_ kelvin: Double) -> Bool
    
    /// Check if blue light filter (Night Shift/Blue Light) is enabled
    func isBlueLightFilterEnabled() -> Bool
    
    /// Enable/disable blue light filter
    func setBlueLightFilter(_ enabled: Bool) -> Bool
    
    /// Get blue light filter temperature (Kelvin)
    func getBlueLightFilterTemperature() -> Double
    
    /// Set blue light filter temperature (Kelvin)
    func setBlueLightFilterTemperature(_ kelvin: Double) -> Bool
    
    /// Check if display supports wide color gamut
    func supportsWideColorGamut() -> Bool
    
    /// Get display information
    func getDisplayInfo() -> DisplayInfo
}

// MARK: - Ambient Light Protocol

/// Cross-platform ambient light sensor interface
protocol AmbientLightProtocol {
    
    /// Open/connect to ambient light sensor
    func open() -> Bool
    
    /// Close/disconnect from sensor
    func close()
    
    /// Read ambient light level in lux
    func readLux() -> Double?
    
    /// Check if sensor is available
    var isAvailable: Bool { get }
}

// MARK: - Color Profile Protocol

/// Cross-platform color profile management interface
protocol ColorProfileProtocol {
    
    /// Get current active ICC profile path
    func getCurrentProfile() -> String?
    
    /// Apply ICC profile to display
    func applyProfile(_ path: String) -> Bool
    
    /// Get list of available profiles
    func listProfiles() -> [ColorProfile]
    
    /// Install ICC profile to system
    func installProfile(_ path: String) -> Bool
    
    /// Remove ICC profile from system
    func removeProfile(_ path: String) -> Bool
    
    /// Get display color space
    func getColorSpace() -> String
}

// MARK: - Types

struct DisplayInfo {
    let name: String
    let manufacturer: String
    let model: String
    let serialNumber: String?
    let resolution: String
    let colorDepth: Int
    let supportsHDR: Bool
    let supportsTrueTone: Bool
    
    static let unknown = DisplayInfo(
        name: "Unknown Display",
        manufacturer: "Unknown",
        model: "Unknown",
        serialNumber: nil,
        resolution: "Unknown",
        colorDepth: 8,
        supportsHDR: false,
        supportsTrueTone: false
    )
}

struct ColorProfile {
    let name: String
    let path: String
    let creationDate: Date?
    let isDefault: Bool
}
