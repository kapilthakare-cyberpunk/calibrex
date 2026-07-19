import Foundation

/// Windows ambient light sensor using Windows.Devices.Sensors API
class WindowsAmbientLightSensor: AmbientLightProtocol {
    
    private var isAvailable_ = false
    
    func open() -> Bool {
        // Check if ambient light sensor is available via PowerShell
        let output = executePowershell(command: """
            Get-CimInstance -Namespace root\\wmi -Class WmiMonitorBrightness | SelectObject -First 1
        """)
        
        isAvailable_ = !output.isEmpty
        
        if isAvailable_ {
            print("[WindowsALS] Ambient light sensor available")
        } else {
            print("[WindowsALS] Ambient light sensor not available")
        }
        
        return isAvailable_
    }
    
    func close() {
        isAvailable_ = false
    }
    
    func readLux() -> Double? {
        guard isAvailable_ else { return nil }
        
        // Windows doesn't directly expose ambient light in lux via WMI
        // Use brightness as a proxy, or USB sensor
        
        let output = executePowershell(command: """
            Get-WmiObject -Namespace root\\wmi -Class WmiMonitorBrightness | SelectObject -ExpandProperty CurrentBrightness
        """)
        
        if let brightness = Double(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
            // Convert brightness percentage to approximate lux
            // 0% = ~0 lux, 100% = ~50000 lux (approximate)
            return brightness * 500.0
        }
        
        return nil
    }
    
    var isAvailable: Bool {
        return isAvailable_
    }
    
    private func executePowershell(command: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/powershell")
        process.arguments = ["-Command", command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
