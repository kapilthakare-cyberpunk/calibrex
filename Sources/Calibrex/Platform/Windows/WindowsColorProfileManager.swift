import Foundation

/// Windows color profile manager using WCS (Windows Color System)
class WindowsColorProfileManager: ColorProfileProtocol {
    
    private let systemProfilesPath = "C:\\Windows\\System32\\spool\\drivers\\color"
    
    func getCurrentProfile() -> String? {
        // Get current ICC profile via PowerShell
        let output = executePowershell(command: """
            Get-ItemProperty -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ICM\\ProfileAssociations\\Display" -Name "Active" -ErrorAction SilentlyContinue | SelectObject -ExpandProperty Active
        """)
        
        let profileName = output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !profileName.isEmpty else { return nil }
        
        return "\(systemProfilesPath)\\\(profileName)"
    }
    
    func applyProfile(_ path: String) -> Bool {
        let fileName = (path as NSString).lastPathComponent
        
        // Apply profile via PowerShell
        let output = executePowershell(command: """
            & "C:\\Windows\\System32\\iccload.exe" "\\?\(path)"
        """)
        
        // Alternative: Set registry
        let setResult = executePowershell(command: """
            Set-ItemProperty -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ICM\\ProfileAssociations\\Display" -Name "Active" -Value "\(fileName)"
        """)
        
        return setResult.isEmpty
    }
    
    func listProfiles() -> [ColorProfile] {
        var profiles: [ColorProfile] = []
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: systemProfilesPath) else {
            return profiles
        }
        
        for file in files where file.hasSuffix(".icc") || file.hasSuffix(".icm") {
            let fullPath = "\(systemProfilesPath)\\\(file)"
            let name = (file as NSString).deletingPathExtension
            
            profiles.append(ColorProfile(
                name: name,
                path: fullPath,
                creationDate: try? FileManager.default.attributesOfItem(atPath: fullPath)[.creationDate] as? Date,
                isDefault: fullPath == getCurrentProfile()
            ))
        }
        
        return profiles
    }
    
    func installProfile(_ path: String) -> Bool {
        do {
            let fileName = (path as NSString).lastPathComponent
            let destination = "\(systemProfilesPath)\\\(fileName)"
            
            try FileManager.default.copyItem(atPath: path, toPath: destination)
            
            // Register with WCS
            _ = executePowershell(command: """
                & "C:\\Windows\\System32\\iccload.exe" "\\?\(destination)"
            """)
            
            return true
        } catch {
            print("[WindowsColorProfile] Failed to install: \(error)")
            return false
        }
    }
    
    func removeProfile(_ path: String) -> Bool {
        // Unregister from WCS
        _ = executePowershell(command: """
            & "C:\\Windows\\System32\\iccuninstall.exe" "\\?\(path)"
        """)
        
        // Remove file
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            print("[WindowsColorProfile] Failed to remove: \(error)")
            return false
        }
    }
    
    func getColorSpace() -> String {
        // Get display color space via PowerShell
        let output = executePowershell(command: """
            Get-CimInstance -ClassName Win32_VideoController | SelectObject -First 1 -ExpandProperty VideoModeDescription
        """)
        
        let description = output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if description.contains("HDR") {
            return "DCI-P3"
        } else if description.contains("Wide") {
            return "Adobe RGB"
        }
        
        return "sRGB"
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
