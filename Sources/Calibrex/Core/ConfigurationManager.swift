import Foundation

/// Manages Calibrex configuration
class ConfigurationManager {
    
    private let configDirectory: String
    private let configFile: String
    
    private(set) var config: CalibrexConfig
    
    struct CalibrexConfig {
        var daemon: DaemonSettings
        var recalibration: RecalibrationSettings
        var perAppRules: [String: AppRuleConfig]
        var profiles: ProfileSettings
        
        struct DaemonSettings {
            var pollIntervalLux: Double
            var pollIntervalColorTemp: Double
            var pollIntervalTemperature: Double
            var transitionDuration: Double
            var luxChangeThreshold: Double
            var colorTempChangeThreshold: Double
            var launchAtLogin: Bool
            var showMenuBarIcon: Bool
            
            static let `default` = DaemonSettings(
                pollIntervalLux: 60,
                pollIntervalColorTemp: 120,
                pollIntervalTemperature: 300,
                transitionDuration: 2.0,
                luxChangeThreshold: 0.15,
                colorTempChangeThreshold: 200,
                launchAtLogin: true,
                showMenuBarIcon: true
            )
        }
        
        struct RecalibrationSettings {
            var monthlyEnabled: Bool
            var spotCheckIntervalDays: Int
            var deltaEThreshold: Double
            var autoRecalibrate: Bool
            
            static let `default` = RecalibrationSettings(
                monthlyEnabled: true,
                spotCheckIntervalDays: 7,
                deltaEThreshold: 3.0,
                autoRecalibrate: false
            )
        }
        
        struct AppRuleConfig {
            var nightShift: String
            var trueTone: String
            var profileOverride: String?
        }
        
        struct ProfileSettings {
            var maxProfiles: Int
            var defaultQuality: String
            var autoClean: Bool
            
            static let `default` = ProfileSettings(
                maxProfiles: 5,
                defaultQuality: "high",
                autoClean: true
            )
        }
        
        static let `default` = CalibrexConfig(
            daemon: .default,
            recalibration: .default,
            perAppRules: [
                "com.adobe.photoshop": AppRuleConfig(nightShift: "off", trueTone: "off", profileOverride: nil),
                "com.apple.FinalCutPro": AppRuleConfig(nightShift: "off", trueTone: "off", profileOverride: nil),
                "com.blackmagic-design.DaVinciResolve": AppRuleConfig(nightShift: "off", trueTone: "off", profileOverride: nil),
                "com.adobe.illustrator": AppRuleConfig(nightShift: "off", trueTone: "off", profileOverride: nil),
                "com.sketch Sketch": AppRuleConfig(nightShift: "off", trueTone: "off", profileOverride: nil),
                "com.bohemiancoding.sketch3": AppRuleConfig(nightShift: "off", trueTone: "off", profileOverride: nil)
            ],
            profiles: .default
        )
    }
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        configDirectory = appSupport.appendingPathComponent("Calibrex").path
        configFile = configDirectory.appending("/config.json")
        
        // Create config directory if needed
        try? FileManager.default.createDirectory(atPath: configDirectory, withIntermediateDirectories: true)
        
