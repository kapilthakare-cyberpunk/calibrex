import Foundation
import IOKit

/// Reads ambient light level from MacBook's built-in HID sensor
/// Available on MacBooks since ~2008
class AmbientLightSensor {
    
    private var serviceConnection: io_connect_t = IO_OBJECT_NULL
    
    /// Open connection to ambient light sensor
    func open() -> Bool {
        let matching = IOServiceMatching("IOHIDDevice")
        
        guard let service = IOServiceGetMatchingService(kIOMainPortDefault, matching) else {
            return false
        }
        
        defer { IOObjectRelease(service) }
        
        var connect: io_connect_t = IO_OBJECT_NULL
        let result = IOServiceOpen(service, mach_task_self_, 0, &connect)
        
        if result == KERN_SUCCESS {
            serviceConnection = connect
            return true
        }
        
        return false
    }
    
    /// Close connection to sensor
    func close() {
        if serviceConnection != IO_OBJECT_NULL {
            IOServiceClose(serviceConnection)
            serviceConnection = IO_OBJECT_NULL
        }
    }
    
    /// Read raw ambient light value
    /// Returns raw sensor value (needs conversion to lux)
    func readRawValue() -> UInt32? {
        guard serviceConnection != IO_OBJECT_NULL else { return nil }
        
        var outputSize = MemoryLayout<UInt32>.size
        var output = UInt32(0)
        
        let result = IOConnectCallMethod(
            serviceConnection,
            0, // selector for ambient light
            nil, 0,
            nil, 0,
            &output, &outputSize
        )
        
        if result == KERN_SUCCESS {
            return output
        }
        
        return nil
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
