import Foundation

/// Driver for BH1750 ambient light sensor
/// Connects via Arduino/ESP32 USB bridge
class BH1750Sensor {
    
    private var serial: SerialCommunication?
    private var isConnected = false
    
    /// BH1750 measurement modes
    enum MeasurementMode: String {
        case continuousHighRes = "1"      // 1 lux resolution, 120ms
        case continuousHighRes2 = "2"     // 0.5 lux resolution, 120ms
        case continuousLowRes = "3"       // 4 lux resolution, 16ms
        case oneTimeHighRes = "4"         // 1 lux resolution, 120ms
        case oneTimeHighRes2 = "5"        // 0.5 lux resolution, 120ms
        case oneTimeLowRes = "6"          // 4 lux resolution, 16ms
    }
    
    /// Initialize and connect to sensor
    func connect(port: String, baudRate: Int = 9600) -> Bool {
        serial = SerialCommunication()
        
        guard serial!.open(port: port, baudRate: baudRate) else {
            print("[BH1750] Failed to open serial port")
            return false
        }
        
        // Wait for Arduino to boot
        Thread.sleep(forTimeInterval: 2.0)
        
        // Flush any boot messages
        serial!.flushInput()
        
        // Send identification command
        serial!.writeLine("IDENTIFY")
        
        if let response = serial!.readLine(), response.contains("BH1750") {
            isConnected = true
            print("[BH1750] Connected")
            
            // Set default mode
            setMode(.continuousHighRes)
            
            return true
        }
        
        print("[BH1750] Device not recognized")
        return false
    }
    
    /// Disconnect from sensor
    func disconnect() {
        serial?.close()
        isConnected = false
    }
    
    /// Read illuminance data
    func read() -> BH1750Data? {
        guard isConnected, let serial = serial else { return nil }
        
        // Send read command
        serial.writeLine("READ")
        
        // Parse response: "LUX:1234.56"
        guard let response = serial.readLine() else { return nil }
        
        return parseResponse(response)
    }
    
    /// Set measurement mode
    func setMode(_ mode: MeasurementMode) {
        guard let serial = serial else { return }
        
        serial.writeLine("MODE:\(mode.rawValue)")
        
        if let response = serial.readLine(), response.contains("OK") {
            print("[BH1750] Mode set to \(mode.rawValue)")
        }
    }
    
    /// Set measurement time
    func setMeasurementTime(_ time: Int) {
        guard let serial = serial else { return }
        
        // Valid: 140-1269 ms (default 120)
        serial.writeLine("MTIME:\(time)")
        
        if let response = serial.readLine(), response.contains("OK") {
            print("[BH1750] Measurement time set to \(time)ms")
        }
    }
    
    /// Reset sensor
    func reset() {
        guard let serial = serial else { return }
        
        serial.writeLine("RESET")
        _ = serial.readLine() // Wait for OK
        
        print("[BH1750] Reset")
    }
    
    /// Power on sensor
    func powerOn() {
        guard let serial = serial else { return }
        
        serial.writeLine("POWER:ON")
        _ = serial.readLine()
    }
    
    /// Power off sensor
    func powerOff() {
        guard let serial = serial else { return }
        
        serial.writeLine("POWER:OFF")
        _ = serial.readLine()
    }
    
    // MARK: - Response Parsing
    
    private func parseResponse(_ response: String) -> BH1750Data? {
        var lux = 0.0
        
        for part in response.components(separatedBy: "|") {
            let kv = part.components(separatedBy: ":")
            guard kv.count == 2 else { continue }
            
            let key = kv[0].trimmingCharacters(in: .whitespaces)
            let value = Double(kv[1].trimmingCharacters(in: .whitespaces)) ?? 0
            
            switch key {
            case "LUX": lux = value
            default: break
            }
        }
        
        return BH1750Data(lux: lux)
    }
}

// MARK: - Data Types

struct BH1750Data {
    let lux: Double
}
