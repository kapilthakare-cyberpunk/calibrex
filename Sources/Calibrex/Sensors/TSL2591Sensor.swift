import Foundation

/// Driver for TSL2591 high-precision luminosity sensor
/// Connects via Arduino/ESP32 USB bridge
class TSL2591Sensor {
    
    private var serial: SerialCommunication?
    private var isConnected = false
    
    /// TSL2591 measurement range
    enum Gain: String {
        case low = "0"      // 1x gain, 100ms
        case medium = "1"   // 25x gain, 100ms
        case high = "2"     // 428x gain, 100ms
        case max = "3"      // 9876x gain, 100ms
    }
    
    /// Initialize and connect to sensor
    func connect(port: String, baudRate: Int = 115200) -> Bool {
        serial = SerialCommunication()
        
        guard serial!.open(port: port, baudRate: baudRate) else {
            print("[TSL2591] Failed to open serial port")
            return false
        }
        
        // Wait for Arduino to boot
        Thread.sleep(forTimeInterval: 2.0)
        
        // Flush any boot messages
        serial!.flushInput()
        
        // Send identification command
        serial!.writeLine("IDENTIFY")
        
        if let response = serial!.readLine(), response.contains("TSL2591") {
            isConnected = true
            print("[TSL2591] Connected")
            
            // Set default gain
            setGain(.high)
            
            return true
        }
        
        print("[TSL2591] Device not recognized")
        return false
    }
    
    /// Disconnect from sensor
    func disconnect() {
        serial?.close()
        isConnected = false
    }
    
    /// Read luminosity data
    func read() -> TSL2591Data? {
        guard isConnected, let serial = serial else { return nil }
        
        // Send read command
        serial.writeLine("READ")
        
        // Parse response: "VISIBLE:12345|IR:67890|LUX:123.45"
        guard let response = serial.readLine() else { return nil }
        
        return parseResponse(response)
    }
    
    /// Set sensor gain
    func setGain(_ gain: Gain) {
        guard let serial = serial else { return }
        
        serial.writeLine("GAIN:\(gain.rawValue)")
        
        if let response = serial.readLine(), response.contains("OK") {
            print("[TSL2591] Gain set to \(gain.rawValue)")
        }
    }
    
    /// Set integration time
    func setIntegrationTime(_ ms: Int) {
        guard let serial = serial else { return }
        
        // Valid: 100, 200, 300, 400, 500, 600 ms
        serial.writeLine("TIME:\(ms)")
        
        if let response = serial.readLine(), response.contains("OK") {
            print("[TSL2591] Integration time set to \(ms)ms")
        }
    }
    
    /// Enable auto-gain
    func setAutoGain(_ enabled: Bool) {
        guard let serial = serial else { return }
        
        serial.writeLine("AUTOGAIN:\(enabled ? "ON" : "OFF")")
        _ = serial.readLine() // Wait for OK
    }
    
    /// Calculate color temperature from visible and IR
    func calculateColorTemp(visible: Double, ir: Double) -> Double {
        // TSL2591 color temperature calculation
        // Based on ratio of visible to IR light
        
        guard ir > 0 else { return 6500 } // Default daylight
        
        let ratio = visible / ir
        
        // Approximate color temperature mapping
        // Higher ratio = cooler (bluer) light
        // Lower ratio = warmer (redder) light
        
        let temp: Double
        if ratio > 0.5 {
            temp = 6500 + (ratio - 0.5) * 2000 // Cool daylight
        } else if ratio > 0.25 {
            temp = 4000 + (ratio - 0.25) * 10000 // Mixed
        } else {
            temp = 2000 + ratio * 8000 // Warm
        }
        
        return max(1800, min(10000, temp))
    }
    
    // MARK: - Response Parsing
    
    private func parseResponse(_ response: String) -> TSL2591Data? {
        var visible = 0.0
        var ir = 0.0
        var lux = 0.0
        
        for part in response.components(separatedBy: "|") {
            let kv = part.components(separatedBy: ":")
            guard kv.count == 2 else { continue }
            
            let key = kv[0].trimmingCharacters(in: .whitespaces)
            let value = Double(kv[1].trimmingCharacters(in: .whitespaces)) ?? 0
            
            switch key {
            case "VISIBLE": visible = value
            case "IR": ir = value
            case "LUX": lux = value
            default: break
            }
        }
        
        let colorTemp = calculateColorTemp(visible: visible, ir: ir)
        
        return TSL2591Data(
            visible: visible,
            infrared: ir,
            lux: lux,
            colorTemperature: colorTemp
        )
    }
}

// MARK: - Data Types

struct TSL2591Data {
    let visible: Double
    let infrared: Double
    let lux: Double
    let colorTemperature: Double
}
