import Foundation

/// Linux ambient light sensor using IIO (Industrial I/O) subsystem
class LinuxAmbientLightSensor: AmbientLightProtocol {
    
    private var iioPath: String?
    
    func open() -> Bool {
        // Find ambient light sensor in /sys/bus/iio/devices/
        let iioBase = "/sys/bus/iio/devices"
        
        guard let devices = try? FileManager.default.contentsOfDirectory(atPath: iioBase) else {
            return false
        }
        
        for device in devices {
            let namePath = "\(iioBase)/\(device)/name"
            
            if let nameData = FileManager.default.contents(atPath: namePath),
               let name = String(data: nameData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                
                // Check for common ambient light sensors
                if name.contains("tsl") || name.contains("bh17") || name.contains("als") || name.contains("light") {
                    iioPath = "\(iioBase)/\(device)"
                    print("[LinuxALS] Found sensor: \(name) at \(iioPath!)")
                    return true
                }
            }
        }
        
        print("[LinuxALS] No ambient light sensor found")
        return false
    }
    
    func close() {
        iioPath = nil
    }
    
    func readLux() -> Double? {
        guard let path = iioPath else { return nil }
        
        // Read from IIO device
        let inputPath = "\(path)/in_illuminance_input"
        
        if let data = FileManager.default.contents(atPath: inputPath),
           let str = String(data: data, encoding: .utf8),
           let lux = Double(str.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return lux / 1000.0 // IIO reports in millilux
        }
        
        // Fallback: try raw channel
        let rawPath = "\(path)/in_illuminance_raw"
        if let data = FileManager.default.contents(atPath: rawPath),
           let str = String(data: data, encoding: .utf8),
           let raw = Double(str.trimmingCharacters(in: .whitespacesAndNewlines)) {
            // Scale based on known sensor characteristics
            return raw * 10.0 // Approximate conversion
        }
        
        return nil
    }
    
    var isAvailable: Bool {
        return iioPath != nil
    }
}
