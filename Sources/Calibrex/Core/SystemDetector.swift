import Foundation
import AppKit

/// Detects system hardware and current state
class SystemDetector {
    
    struct SystemInfo {
        let osVersion: String
        let architecture: String
        let displayModel: String
        let displayManufacturer: String
        let gpuModel: String
        let connectedColorimeters: [String]
        let hasAmbientLightSensor: Bool
        let supportsTrueTone: Bool
        let supportsNightShift: Bool
    }
    
    private var systemInfo: SystemInfo?
    
    /// Detect system hardware on first run
    func detect() async {
        print("[SystemDetector] Detecting system hardware...")
        
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let arch = sysctlArchString()
        
        let displayInfo = await getDisplayInfo()
        let gpuInfo = getGPUInfo()
        let colorimeters = await detectColorimeters()
        let ambientSensor = detectAmbientLightSensor()
        let trueTone = detectTrueToneSupport()
        let nightShift = detectNightShiftSupport()
        
        systemInfo = SystemInfo(
            osVersion: osVersion,
            architecture: arch,
            displayModel: displayInfo.model,
            displayManufacturer: displayInfo.manufacturer,
            gpuModel: gpuInfo,
            connectedColorimeters: colorimeters,
            hasAmbientLightSensor: ambientSensor,
            supportsTrueTone: trueTone,
            supportsNightShift: nightShift
        )
        
        print("[SystemDetector] OS: \(osVersion) (\(arch))")
        print("[SystemDetector] Display: \(displayInfo.manufacturer) \(displayInfo.model)")
        print("[SystemDetector] GPU: \(gpuInfo)")
        print("[SystemDetector] Colorimeters: \(colorimeters.count) connected")
        print("[SystemDetector] Ambient light sensor: \(ambientSensor)")
        print("[SystemDetector] True Tone: \(trueTone), Night Shift: \(nightShift)")
    }
    
    /// Get the currently active application's bundle ID
    func currentAppBundle() async -> String {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
    }
    
    // MARK: - Display Info (EDID)
    
    private func getDisplayInfo() async -> (model: String, manufacturer: String) {
        // Read display EDID via IOKit
        // Returns display model and manufacturer
        
        // TODO: Implement IOKit EDID reading
        return ("Unknown Display", "Unknown")
    }
    
    // MARK: - GPU Info
    
    private func getGPUInfo() -> String {
        // Read GPU info via system_profiler
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPDisplaysDataType"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try? process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // Extract GPU model from output
        for line in output.components(separatedBy: .newlines) {
            if line.contains("Chipset Model:") || line.contains("Chip:") {
                return line.replacingOccurrences(of: "Chipset Model:", with: "")
                    .replacingOccurrences(of: "Chip:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        
        return "Unknown GPU"
    }
    
    // MARK: - Colorimeter Detection
    
    private func detectColorimeters() async -> [String] {
        // Detect USB colorimeters via IOKit
        // Supports: Datacolor Spyder, X-Rite i1 Display
        
        // TODO: Implement USB device enumeration
        return []
    }
    
    // MARK: - Sensor Detection
    
    private func detectAmbientLightSensor() -> Bool {
        // Check for MacBook ambient light sensor via IOKit HID
        // Available on MacBooks since ~2008
        
        // TODO: Implement IOKit HID check
        return false
    }
    
    // MARK: - Feature Detection
    
    private func detectTrueToneSupport() -> Bool {
        // Check if display supports True Tone via DisplayServices
        // Requires Apple Silicon Mac with built-in display or supported external
        
        // TODO: Implement DisplayServices check
        return false
    }
    
    private func detectNightShiftSupport() -> Bool {
        // Night Shift is supported on most Macs from 2012 onward
        // Check via CoreBrightness
        
        // TODO: Implement CoreBrightness check
        return true
    }
    
    // MARK: - Helpers
    
    private func sysctlArchString() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        
        return String(cString: machine)
    }
}
