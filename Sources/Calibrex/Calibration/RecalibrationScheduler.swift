import Foundation

/// Manages periodic recalibration and drift detection
class RecalibrationScheduler {
    
    private let argyll: ArgyllCMS
    private let profileManager: ProfileManager
    private let config: RecalibrationConfig
    
    private var lastCalibrationDate: Date?
    private var lastSpotCheckDate: Date?
    private var lastDeltaE: Double = 0
    
    struct RecalibrationConfig {
        let monthlyEnabled: Bool
        let spotCheckIntervalDays: Int
        let deltaEThreshold: Double
        
        static let `default` = RecalibrationConfig(
            monthlyEnabled: true,
            spotCheckIntervalDays: 7,
            deltaEThreshold: 3.0
        )
    }
    
    init(
        argyll: ArgyllCMS,
        profileManager: ProfileManager,
        config: RecalibrationConfig = .default
    ) {
        self.argyll = argyll
        self.profileManager = profileManager
        self.config = config
        loadState()
    }
    
    // MARK: - Main Check Loop
    
    /// Check if recalibration is needed
    /// Returns the type of recalibration needed, or nil
    func checkRecalibrationNeeded() -> RecalibrationType? {
        // Priority: drift-triggered > scheduled monthly > spot-check
        
        // 1. Check drift from last spot-check
        if let driftCheck = checkDriftNeeded() {
            return driftCheck
        }
        
        // 2. Check monthly schedule
        if let monthlyCheck = checkMonthlyNeeded() {
            return monthlyCheck
        }
        
        // 3. Check spot-check schedule
        if let spotCheck = checkSpotCheckNeeded() {
            return spotCheck
        }
        
        return nil
    }
    
    // MARK: - Drift Detection
    
    private func checkDriftNeeded() -> RecalibrationType? {
        guard let lastCheck = lastSpotCheckDate else { return nil }
        
        // Only check drift if we have a previous measurement
        guard lastDeltaE > 0 else { return nil }
        
        // If delta-E is above threshold, recommend recalibration
        if lastDeltaE > config.deltaEThreshold {
            print("[Scheduler] Drift detected: delta-E \(String(format: "%.1f", lastDeltaE)) > \(config.deltaEThreshold)")
            return .driftDetected(deltaE: lastDeltaE)
        }
        
        return nil
    }
    
    // MARK: - Monthly Schedule
    
    private func checkMonthlyNeeded() -> RecalibrationType? {
        guard config.monthlyEnabled else { return nil }
        
        guard let lastCal = lastCalibrationDate else {
            // Never calibrated, recommend first calibration
            return .firstCalibration
        }
        
        let daysSinceLastCal = Calendar.current.dateComponents([.day], from: lastCal, to: Date()).day ?? 0
        
        if daysSinceLastCal >= 30 {
            print("[Scheduler] Monthly recalibration due: \(daysSinceLastCal) days since last calibration")
            return .monthlyDue(lastCalibration: lastCal, daysSince: daysSinceLastCal)
        }
        
        return nil
    }
    
    // MARK: - Spot-Check Schedule
    
    private func checkSpotCheckNeeded() -> RecalibrationType? {
        guard let lastCheck = lastSpotCheckDate else {
            // Never spot-checked, recommend first check
            return .firstSpotCheck
        }
        
        let daysSinceLastCheck = Calendar.current.dateComponents([.day], from: lastCheck, to: Date()).day ?? 0
        
        if daysSinceLastCheck >= config.spotCheckIntervalDays {
            print("[Scheduler] Spot-check due: \(daysSinceLastCheck) days since last check")
            return .spotCheckDue(lastCheck: lastCheck, daysSince: daysSinceLastCheck)
        }
        
        return nil
    }
    
    // MARK: - Execute Recalibration
    
