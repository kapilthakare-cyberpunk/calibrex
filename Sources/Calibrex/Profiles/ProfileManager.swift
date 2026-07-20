import Foundation

/// Manages ICC profiles for display calibration
class ProfileManager {
    
    private let profilesDirectory: String
    
    var currentProfilePath: String?
    var profileHistory: [CalibrationRecord] = []
    
    struct CalibrationRecord {
        let profilePath: String
        let creationDate: Date
        let deltaE: Double
        let hardware: String
        let displayModel: String
    }
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        profilesDirectory = appSupport.appendingPathComponent("Calibrex/Profiles").path
        
        // Create profiles directory if needed
        try? FileManager.default.createDirectory(atPath: profilesDirectory, withIntermediateDirectories: true)
        
        loadHistory()
    }
    
    // MARK: - Profile Storage
    
    /// Store a new ICC profile
    func storeProfile(
        at tempPath: String,
        deltaE: Double,
        hardware: String,
        displayModel: String
    ) -> String? {
        let filename = "calibrex_\(formatDate(Date())).icc"
        let destination = "\(profilesDirectory)/\(filename)"
        
        do {
            // Copy profile to permanent location
            if FileManager.default.fileExists(atPath: destination) {
                try FileManager.default.removeItem(atPath: destination)
            }
            try FileManager.default.copyItem(atPath: tempPath, toPath: destination)
            
            // Add to history
            let record = CalibrationRecord(
                profilePath: destination,
                creationDate: Date(),
                deltaE: deltaE,
                hardware: hardware,
                displayModel: displayModel
            )
            profileHistory.append(record)
            currentProfilePath = destination
            
            saveHistory()
            
            print("[ProfileManager] Stored profile: \(filename)")
            return destination
            
        } catch {
            print("[ProfileManager] Failed to store profile: \(error)")
            return nil
        }
    }
    
    /// Get the most recent profile
    func latestProfile() -> CalibrationRecord? {
        return profileHistory.last
    }
    
    /// Get profile for specific date
    func profile(for date: Date) -> CalibrationRecord? {
        return profileHistory.first { record in
            Calendar.current.isDate(record.creationDate, inSameDayAs: date)
        }
    }
    
    // MARK: - Profile Activation
    
    /// Set a profile as active
    func activateProfile(_ record: CalibrationRecord) -> Bool {
        // Apply profile via ArgyllCMS dispwin
        let argyll = ArgyllCMS()
        let success = argyll.applyProfile(record.profilePath)
        
        if success {
            currentProfilePath = record.profilePath
            print("[ProfileManager] Activated profile: \(record.profilePath)")
        }
        
        return success
    }
    
    /// Restore the most recent profile
    func restoreLatestProfile() -> Bool {
        guard let latest = latestProfile() else {
            print("[ProfileManager] No profiles in history")
            return false
        }
        
        return activateProfile(latest)
    }
    
    // MARK: - Profile Management
    
    /// List all stored profiles
    func listProfiles() -> [CalibrationRecord] {
        return profileHistory
    }
    
    /// Delete a profile
    func deleteProfile(_ record: CalibrationRecord) -> Bool {
        do {
            try FileManager.default.removeItem(atPath: record.profilePath)
            profileHistory.removeAll { $0.profilePath == record.profilePath }
            saveHistory()
            
            print("[ProfileManager] Deleted profile: \(record.profilePath)")
            return true
            
        } catch {
            print("[ProfileManager] Failed to delete profile: \(error)")
            return false
        }
    }
    
    /// Clean old profiles (keep last N)
    func cleanOldProfiles(keeping keepCount: Int = 5) {
        guard profileHistory.count > keepCount else { return }
        
        let toRemove = profileHistory.prefix(profileHistory.count - keepCount)
        
        for record in toRemove {
            _ = deleteProfile(record)
        }
        
        print("[ProfileManager] Cleaned old profiles, keeping \(keepCount)")
    }
    
    // MARK: - Per-App Rules
    
    private var perAppRules: [String: ProfileAppRule] = [:]
    
    /// Load per-app rules from config
    func loadPerAppRules() -> [String: ProfileAppRule] {
        // TODO: Load from JSON config file
        return [
            "com.adobe.photoshop": ProfileAppRule(nightShift: "off", trueTone: "off"),
            "com.apple.FinalCutPro": ProfileAppRule(nightShift: "off", trueTone: "off"),
            "com.blackmagic-design.DaVinciResolve": ProfileAppRule(nightShift: "off", trueTone: "off")
        ]
    }
    
    /// Save per-app rules to config
    func savePerAppRules(_ rules: [String: ProfileAppRule]) {
        // TODO: Save to JSON config file
        perAppRules = rules
    }
    
    // MARK: - State Persistence
    
    private var historyFilePath: String {
        return "\(profilesDirectory)/history.json"
    }
    
    private func saveHistory() {
        let historyData: [[String: Any]] = profileHistory.map { record in
            [
                "profilePath": record.profilePath,
                "creationDate": record.creationDate.timeIntervalSince1970,
                "deltaE": record.deltaE,
                "hardware": record.hardware,
                "displayModel": record.displayModel
            ]
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: historyData) {
            try? data.write(to: URL(fileURLWithPath: historyFilePath))
        }
    }
    
    private func loadHistory() {
        guard let data = FileManager.default.contents(atPath: historyFilePath),
              let history = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }
        
        profileHistory = history.compactMap { dict in
            guard let path = dict["profilePath"] as? String,
                  let timestamp = dict["creationDate"] as? TimeInterval,
                  let deltaE = dict["deltaE"] as? Double,
                  let hardware = dict["hardware"] as? String,
                  let displayModel = dict["displayModel"] as? String else {
                return nil
            }
            
            return CalibrationRecord(
                profilePath: path,
                creationDate: Date(timeIntervalSince1970: timestamp),
                deltaE: deltaE,
                hardware: hardware,
                displayModel: displayModel
            )
        }
        
        currentProfilePath = profileHistory.last?.profilePath
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
}

struct ProfileAppRule {
    let nightShift: String // "on", "off", "default"
    let trueTone: String  // "on", "off", "default"
}
