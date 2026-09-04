import Foundation

/// ArgyllCMS CLI wrapper with colorimeter pre-initialization
/// Fix: Spyder X2 Ultra requires USB initialization before dispcal can detect it.
/// Solution: Run a brief dispread measurement first to wake up the sensor.
class ArgyllCMS {
    private let argyllPath: String
    
    init(argyllPath: String = "\(NSHomeDirectory())/Library/Application Support/DisplayCAL/dl/Argyll_V3.5.0/bin") {
        self.argyllPath = argyllPath
    }
    
    // MARK: - Tool Paths
    
    private func toolPath(_ name: String) -> String {
        return "\(argyllPath)/\(name)"
    }
    
    // MARK: - Display Detection
    
    func listDisplays() -> [String] {
        let output = run(toolPath("dispcal"), args: ["-l"])

        if output.contains("Instrument Access Failed") {
            print("[ArgyllCMS] ERROR: USB Instrument Access Failed. macOS 26+ requires explicit USB permission for the application. Please ensure Calibrex has USB access in System Settings → Privacy & Security.")
            return []
        }

        return parseDisplayList(output)
    }
    
    private func parseDisplayList(_ output: String) -> [String] {
        var displays: [String] = []
        for line in output.components(separatedBy: .newlines) {
            if line.contains("Display") {
                displays.append(line)
            }
        }
        return displays
    }
    
    // MARK: - Colorimeter Initialization (THE FIX)
    
    /// Pre-initialize the colorimeter by running a brief dispread measurement.
    /// This wakes up the Spyder X2 Ultra so dispcal can detect it.
    func initializeColorimeter(display: Int = 1) -> Bool {
        let result = run(toolPath("dispread"), args: [
            "-d\(display)",
            "-v",
            "-e"  // Exit after reading (don't display patches)
        ])

        if result.contains("Instrument Access Failed") {
            print("[ArgyllCMS] ERROR: USB Instrument Access Failed. macOS 26+ requires explicit USB permission for the application. Please ensure Calibrex has USB access in System Settings → Privacy & Security.")
            return false
        }

        return result.contains("Instrument") || result.contains("reading")
    }
    
    // MARK: - Calibration
    
    /// Run full calibration with pre-initialization
    func calibrateDisplay(display: Int = 1, outputFile: String) -> Bool {
        // Step 1: Pre-initialize the colorimeter
        print("[ArgyllCMS] Initializing colorimeter...")
        guard initializeColorimeter(display: display) else {
            print("[ArgyllCMS] ERROR: Failed to initialize colorimeter")
            return false
        }

        // Step 2: Run dispcal
        print("[ArgyllCMS] Running dispcal...")
        let result = run(toolPath("dispcal"), args: [
            "-d\(display)",
            "-v",
            "-o", outputFile
        ])

        if result.contains("Instrument Access Failed") {
            print("[ArgyllCMS] ERROR: USB Instrument Access Failed. macOS 26+ requires explicit USB permission for the application. Please ensure Calibrex has USB access in System Settings → Privacy & Security, or run calibration through DisplayCAL.")
            return false
        }

        return result.contains("Done") || !result.contains("Error")
    }
    
    /// Generate calibration targets
    func generateTargets(display: Int = 1, outputDir: String, patches: Int = 100) -> Bool {
        let result = run(toolPath("targen"), args: [
            "-d\(display)",
            "-v",
            "-p", String(patches),
            outputDir
        ])
        return result.contains("Done") || !result.contains("Error")
    }
    
    /// Display and read measurement patches
    func displayPatches(display: Int = 1, targetsFile: String) -> Bool {
        let result = run(toolPath("dispread"), args: [
            "-d\(display)",
            "-v",
            targetsFile
        ])
        return result.contains("Done") || !result.contains("Error")
    }
    
    /// Generate ICC profile from measurement data
    func generateProfile(measurementFile: String, profileName: String) -> Bool {
        let result = run(toolPath("colprof"), args: [
            "-v",
            "-a",  // Adaptive gamut mapping
            "-q", "m",  // Medium quality
            profileName
        ])
        return result.contains("Done") || !result.contains("Error")
    }
    
    /// Apply ICC profile to display
    func applyProfile(profilePath: String, display: Int = 1) -> Bool {
        let result = run(toolPath("dispwin"), args: [
            "-I",
            "-d\(display)",
            profilePath
        ])
        return result.contains("Done") || !result.contains("Error")
    }
    
    // MARK: - Spot Reading
    
    /// Take a single spot reading (for verification)
    func spotRead(display: Int = 1) -> (valid: Bool, x: Double, y: Double, Y: Double) {
        let result = run(toolPath("spotread"), args: [
            "-d\(display)",
            "-v"
        ])
        
        // Parse spotread output for XYZ values
        return parseSpotRead(result)
    }
    
    private func parseSpotRead(_ output: String) -> (valid: Bool, x: Double, y: Double, Y: Double) {
        // Implementation depends on spotread output format
        return (false, 0, 0, 0)
    }
    
    // MARK: - Utility
    
    private func run(_ command: String, args: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("[ArgyllCMS] Error running \(command): \(error)")
            return ""
        }
    }
}