        // Load or create default config
        config = ConfigurationManager.loadConfig(from: configFile) ?? .default
    }
    
    // MARK: - Load/Save
    
    private static func loadConfig(from path: String) -> CalibrexConfig? {
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return parseConfig(json)
    }
    
    func save() {
        let json = configToJSON(config)
        
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
            print("[Config] Failed to serialize config")
            return
        }
        
        do {
            try data.write(to: URL(fileURLWithPath: configFile))
            print("[Config] Saved to \(configFile)")
        } catch {
            print("[Config] Failed to save: \(error)")
        }
    }
    
    // MARK: - Config Access
    
    func updateDaemonSettings(_ update: (inout CalibrexConfig.DaemonSettings) -> Void) {
        update(&config.daemon)
        save()
    }
    
    func updateRecalibrationSettings(_ update: (inout CalibrexConfig.RecalibrationSettings) -> Void) {
        update(&config.recalibration)
        save()
    }
    
    func setAppRule(for bundleID: String, rule: CalibrexConfig.AppRuleConfig) {
        config.perAppRules[bundleID] = rule
        save()
    }
    
    func removeAppRule(for bundleID: String) {
        config.perAppRules.removeValue(forKey: bundleID)
        save()
    }
    
    func getAppRule(for bundleID: String) -> CalibrexConfig.AppRuleConfig? {
        return config.perAppRules[bundleID]
    }
    
    // MARK: - JSON Parsing
    
    private static func parseConfig(_ json: [String: Any]) -> CalibrexConfig? {
        var config = CalibrexConfig.default
        
        // Parse daemon settings
        if let daemon = json["daemon"] as? [String: Any] {
            config.daemon = CalibrexConfig.DaemonSettings(
                pollIntervalLux: daemon["poll_interval_lux"] as? Double ?? 60,
                pollIntervalColorTemp: daemon["poll_interval_color_temp"] as? Double ?? 120,
                pollIntervalTemperature: daemon["poll_interval_temperature"] as? Double ?? 300,
                transitionDuration: daemon["transition_duration"] as? Double ?? 2.0,
                luxChangeThreshold: daemon["lux_change_threshold"] as? Double ?? 0.15,
                colorTempChangeThreshold: daemon["color_temp_change_threshold"] as? Double ?? 200,
                launchAtLogin: daemon["launch_at_login"] as? Bool ?? true,
                showMenuBarIcon: daemon["show_menu_bar_icon"] as? Bool ?? true
            )
        }
        
        // Parse recalibration settings
        if let recal = json["recalibration"] as? [String: Any] {
            config.recalibration = CalibrexConfig.RecalibrationSettings(
                monthlyEnabled: recal["monthly_enabled"] as? Bool ?? true,
                spotCheckIntervalDays: recal["spot_check_interval_days"] as? Int ?? 7,
                deltaEThreshold: recal["delta_e_threshold"] as? Double ?? 3.0,
                autoRecalibrate: recal["auto_recalibrate"] as? Bool ?? false
            )
        }
        
        // Parse per-app rules
        if let rules = json["per_app_rules"] as? [String: [String: Any]] {
            config.perAppRules = rules.mapValues { ruleDict in
                CalibrexConfig.AppRuleConfig(
                    nightShift: ruleDict["night_shift"] as? String ?? "default",
                    trueTone: ruleDict["true_tone"] as? String ?? "default",
                    profileOverride: ruleDict["profile_override"] as? String
                )
            }
        }
        
        // Parse profile settings
        if let profiles = json["profiles"] as? [String: Any] {
            config.profiles = CalibrexConfig.ProfileSettings(
                maxProfiles: profiles["max_profiles"] as? Int ?? 5,
                defaultQuality: profiles["default_quality"] as? String ?? "high",
                autoClean: profiles["auto_clean"] as? Bool ?? true
            )
        }
        
        return config
    }
    
    private func configToJSON(_ config: CalibrexConfig) -> [String: Any] {
        var json: [String: Any] = [:]
        
        // Daemon settings
        json["daemon"] = [
            "poll_interval_lux": config.daemon.pollIntervalLux,
            "poll_interval_color_temp": config.daemon.pollIntervalColorTemp,
            "poll_interval_temperature": config.daemon.pollIntervalTemperature,
            "transition_duration": config.daemon.transitionDuration,
            "lux_change_threshold": config.daemon.luxChangeThreshold,
            "color_temp_change_threshold": config.daemon.colorTempChangeThreshold,
            "launch_at_login": config.daemon.launchAtLogin,
            "show_menu_bar_icon": config.daemon.showMenuBarIcon
        ]
        
        // Recalibration settings
        json["recalibration"] = [
            "monthly_enabled": config.recalibration.monthlyEnabled,
            "spot_check_interval_days": config.recalibration.spotCheckIntervalDays,
            "delta_e_threshold": config.recalibration.deltaEThreshold,
            "auto_recalibrate": config.recalibration.autoRecalibrate
        ]
        
        // Per-app rules
        json["per_app_rules"] = config.perAppRules.mapValues { rule in
            var ruleDict: [String: Any] = [
                "night_shift": rule.nightShift,
                "true_tone": rule.trueTone
            ]
            if let profileOverride = rule.profileOverride {
                ruleDict["profile_override"] = profileOverride
            }
            return ruleDict
        }
        
        // Profile settings
        json["profiles"] = [
            "max_profiles": config.profiles.maxProfiles,
            "default_quality": config.profiles.defaultQuality,
            "auto_clean": config.profiles.autoClean
        ]
        
        return json
    }
}

// MARK: - Default Config File

extension ConfigurationManager {
    
    /// Generate default config file
    static func generateDefaultConfig() -> String {
        let config = CalibrexConfig.default
        let manager = ConfigurationManager()
        let json = manager.configToJSON(config)
        
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
}
