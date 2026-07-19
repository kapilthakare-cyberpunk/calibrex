import Foundation

/// Windows display controller using DDC/CI and WCS
class WindowsDisplayController: DisplayControllerProtocol {
    
    // MARK: - Brightness
    
    func getBrightness() -> Double {
        // Try WMI brightness query
        let output = executePowershell(command: """
            Get-WmiObject -Namespace root\\wmi -Class WmiMonitorBrightness | SelectObject -ExpandProperty CurrentBrightness
        """)
        
        if let brightness = Double(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return brightness / 100.0
        }
        
        return 0.5 // Default
    }
    
    func setBrightness(_ level: Double) -> Bool {
        let clamped = max(0.0, min(1.0, level))
        let brightness = Int(clamped * 100)
        
        let output = executePowershell(command: """
            Get-WmiObject -Namespace root\\wmi -Class WmiMonitorBrightnessMethods | Invoke-WmiMethod -MethodName WmiSetBrightness -ArgumentList @\(brightness)
        """)
        
        return output.isEmpty
    }
    
    // MARK: - White Point
    
    func getWhitePoint() -> Double {
        // Use Windows Color System (WCS)
        // TODO: Implement WCS query via PowerShell
        return 6500 // Default daylight
    }
    
    func setWhitePoint(_ kelvin: Double) -> Bool {
        // Use Windows Color System (WCS)
        // TODO: Implement WCS profile application
        return false
    }
    
    // MARK: - Blue Light Filter
    
    func isBlueLightFilterEnabled() -> Bool {
        // Check Night Light via registry
        let output = executePowershell(command: """
            Get-ItemProperty -Path "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\CloudStore\\Store\\DefaultAccount\\Current\\default`$windows.data.bluelightreduction.bluelightreductionstate" -Name "Data" -ErrorAction SilentlyContinue | SelectObject -ExpandProperty Data
        """)
        
        // Parse registry data to check if enabled
        // Simplified check
        return !output.isEmpty
    }
    
    func setBlueLightFilter(_ enabled: Bool) -> Bool {
        // Enable/disable Night Light via registry
        let value = enabled ? 1 : 0
        
        let output = executePowershell(command: """
            Set-ItemProperty -Path "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\CloudStore\\Store\\DefaultAccount\\Current\\default`$windows.data.bluelightreduction.bluelightreductionstate" -Name "Data" -Value @\(value)
        """)
        
        return output.isEmpty
    }
    
    func getBlueLightFilterTemperature() -> Double {
        // Night Light temperature is stored in registry
        // Default is 4000K
        return 4000
    }
    
    func setBlueLightFilterTemperature(_ kelvin: Double) -> Bool {
        // TODO: Implement Night Light temperature setting
        return false
    }
    
    // MARK: - Display Info
    
    func supportsWideColorGamut() -> Bool {
        // Check via DXVA or registry
        return false // Conservative default
    }
    
    func getDisplayInfo() -> DisplayInfo {
        let name = getMonitorName()
        let resolution = getDisplayResolution()
        
        return DisplayInfo(
            name: name,
            manufacturer: "Unknown",
            model: name,
            serialNumber: nil,
            resolution: resolution,
            colorDepth: 32,
            supportsHDR: isHDREnabled(),
            supportsTrueTone: false
        )
    }
    
    // MARK: - Private Helpers
    
    private func getMonitorName() -> String {
        let output = executePowershell(command: """
            Get-CimInstance -ClassName Win32_DesktopMonitor | SelectObject -First 1 -ExpandProperty Name
        """)
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown Display" : output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getDisplayResolution() -> String {
        let width = executePowershell(command: """
            Get-CimInstance -ClassName Win32_VideoController | SelectObject -First 1 -ExpandProperty CurrentHorizontalResolution
        """)
        
        let height = executePowershell(command: """
            Get-CimInstance -ClassName Win32_VideoController | SelectObject -First 1 -ExpandProperty CurrentVerticalResolution
        """)
        
        let w = width.trimmingCharacters(in: .whitespacesAndNewlines)
        let h = height.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !w.isEmpty && !h.isEmpty else { return "Unknown" }
        
        return "\(w)x\(h)"
    }
    
    private func isHDREnabled() -> Bool {
        let output = executePowershell(command: """
            Get-CimInstance -Namespace root\\wmi -Class WmiMonitorConnectionParams | SelectObject -ExpandProperty VideoOutputTechnology
        """)
        
        // VideoOutputTechnology 10 = DisplayPort HDR
        return output.trimmingCharacters(in: .whitespacesAndNewlines) == "10"
    }
    
    private func executePowershell(command: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/powershell") // WSL or PowerShell Core
        
        // For native Windows, use:
        // process.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe")
        
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
