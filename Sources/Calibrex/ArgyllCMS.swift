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
    func initializeColorimeter(display: Int = 1, port: Int = 1) -> Bool {
        // Run a short, non-interactive read to wake up the colorimeter and verify
        // access. `-Y p` skips the "place instrument" wait. dispread has no `-e`
        // flag, so we point it at a throwaway per-display output file.
        let probe = NSTemporaryDirectory() + "calibrex_probe_\(display).ti1"
        let result = run(toolPath("dispread"), args: [
            "-d\(display)",
            "-c\(port)",
            "-Y", "p",
            "-v",
            probe
        ])
        try? FileManager.default.removeItem(atPath: probe)

        if result.contains("Instrument Access Failed") {
            print("[ArgyllCMS] ERROR: USB Instrument Access Failed. macOS 26+ requires explicit USB permission for the application. Please ensure Calibrex has USB access in System Settings → Privacy & Security.")
            return false
        }

        // dispread exits non-zero / reports when it can't open the instrument,
        // even on a non-fatal read. Look for an explicit access failure message too.
        if result.contains("new_disprd() failed") || result.contains("Instrument Access Failed") {
            return false
        }
        return true
    }
    
    // MARK: - Calibration
    
    /// Run full calibration with pre-initialization
    func calibrateDisplay(display: Int = 1, port: Int = 1,
                          whiteTemp: Int = 5000, gamma: Double = 2.2,
                          quality: String = "m", brightness: Int = 100,
                          outputFile: String) -> Bool {
        // Step 1: Pre-initialize the colorimeter
        print("[ArgyllCMS] Initializing colorimeter...")
        guard initializeColorimeter(display: display, port: port) else {
            print("[ArgyllCMS] ERROR: Failed to initialize colorimeter")
            return false
        }

        // Step 2: Run dispcal. dispcal takes a base output path (no extension) and
        // writes <base>.cal and <base>.icc if -o is used. We intentionally skip -o
        // here so a standalone .cal is produced without prematurely building a
        // profile; pass each flag/value as SEPARATE argv entries (dispcal rejects
        // tokens like "-q m" with a single-space value).
        print("[ArgyllCMS] Running dispcal...")
        let result = run(toolPath("dispcal"), args: [
            "-v",
            "-d\(display)",
            "-c\(port)",
            "-y", "l",
            "-q", quality,
            "-t", "\(whiteTemp)",
            "-g", "\(gamma)",
            "-b", "\(brightness)",
            "-Y", "p",
            outputFile
        ])

        if result.contains("Instrument Access Failed") || result.contains("new_disprd() failed") {
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
        if printIfInstrumentError(run(toolPath("spotread"), args: ["-d\(display)", "-v"])) {
            return (false, 0, 0, 0)
        }
        let result = run(toolPath("spotread"), args: ["-d\(display)", "-v"])

        // Parse spotread output for XYZ values
        return parseSpotRead(result)
    }

    /// Returns true (and prints a helpful message) if the supplied Argyll output
    /// indicates the instrument could not be accessed.
    private func printIfInstrumentError(_ output: String) -> Bool {
        guard output.contains("Instrument Access Failed") || output.contains("new_disprd() failed") else {
            return false
        }
        print("[ArgyllCMS] ERROR: USB Instrument Access Failed. macOS 26+ requires explicit USB permission for the application. Please ensure Calibrex has USB access in System Settings → Privacy & Security.")
        return true
    }

    private func parseSpotRead(_ output: String) -> (valid: Bool, x: Double, y: Double, Y: Double) {
        // Argyll spotread prints a line like:
        //   X: 0.3127  Y: 0.3290  Z: 0.3582  ...
        // plus XYZ_master / XYZ fields. We look for 'x:', 'y:' and 'Y:' tokens.
        var x: Double?
        var y: Double?
        var Y: Double?

        let words = output.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\r" || $0 == "\t" })
        var i = 0
        while i < words.count {
            let w = String(words[i]).lowercased()
            if (w == "x:" || w == "x") && i + 1 < words.count, x == nil {
                x = Double(words[i + 1])
                i += 1
            } else if (w == "y:" || w == "y") && i + 1 < words.count, y == nil {
                y = Double(words[i + 1])
                i += 1
            } else if (w == "y:" || w == "y") && i + 1 < words.count, Y == nil {
                // Y (luminance) appears as a capital-Y field in the same listing.
                Y = Double(words[i + 1])
                i += 1
            }
            i += 1
        }

        guard let xv = x, let yv = y, let Yv = Y else {
            return (false, 0, 0, 0)
        }
        return (true, xv, yv, Yv)
    }
    
    // MARK: - Full Automation Flow

    /// Run a fully automated calibration sequence: init -> measure -> profile -> apply
    func runFullCalibration(display: Int = 1, profileName: String, progress: (Double) -> Void) -> Bool {
        print("[ArgyllCMS] Starting fully automated calibration flow...")
        progress(0.1)

        // Step 1: Pre-initialize the colorimeter
        guard initializeColorimeter(display: display) else {
            print("[ArgyllCMS] ERROR: Hardware initialization failed")
            return false
        }
        progress(0.2)

        // Step 2: Measure (dispcal)
        let calFile = "temp_\(display).cal"
        print("[ArgyllCMS] Measuring display (dispcal)...")
        let measureResult = run(toolPath("dispcal"), args: [
            "-d\(display)",
            "-v",
            "-o", calFile
        ])

        if measureResult.contains("Instrument Access Failed") {
            print("[ArgyllCMS] ERROR: USB Instrument Access Failed. macOS 26+ requires explicit USB permission.")
            return false
        }

        guard measureResult.contains("Done") || !measureResult.contains("Error") else {
            print("[ArgyllCMS] ERROR: Measurement phase failed")
            return false
        }
        progress(0.6)

        // Step 3: Generate Profile (colprof)
        print("[ArgyllCMS] Generating ICC profile (colprof)...")
        let profileResult = run(toolPath("colprof"), args: [
            "-v",
            "-a",
            "-q", "m",
            calFile,
            profileName
        ])

        guard profileResult.contains("Done") || !profileResult.contains("Error") else {
            print("[ArgyllCMS] ERROR: Profiling phase failed")
            return false
        }
        progress(0.8)

        // Step 4: Apply Profile
        print("[ArgyllCMS] Applying profile...")
        guard applyProfile(profilePath: profileName, display: display) else {
            print("[ArgyllCMS] ERROR: Failed to apply profile")
            return false
        }
        progress(1.0)

        // Step 5: Export Profile
        print("[ArgyllCMS] Exporting profile...")
        exportProfile(profilePath: profileName)

        print("[ArgyllCMS] Full calibration flow completed successfully.")
        return true
    }

    /// Export the generated ICC profile to the user's Desktop
    func exportProfile(profilePath: String) -> Bool {
        let fileManager = FileManager.default
        let desktopPath = NSString(string: NSHomeDirectory()).appendingPathComponent("Desktop")
        let destinationURL = URL(fileURLWithPath: desktopPath).appendingPathComponent("calibrex_profile.icc")

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(atPath: profilePath, toPath: destinationURL.path)
            print("[ArgyllCMS] Profile exported to: \(destinationURL.path)")
            return true
        } catch {
            print("[ArgyllCMS] Error exporting profile: \(error)")
            return false
        }
    }
    
    private func run(_ command: String, args: [String]) -> String {
        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()

            // Drain both pipes concurrently BEFORE waiting, otherwise a child that
            // produces a lot of output can fill the pipe buffer and deadlock on
            // waitUntilExit().
            let outGroup = DispatchGroup()
            var outData = Data()
            outGroup.enter()
            DispatchQueue.global().async {
                outData = (try? outPipe.fileHandleForReading.readToEnd()) ?? Data()
                outGroup.leave()
            }
            var errData = Data()
            outGroup.enter()
            DispatchQueue.global().async {
                errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
                outGroup.leave()
            }

            process.waitUntilExit()
            outGroup.wait()

            let stdout = String(data: outData, encoding: .utf8) ?? ""
            let stderr = String(data: errData, encoding: .utf8) ?? ""
            return stdout.isEmpty ? stderr : stdout
        } catch {
            print("[ArgyllCMS] Error running \(command): \(error)")
            return ""
        }
    }
}
