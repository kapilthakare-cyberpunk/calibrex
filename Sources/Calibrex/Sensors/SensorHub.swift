import Foundation

/// Reads ambient environmental signals from sensors
class SensorHub {
    
    private let ambientSensor = AmbientLightSensor()
    private let usbSensorManager = USBSensorManager()
    private var sensorOpened = false
    private var usbScanned = false
    
    init() {
        // Try to open ambient light sensor on init
        sensorOpened = ambientSensor.open()
        if sensorOpened {
            print("[SensorHub] Ambient light sensor opened successfully")
        } else {
            print("[SensorHub] Ambient light sensor not available, using fallbacks")
        }
    }
    
    /// Scan for USB sensors (call once on startup)
    func scanUSBSensors() {
        guard !usbScanned else { return }
        
        let sensors = usbSensorManager.scanAndConnect()
        usbScanned = true
        
        if sensors.isEmpty {
            print("[SensorHub] No USB sensors found")
        }
    }
    
    /// Read ambient light level in lux
    func readLux() async -> Double {
        // Priority: USB sensor > MacBook built-in sensor > estimation
        
        // Try USB sensor first (more accurate)
        if usbSensorManager.hasLightSensor, let lux = usbSensorManager.readLux() {
            return lux
        }
        
        // Try MacBook built-in sensor
        if sensorOpened, let lux = ambientSensor.readLux() {
            return lux
        }
        
        // Fallback: estimate from time of day
        return estimateLuxFromTimeOfDay()
    }
    
    /// Read ambient color temperature in Kelvin
    func readColorTemp() async -> Double {
        // Priority: USB sensor (TSL2591) > calculation > time-based estimation
        
        // TSL2591 can calculate color temperature from IR/Visible ratio
        if let temp = usbSensorManager.readColorTemp() {
            return temp
        }
        
        // Estimate from time of day (sunrise: 2000K, noon: 6500K, sunset: 2000K)
        return estimateColorTempFromTimeOfDay()
    }
    
    /// Read room temperature in Celsius
    func readTemperature() async -> Double {
        // Priority: USB sensor > SMC sensors > estimate
        
        if let temp = usbSensorManager.readTemperature() {
            return temp
        }
        
        if let smcTemp = readSMCTemperature() {
            return smcTemp
        }
        
        return 22.0 // Default room temperature assumption
    }
    
    // MARK: - SMC Temperature Sensors (Mac)
    
    private func readSMCTemperature() -> Double? {
        // Read CPU/GPU/ambient temperature from SMC
        // Uses ioreg or direct SMC access
        
        // TODO: Implement SMC temperature reading
        return nil
    }
    
    // MARK: - Cleanup
    
    func disconnectAll() {
        usbSensorManager.disconnectAll()
        if sensorOpened {
            ambientSensor.close()
            sensorOpened = false
        }
    }
    
    // MARK: - Estimation Fallbacks
    
    private func estimateLuxFromTimeOfDay() -> Double {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 6..<8:   return 500   // Dawn
        case 8..<12:  return 10000 // Morning
        case 12..<14: return 15000 // Noon
        case 14..<18: return 10000 // Afternoon
        case 18..<20: return 2000  // Sunset
        case 20..<22: return 200   // Evening
        default:      return 50    // Night
        }
    }
    
    private func estimateColorTempFromTimeOfDay() -> Double {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 6..<8:   return 2500  // Warm dawn
        case 8..<10:  return 4000  // Warming up
        case 10..<16: return 6500  // Daylight D65
        case 16..<18: return 5000  // Afternoon
        case 18..<20: return 3500  // Golden hour
        case 20..<22: return 2700  // Warm evening
        default:      return 2000  // Very warm night
        }
    }
}
