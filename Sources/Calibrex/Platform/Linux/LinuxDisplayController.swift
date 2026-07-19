import Foundation

/// Linux display controller using colord and xrandr
class LinuxDisplayController: DisplayControllerProtocol {
    
    // MARK: - Brightness
    
    func getBrightness() -> Double {
        // Try xrandr first
        if let brightness = getXrandrBrightness() {
            return brightness
        }
        
        // Try sysfs backlight
        if let brightness = getSysfsBrightness() {
            return brightness
        }
        
        return 0.5 // Default
    }
    
    func setBrightness(_ level: Double) -> Bool {
        let clamped = max(0.0, min(1.0, level))
        
        // Try xrandr
        if setXrandrBrightness(clamped) {
            return true
        }
        
        // Try sysfs
        if setSysfsBrightness(clamped) {
            return true
        }
        
        return false
    }
    
    // MARK: - White Point
    
    func getWhitePoint() -> Double {
        // Use colord to get current white point
        let output = execute(command: "colord", args: ["get-default-device"])
        
        // Parse output for color temperature
        // TODO: Implement colord query
        return 6500 // Default daylight
    }
    
    func setWhitePoint(_ kelvin: Double) -> Bool {
        // Use colord to set white point
        // TODO: Implement colord profile application
        return false
    }
    
    // MARK: - Blue Light Filter
    
    func isBlueLightFilterEnabled() -> Bool {
        // Check if Night Light is enabled via GNOME settings
        let output = execute(command: "gsettings", args: [
            "get", "org.gnome.settings-daemon.plugins.color", "night-light-enabled"
        ])
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }
    
    func setBlueLightFilter(_ enabled: Bool) -> Bool {
        let result = execute(command: "gsettings", args: [
            "set", "org.gnome.settings-daemon.plugins.color", "night-light-enabled",
            enabled ? "true" : "false"
        ])
        
        return result.isEmpty // Empty means success
    }
    
    func getBlueLightFilterTemperature() -> Double {
        let output = execute(command: "gsettings", args: [
            "get", "org.gnome.settings-daemon.plugins.color", "night-light-temperature"
        ])
        
        return Double(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 4000
    }
    
    func setBlueLightFilterTemperature(_ kelvin: Double) -> Bool {
        let result = execute(command: "gsettings", args: [
            "set", "org.gnome.settings-daemon.plugins.color", "night-light-temperature",
            String(Int(kelvin))
        ])
        
        return result.isEmpty
    }
    
    // MARK: - Display Info
    
    func supportsWideColorGamut() -> Bool {
        // Check via xrandr or colord
        return false // Conservative default
    }
    
    func getDisplayInfo() -> DisplayInfo {
        let name = getDisplayName()
        let resolution = getDisplayResolution()
        
        return DisplayInfo(
            name: name,
            manufacturer: "Unknown",
            model: name,
            serialNumber: nil,
            resolution: resolution,
            colorDepth: 24,
            supportsHDR: false,
            supportsTrueTone: false
        )
    }
    
    // MARK: - Private Helpers
    
    private func getXrandrBrightness() -> Double? {
        let output = execute(command: "xrandr", args: ["--verbose"])
        
        // Parse brightness from xrandr output
        for line in output.components(separatedBy: .newlines) {
            if line.contains("Brightness:") {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    return Double(parts[1].trimmingCharacters(in: .whitespaces))
                }
            }
        }
        
        return nil
    }
    
    private func setXrandrBrightness(_ level: Double) -> Bool {
        let output = execute(command: "xrandr", args: [
            "--output", getActiveOutput(),
            "--brightness", String(format: "%.2f", level)
        ])
        
        return output.isEmpty
    }
    
    private func getSysfsBrightness() -> Double? {
        let backlightPath = "/sys/class/backlight"
        
        guard let devices = try? FileManager.default.contentsOfDirectory(atPath: backlightPath) else {
            return nil
        }
        
        for device in devices {
            let maxPath = "\(backlightPath)/\(device)/max_brightness"
            let currentPath = "\(backlightPath)/\(device)/brightness"
            
            if let maxData = FileManager.default.contents(atPath: maxPath),
               let currentData = FileManager.default.contents(atPath: currentPath),
               let maxStr = String(data: maxData, encoding: .utf8),
               let currentStr = String(data: currentData, encoding: .utf8),
               let max = Double(maxStr.trimmingCharacters(in: .whitespacesAndNewlines)),
               let current = Double(currentStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return current / max
            }
        }
        
        return nil
    }
    
    private func setSysfsBrightness(_ level: Double) -> Bool {
        let backlightPath = "/sys/class/backlight"
        
        guard let devices = try? FileManager.default.contentsOfDirectory(atPath: backlightPath) else {
            return false
        }
        
        for device in devices {
            let maxPath = "\(backlightPath)/\(device)/max_brightness"
            let currentPath = "\(backlightPath)/\(device)/brightness"
            
            if let maxData = FileManager.default.contents(atPath: maxPath),
               let maxStr = String(data: maxData, encoding: .utf8),
               let max = Double(maxStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                let target = Int(level * max)
                let result = execute(command: "tee", args: [currentPath], input: String(target))
                return result.isEmpty
            }
        }
        
        return false
    }
    
    private func getActiveOutput() -> String {
        let output = execute(command: "xrandr", args: ["--query"])
        
        for line in output.components(separatedBy: .newlines) {
            if line.contains(" connected") && line.contains(" x ") {
                return line.components(separatedBy: " ").first ?? "eDP-1"
            }
        }
        
        return "eDP-1"
    }
    
    private func getDisplayName() -> String {
        let output = execute(command: "xrandr", args: ["--query"])
        
        // Parse display name from xrandr
        for line in output.components(separatedBy: .newlines) {
            if line.contains(" connected") {
                return line.components(separatedBy: " ").first ?? "Unknown Display"
            }
        }
        
        return "Unknown Display"
    }
    
    private func getDisplayResolution() -> String {
        let output = execute(command: "xrandr", args: ["--query"])
        
        // Parse resolution from xrandr
        for line in output.components(separatedBy: .newlines) {
            if line.contains(" connected") && line.contains(" x ") {
                let parts = line.components(separatedBy: " x ")
                if parts.count >= 2 {
                    return parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        return "Unknown"
    }
    
    private func execute(command: String, args: [String] = [], input: String? = nil) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/\(command)")
        process.arguments = args
        
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        
        if let input = input {
            let inPipe = Pipe()
            process.standardInput = inPipe
            inPipe.fileHandleForWriting.write(input.data(using: .utf8) ?? Data())
            inPipe.fileHandleForWriting.closeFile()
        }
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }
        
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