    /// Execute full recalibration with colorimeter
    func executeFullCalibration(device: ColorimeterDevice) async -> CalibrationResult {
        print("[Scheduler] Starting full calibration...")
        
        // 1. Generate targets
        guard let targetsDir = argyll.generateTargets() else {
            return .failed(error: "Failed to generate targets")
        }
        
        // 2. Run display measurement
        let success = argyll.calibrateDisplay(
            device: device,
            targetsDir: targetsDir
        ) { current, total in
            let progress = Double(current) / Double(total) * 100
            print("[Scheduler] Calibration progress: \(Int(progress))%")
        }
        
        guard success else {
            return .failed(error: "Display measurement failed")
        }
        
        // 3. Generate ICC profile
        let profileName = "calibrex_\(formatDate(Date()))"
        guard let profilePath = argyll.generateProfile(
            from: targetsDir,
            quality: .high,
            outputName: profileName
        ) else {
            return .failed(error: "Profile generation failed")
        }
        
        // 4. Apply profile
        let applied = argyll.applyProfile(profilePath)
        guard applied else {
            return .failed(error: "Profile application failed")
        }
        
        // 5. Verify profile
        if let deltaE = argyll.verifyProfile(device: device, profilePath: profilePath) {
            lastDeltaE = deltaE
            print("[Scheduler] Calibration complete - delta-E: \(String(format: "%.1f", deltaE))")
        }
        
        // 6. Update state
        lastCalibrationDate = Date()
        lastSpotCheckDate = Date()
        saveState()
        
        return .success(
            profilePath: profilePath,
            deltaE: lastDeltaE,
            date: Date()
        )
    }
    
    /// Execute spot-check verification
    func executeSpotCheck(device: ColorimeterDevice) async -> SpotCheckResult {
        print("[Scheduler] Starting spot-check...")
        
        guard let currentProfile = profileManager.currentProfilePath else {
            return .noProfile
        }
        
        // Read spot measurement
        guard let (r, g, b) = argyll.spotRead(device: device) else {
            return .measurementFailed
        }
        
        // Verify against profile
        if let deltaE = argyll.verifyProfile(device: device, profilePath: currentProfile) {
            lastDeltaE = deltaE
            lastSpotCheckDate = Date()
            saveState()
            
            print("[Scheduler] Spot-check complete - delta-E: \(String(format: "%.1f", deltaE))")
            
            if deltaE > config.deltaEThreshold {
                return .driftDetected(deltaE: deltaE)
            } else {
                return .accurate(deltaE: deltaE)
            }
        }
        
        return .measurementFailed
    }
    
    // MARK: - State Persistence
    
    private var stateFilePath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Calibrex/recalibration_state.json").path
    }
    
    private func saveState() {
        let state: [String: Any] = [
            "lastCalibrationDate": lastCalibrationDate?.timeIntervalSince1970 ?? 0,
            "lastSpotCheckDate": lastSpotCheckDate?.timeIntervalSince1970 ?? 0,
            "lastDeltaE": lastDeltaE
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: state) {
            try? data.write(to: URL(fileURLWithPath: stateFilePath))
        }
    }
    
    private func loadState() {
        guard let data = FileManager.default.contents(atPath: stateFilePath),
              let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        if let calTimestamp = state["lastCalibrationDate"] as? TimeInterval, calTimestamp > 0 {
            lastCalibrationDate = Date(timeIntervalSince1970: calTimestamp)
        }
        if let checkTimestamp = state["lastSpotCheckDate"] as? TimeInterval, checkTimestamp > 0 {
            lastSpotCheckDate = Date(timeIntervalSince1970: checkTimestamp)
        }
        lastDeltaE = state["lastDeltaE"] as? Double ?? 0
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}

// MARK: - Types

enum RecalibrationType {
    case firstCalibration
    case firstSpotCheck
    case monthlyDue(lastCalibration: Date, daysSince: Int)
    case spotCheckDue(lastCheck: Date, daysSince: Int)
    case driftDetected(deltaE: Double)
    
    var description: String {
        switch self {
        case .firstCalibration:
            return "First calibration recommended"
        case .firstSpotCheck:
            return "First spot-check recommended"
        case .monthlyDue(_, let days):
            return "Monthly recalibration due (\(days) days since last)"
        case .spotCheckDue(_, let days):
            return "Spot-check due (\(days) days since last)"
        case .driftDetected(let deltaE):
            return "Display drift detected (delta-E: \(String(format: "%.1f", deltaE)))"
        }
    }
}

enum CalibrationResult {
    case success(profilePath: String, deltaE: Double, date: Date)
    case failed(error: String)
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

enum SpotCheckResult {
    case accurate(deltaE: Double)
    case driftDetected(deltaE: Double)
    case noProfile
    case measurementFailed
}
