import Foundation
import AppKit

/// macOS ambient light sensor (wraps existing AmbientLightSensor)
class MacOSAmbientLightSensor: AmbientLightProtocol {
    
    private let sensor = AmbientLightSensor()
    
    func open() -> Bool {
        return sensor.open()
    }
    
    func close() {
        sensor.close()
    }
    
    func readLux() -> Double? {
        return sensor.readLux()
    }
    
    var isAvailable: Bool {
        return sensor.isOpen
    }
}

/// macOS display controller (wraps existing CoreBrightness)
class MacDisplayController: DisplayControllerProtocol {
    
    private let coreBrightness = CoreBrightnessClient()
    
    init() {
        _ = coreBrightness.initialize()
    }
    
    func getBrightness() -> Double {
        return coreBrightness.getBrightness()
    }
    
    func setBrightness(_ level: Double) -> Bool {
        return coreBrightness.setBrightness(level)
    }
    
    func getWhitePoint() -> Double {
        return coreBrightness.getNightShiftTemperature()
    }
    
    func setWhitePoint(_ kelvin: Double) -> Bool {
        return coreBrightness.setNightShiftTemperature(kelvin)
    }
    
    func isBlueLightFilterEnabled() -> Bool {
        return coreBrightness.isNightShiftEnabled()
    }
    
    func setBlueLightFilter(_ enabled: Bool) -> Bool {
        return coreBrightness.setNightShift(enabled)
    }
    
    func getBlueLightFilterTemperature() -> Double {
        return coreBrightness.getNightShiftTemperature()
    }
    
    func setBlueLightFilterTemperature(_ kelvin: Double) -> Bool {
        return coreBrightness.setNightShiftTemperature(kelvin)
    }
    
    func supportsWideColorGamut() -> Bool {
        return true
    }
    
    func getDisplayInfo() -> DisplayInfo {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPDisplaysDataType"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try? process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        var name = "Unknown Display"
        var resolution = "Unknown"
        
        for line in output.components(separatedBy: .newlines) {
            if line.contains("Display Type:") {
                name = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? name
            }
            if line.contains("Resolution:") {
                resolution = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? resolution
            }
        }
        
        return DisplayInfo(
            name: name,
            manufacturer: "Apple",
            model: name,
            serialNumber: nil,
            resolution: resolution,
            colorDepth: 24,
            supportsHDR: true,
            supportsTrueTone: coreBrightness.supportsTrueTone()
        )
    }
}

/// macOS color profile manager
class MacOSColorProfileManager: ColorProfileProtocol {
    
    private let profileManager = ProfileManager()
    
    func getCurrentProfile() -> String? {
        return profileManager.currentProfilePath
    }
    
    func applyProfile(_ path: String) -> Bool {
        let argyll = ArgyllCMS()
        return argyll.applyProfile(path)
    }
    
    func listProfiles() -> [ColorProfile] {
        let profilesDir = "/Library/ColorSync/Profiles"
        var profiles: [ColorProfile] = []
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: profilesDir) else {
            return profiles
        }
        
        for file in files where file.hasSuffix(".icc") || file.hasSuffix(".icm") {
            let fullPath = "\(profilesDir)/\(file)"
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
        let profilesDir = "/Library/ColorSync/Profiles"
        
        do {
            let fileName = (path as NSString).lastPathComponent
            let destination = "\(profilesDir)/\(fileName)"
            
            try FileManager.default.copyItem(atPath: path, toPath: destination)
            return true
        } catch {
            print("[macOSColorProfile] Failed to install: \(error)")
            return false
        }
    }
    
    func removeProfile(_ path: String) -> Bool {
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            print("[macOSColorProfile] Failed to remove: \(error)")
            return false
        }
    }
    
    func getColorSpace() -> String {
        return "Display P3"
    }
}
