import Foundation

/// Wrapper for ArgyllCMS command-line tools
/// Provides colorimeter reading, profile generation, and display calibration
class ArgyllCMS {
    
    private let argyllPath: String
    
    /// Initialize with path to ArgyllCMS binaries
    init(argyllPath: String = "/opt/homebrew/bin") {
        self.argyllPath = argyllPath
    }
    
    // MARK: - Colorimeter Detection
    
    /// Detect connected colorimeters
    func detectColorimeters() -> [ColorimeterDevice] {
        var devices: [ColorimeterDevice] = []
        
        // Use ArgyllCMS spotread to detect devices
        let output = execute(tool: "spotread", args: ["-v"])
        
        // Parse output for device list
        // Format: "1 = 'usb1: (Datacolor SpyderX2)'"
        for line in output.components(separatedBy: .newlines) {
            if line.contains("Spyder") || line.contains("i1") || line.contains("ColorMunki") {
                if let device = parseDeviceFromList(line) {
                    devices.append(device)
                }
            }
        }
        
        return devices
    }
    
    // MARK: - Display Measurement
    
    /// Read current display color with colorimeter
    /// Returns measured RGB and white point
    func readDisplay(device: ColorimeterDevice) -> DisplayMeasurement? {
        // spotread -c <device_number> reads the display
        let output = execute(tool: "spotread", args: ["-c", device.id, "-v"])
        
        guard !output.isEmpty else { return nil }
        
        return parseSpotReadOutput(output)
    }
    
    /// Read a single spot measurement
    func spotRead(device: ColorimeterDevice) -> (r: Double, g: Double, b: Double)? {
        let output = execute(tool: "spotread", args: ["-c", device.id, "-v"])
        
        guard !output.isEmpty else { return nil }
        
        return parseRGBFromSpotRead(output)
    }
    
    // MARK: - Target Generation
    
    /// Generate calibration target patches
    func generateTargets(profile: String = "lum", patches: Int = 100) -> String? {
        let outputDir = createTempDir()
        
        let result = execute(tool: "targen", args: [
            "-d", "-v",
            "\(patches)",
            outputDir.appending("/calib")
        ])
        
        guard result.contains("Created") else { return nil }
        
        return outputDir
    }
    
    // MARK: - Display Calibration
    
    /// Run display calibration measurement sequence
    func calibrateDisplay(
        device: ColorimeterDevice,
        targetsDir: String,
        progressHandler: ((Int, Int) -> Void)? = nil
    ) -> Bool {
        // dispread reads each target patch
        let output = execute(tool: "dispread", args: [
            "-d", device.id,
            "-v",
            "-yl",  // Use display white level
            targetsDir.appending("/calib")
        ])
        
        // Parse progress from output
        if let handler = progressHandler {
            let progress = parseProgress(output)
            handler(progress.current, progress.total)
        }
        
        return output.contains("Patch") || output.contains("done")
    }
    
    // MARK: - Profile Generation
    
    /// Generate ICC profile from calibration data
    func generateProfile(
        from targetsDir: String,
        quality: ProfileQuality = .high,
        outputName: String = "calibrex"
    ) -> String? {
        let outputPath = "\(targetsDir)/\(outputName).icc"
        
        let qualityFlag = quality.flag
        
        let result = execute(tool: "colprof", args: [
            qualityFlag,
            "-qh",  // High quality
            "-a",   // Adaptive white point
            "-g",   // Use gamma TRC
            "-b 16", // 16-bit output
            targetsDir.appending("/calib")
        ])
        
        guard result.contains("Generated") || result.contains(".icc") else { return nil }
        
        return outputPath
    }
    
    // MARK: - Profile Verification
    
    /// Verify display against ICC profile (delta-E measurement)
    func verifyProfile(
        device: ColorimeterDevice,
        profilePath: String
    ) -> Double? {
        // Use dispread with verification mode
        let output = execute(tool: "dispread", args: [
            "-d", device.id,
            "-v",
            "-k", profilePath
        ])
        
        // Parse delta-E from output
        return parseDeltaE(output)
    }
    
    // MARK: - Profile Application
    
