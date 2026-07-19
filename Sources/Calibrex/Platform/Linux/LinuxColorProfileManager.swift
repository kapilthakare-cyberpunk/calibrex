import Foundation

/// Linux color profile manager using colord
class LinuxColorProfileManager: ColorProfileProtocol {
    
    func getCurrentProfile() -> String? {
        // Get default device profile via colord
        let deviceID = execute(command: "colord", args: ["get-default-device"])
        
        guard !deviceID.isEmpty else { return nil }
        
        let profile = execute(command: "colord", args: ["get-default-profile", deviceID.trimmingCharacters(in: .whitespacesAndNewlines)])
        
        return profile.isEmpty ? nil : profile.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func applyProfile(_ path: String) -> Bool {
        let deviceID = execute(command: "colord", args: ["get-default-device"]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !deviceID.isEmpty else { return false }
        
        // Import profile to colord
        let importResult = execute(command: "colord", args: ["import-profile", path])
        
        // Get profile ID from import result
        let profileID = importResult.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Set as default for device
        let setResult = execute(command: "colord", args: ["set-default-profile", deviceID, profileID])
        
        return setResult.isEmpty
    }
    
    func listProfiles() -> [ColorProfile] {
        var profiles: [ColorProfile] = []
        
        // List system profiles
        let systemPaths = [
            "/usr/share/color/icc",
            "/usr/local/share/color/icc",
            "\(NSHomeDirectory())/.color/icc"
        ]
        
        for dirPath in systemPaths {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dirPath) else {
                continue
            }
            
            for file in files where file.hasSuffix(".icc") || file.hasSuffix(".icm") {
                let fullPath = "\(dirPath)/\(file)"
                let name = (file as NSString).deletingPathExtension
                
                profiles.append(ColorProfile(
                    name: name,
                    path: fullPath,
                    creationDate: try? FileManager.default.attributesOfItem(atPath: fullPath)[.creationDate] as? Date,
                    isDefault: fullPath == getCurrentProfile()
                ))
            }
        }
        
        return profiles
    }
    
    func installProfile(_ path: String) -> Bool {
        let systemPath = "/usr/share/color/icc"
        
        do {
            let fileName = (path as NSString).lastPathComponent
            let destination = "\(systemPath)/\(fileName)"
            
            try FileManager.default.copyItem(atPath: path, toPath: destination)
            
            // Import to colord
            _ = execute(command: "colord", args: ["import-profile", destination])
            
            return true
        } catch {
            print("[LinuxColorProfile] Failed to install: \(error)")
            return false
        }
    }
    
    func removeProfile(_ path: String) -> Bool {
        // Remove from colord
        let profileName = (path as NSString).lastPathComponent
        _ = execute(command: "colord", args: ["remove-profile", profileName])
        
        // Remove file
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            print("[LinuxColorProfile] Failed to remove: \(error)")
            return false
        }
    }
    
    func getColorSpace() -> String {
        let deviceID = execute(command: "colord", args: ["get-default-device"]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !deviceID.isEmpty else { return "sRGB" }
        
        let profile = execute(command: "colord", args: ["get-profile-colorspace", deviceID])
        
        return profile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "sRGB" : profile.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func execute(command: String, args: [String] = []) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/\(command)")
        process.arguments = args
        
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
