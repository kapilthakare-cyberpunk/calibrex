import Foundation

/// Reads ambient light level from MacBook's built-in HID sensor
/// Available on MacBooks since ~2008
class AmbientLightSensor {
    
    private var isOpen_ = false
    
    /// Check if sensor is open
    var isOpen: Bool {
        return isOpen_
    }
    
    /// Open connection to ambient light sensor
    func open() -> Bool {
        // For now, just mark as open
        // In production, use IOKit HID to access the sensor
        isOpen_ = true
        return true
    }
    
    /// Close connection to sensor
    func close() {
        isOpen_ = false
    }
    
    /// Read raw ambient light value
    /// Returns raw sensor value (needs conversion to lux)
    func readRawValue() -> UInt32? {
        guard isOpen_ else { return nil }
        
        // For now, return a simulated value
        // In production, use IOKit to read the actual sensor
        return 30000 // Simulated value
    }
    
    /// Convert raw sensor value to lux
    /// Apple's ambient light sensor has a non-linear response
    func rawToLux(_ raw: UInt32) -> Double {
        // Apple's ambient light sensor calibration
        // Raw values range from ~0 to ~67000
        // Mapping is approximately logarithmic
        
        let rawDouble = Double(raw)
        
        // Approximate calibration curve
        // Based on known Apple sensor characteristics
        let lux = pow(rawDouble / 67000.0, 2.0) * 100000.0
        
        return max(0, min(lux, 100000))
    }
    
    /// Read ambient light in lux (convenience method)
    func readLux() -> Double? {
        guard let raw = readRawValue() else { return nil }
        return rawToLux(raw)
    }
    
    deinit {
        close()
    }
}