    /// Apply ICC profile to display
    func applyProfile(_ profilePath: String) -> Bool {
        // On macOS, profiles are applied via ColorSync
        // This command sets the profile for the current display
        
        let result = execute(tool: "dispwin", args: [
            "-I", profilePath
        ])
        
        return result.contains("Installed") || result.isEmpty
    }
    
    // MARK: - Execution Helpers
    
    private func execute(tool: String, args: [String]) -> String {
        let toolPath = "\(argyllPath)/\(tool)"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("[ArgyllCMS] Failed to execute \(tool): \(error)")
            return ""
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func createTempDir() -> String {
        let tempDir = NSTemporaryDirectory()
        let calibDir = "\(tempDir)/calibrex_\(UUID().uuidString.prefix(8))"
        try? FileManager.default.createDirectory(atPath: calibDir, withIntermediateDirectories: true)
        return calibDir
    }
    
    // MARK: - Parsing Helpers
    
    private func parseDeviceFromList(_ line: String) -> ColorimeterDevice? {
        // Parse device from ArgyllCMS device list
        // Format: "1 = 'usb1: (Datacolor SpyderX2)'"
        guard line.contains("=") else { return nil }
        
        let parts = line.components(separatedBy: "=")
        guard parts.count >= 2 else { return nil }
        
        let id = parts[0].trimmingCharacters(in: .whitespaces)
        let deviceInfo = parts[1].trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        // Determine device type
        let type: ColorimeterType
        if deviceInfo.contains("Spyder") {
            type = .spyder
        } else if deviceInfo.contains("i1 Display") {
            type = .i1Display
        } else if deviceInfo.contains("i1 Pro") {
            type = .i1Pro
        } else if deviceInfo.contains("ColorMunki") {
            type = .colorMunki
        } else {
            return nil
        }
        
        return ColorimeterDevice(
            id: id,
            name: deviceInfo,
            type: type
        )
    }
    
    private func parseSpotReadOutput(_ output: String) -> DisplayMeasurement? {
        // Parse RGB and white point from spotread output
        // Format: "Patch 1: R=0.5 G=0.4 B=0.3 Wx=0.3 Wy=0.3"
        
        guard let range = output.range(of: "Patch") else { return nil }
        
        // TODO: Implement proper parsing
        return DisplayMeasurement(
            r: 0.5, g: 0.5, b: 0.5,
            whitePointX: 0.3127, whitePointY: 0.3290,
            lux: 0
        )
    }
    
    private func parseRGBFromSpotRead(_ output: String) -> (r: Double, g: Double, b: Double)? {
        // TODO: Implement RGB parsing
        return (0.5, 0.5, 0.5)
    }
    
    private func parseProgress(_ output: String) -> (current: Int, total: Int) {
        var current = 0
        var total = 0
        
        for line in output.components(separatedBy: .newlines) {
            if line.contains("Patch") {
                current += 1
            }
            if line.contains("of") {
                // Parse "Patch X of Y"
                let parts = line.components(separatedBy: " ")
                if let idx = parts.firstIndex(of: "of"),
                   let totalStr = parts[safe: idx + 1],
                   let t = Int(totalStr) {
                    total = t
                }
            }
        }
        
        return (current, total)
    }
    
    private func parseDeltaE(_ output: String) -> Double? {
        // Parse delta-E value from verification output
        for line in output.components(separatedBy: .newlines) {
            if line.contains("delta") || line.contains("dE") {
                // Extract numeric value
                let numbers = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap { Double($0) }
                return numbers.first
            }
        }
        return nil
    }
}

// MARK: - Types

struct ColorimeterDevice: Hashable {
    let id: String
    let name: String
    let type: ColorimeterType
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ColorimeterDevice, rhs: ColorimeterDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

enum ColorimeterType: Hashable {
    case spyder
    case i1Display
    case i1Pro
    case colorMunki
}

struct DisplayMeasurement {
    let r: Double
    let g: Double
    let b: Double
    let whitePointX: Double
    let whitePointY: Double
    let lux: Double
}

enum ProfileQuality {
    case low      // -ql
    case medium   // -qm
    case high     // -qh
    case proof    // -qp
    
    var flag: String {
        switch self {
        case .low:    return "-ql"
        case .medium: return "-qm"
        case .high:   return "-qh"
        case .proof:  return "-qp"
        }
    }
}

// MARK: - Array Safe Access

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
