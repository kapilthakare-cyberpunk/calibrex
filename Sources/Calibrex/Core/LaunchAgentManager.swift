import Foundation

/// Manages the launchd agent for Calibrex auto-start on login
class LaunchAgentManager {
    
    private let agentPlistName = "com.calibrex.daemon"
    private let agentLabel = "com.calibrex.daemon"
    
    private var agentDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents").path
    }
    
    private var agentPlistPath: String {
        return "\(agentDirectory)/\(agentPlistName).plist"
    }
    
    private var executablePath: String {
        // Get path to the Calibrex executable
        return Bundle.main.executablePath ?? "/usr/local/bin/calibrex"
    }
    
    // MARK: - Installation
    
    /// Install the launch agent
    func install() -> Bool {
        print("[LaunchAgent] Installing...")
        
        // 1. Create LaunchAgents directory if needed
        let fm = FileManager.default
        if !fm.fileExists(atPath: agentDirectory) {
            do {
                try fm.createDirectory(atPath: agentDirectory, withIntermediateDirectories: true)
                print("[LaunchAgent] Created \(agentDirectory)")
            } catch {
                print("[LaunchAgent] Failed to create directory: \(error)")
                return false
            }
        }
        
        // 2. Generate plist content
        let plistContent = generatePlist()
        
        // 3. Write plist file
        do {
            try plistContent.write(toFile: agentPlistPath, atomically: true, encoding: .utf8)
            print("[LaunchAgent] Wrote plist to \(agentPlistPath)")
        } catch {
            print("[LaunchAgent] Failed to write plist: \(error)")
            return false
        }
        
        // 4. Load the agent
        let result = loadAgent()
        
        if result {
            print("[LaunchAgent] Installed and loaded successfully")
        }
        
        return result
    }
    
    /// Uninstall the launch agent
    func uninstall() -> Bool {
        print("[LaunchAgent] Uninstalling...")
        
        // 1. Unload the agent
        _ = unloadAgent()
        
        // 2. Remove plist file
        let fm = FileManager.default
        if fm.fileExists(atPath: agentPlistPath) {
            do {
                try fm.removeItem(atPath: agentPlistPath)
                print("[LaunchAgent] Removed plist")
            } catch {
                print("[LaunchAgent] Failed to remove plist: \(error)")
                return false
            }
        }
        
        print("[LaunchAgent] Uninstalled successfully")
        return true
    }
    
    // MARK: - Load/Unload
    
    /// Load the launch agent
    func loadAgent() -> Bool {
        let result = execute(launchctl: ["load", "-w", agentPlistPath])
        
        if result {
            print("[LaunchAgent] Loaded")
        } else {
            print("[LaunchAgent] Failed to load")
        }
        
        return result
    }
    
    /// Unload the launch agent
    func unloadAgent() -> Bool {
        let result = execute(launchctl: ["unload", agentPlistPath])
        
        if result {
            print("[LaunchAgent] Unloaded")
        } else {
            print("[LaunchAgent] Failed to unload (may not be loaded)")
        }
        
        return result
    }
    
    /// Check if the agent is currently loaded
    func isLoaded() -> Bool {
        let result = execute(launchctl: ["list", agentLabel])
        return result && !lastOutput.contains("Could not find")
    }
    
    // MARK: - Status
    
    /// Get agent status
    func getStatus() -> AgentStatus {
        if !FileManager.default.fileExists(atPath: agentPlistPath) {
            return .notInstalled
        }
        
        if isLoaded() {
            return .loaded
        } else {
            return .installed
        }
    }
    
    // MARK: - Plist Generation
    
    private func generatePlist() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(agentLabel)</string>
            
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
                <string>--daemon</string>
            </array>
            
            <key>RunAtLoad</key>
            <true/>
            
            <key>KeepAlive</key>
            <dict>
                <key>SuccessfulExit</key>
                <false/>
            </dict>
            
            <key>StandardOutPath</key>
            <string>/tmp/calibrex_stdout.log</string>
            
            <key>StandardErrorPath</key>
            <string>/tmp/calibrex_stderr.log</string>
            
            <key>ProcessType</key>
            <string>Background</string>
            
            <key>Nice</key>
            <integer>10</integer>
            
            <key>ThrottleInterval</key>
            <integer>10</integer>
        </dict>
        </plist>
        """
    }
    
    // MARK: - Helpers
    
    private var lastOutput: String = ""
    
    private func execute(launchctl args: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            lastOutput = String(data: data, encoding: .utf8) ?? ""
            
            return process.terminationStatus == 0
        } catch {
            print("[LaunchAgent] Failed to execute launchctl: \(error)")
            return false
        }
    }
}

// MARK: - Types

enum AgentStatus {
    case notInstalled
    case installed
    case loaded
    
    var description: String {
        switch self {
        case .notInstalled:
            return "Not installed"
        case .installed:
            return "Installed (not loaded)"
        case .loaded:
            return "Loaded and running"
        }
    }
}

// MARK: - Convenience Extensions

extension LaunchAgentManager {
    
    /// Toggle agent on/off
    func toggle(enabled: Bool) -> Bool {
        if enabled {
            return loadAgent()
        } else {
            return unloadAgent()
        }
    }
    
    /// Restart the agent
    func restart() -> Bool {
        _ = unloadAgent()
        
        // Brief delay
        Thread.sleep(forTimeInterval: 1.0)
        
        return loadAgent()
    }
    
    /// Get log file paths
    func getLogPaths() -> (stdout: String, stderr: String) {
        return (
            stdout: "/tmp/calibrex_stdout.log",
            stderr: "/tmp/calibrex_stderr.log"
        )
    }
    
    /// Open logs in Console.app
    func openLogs() {
        let logs = getLogPaths()
        
        // Open both log files
        NSWorkspace.shared.open(URL(fileURLWithPath: logs.stdout))
        NSWorkspace.shared.open(URL(fileURLWithPath: logs.stderr))
    }
}
