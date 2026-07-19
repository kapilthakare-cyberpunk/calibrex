import XCTest
@testable import Calibrex

final class ConfigurationManagerTests: XCTestCase {
    
    var manager: ConfigurationManager!
    
    override func setUp() {
        super.setUp()
        manager = ConfigurationManager()
    }
    
    func testDefaultConfig() {
        let config = manager.config
        
        // Daemon settings
        XCTAssertEqual(config.daemon.pollIntervalLux, 60)
        XCTAssertEqual(config.daemon.launchAtLogin, true)
        XCTAssertEqual(config.daemon.showMenuBarIcon, true)
        
        // Recalibration settings
        XCTAssertEqual(config.recalibration.monthlyEnabled, true)
        XCTAssertEqual(config.recalibration.spotCheckIntervalDays, 7)
        XCTAssertEqual(config.recalibration.deltaEThreshold, 3.0)
        
        // Profile settings
        XCTAssertEqual(config.profiles.maxProfiles, 5)
        XCTAssertEqual(config.profiles.defaultQuality, "high")
    }
    
    func testUpdateDaemonSettings() {
        manager.updateDaemonSettings { settings in
            settings.pollIntervalLux = 30
            settings.launchAtLogin = false
        }
        
        XCTAssertEqual(manager.config.daemon.pollIntervalLux, 30)
        XCTAssertEqual(manager.config.daemon.launchAtLogin, false)
    }
    
    func testUpdateRecalibrationSettings() {
        manager.updateRecalibrationSettings { settings in
            settings.monthlyEnabled = false
            settings.spotCheckIntervalDays = 14
        }
        
        XCTAssertEqual(manager.config.recalibration.monthlyEnabled, false)
        XCTAssertEqual(manager.config.recalibration.spotCheckIntervalDays, 14)
    }
    
    func testSetAppRule() {
        let rule = ConfigurationManager.CalibrexConfig.AppRuleConfig(
            nightShift: "off",
            trueTone: "off",
            profileOverride: nil
        )
        
        manager.setAppRule(for: "com.test.app", rule: rule)
        
        let retrieved = manager.getAppRule(for: "com.test.app")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.nightShift, "off")
        XCTAssertEqual(retrieved?.trueTone, "off")
    }
    
    func testRemoveAppRule() {
        let rule = ConfigurationManager.CalibrexConfig.AppRuleConfig(
            nightShift: "off",
            trueTone: "off",
            profileOverride: nil
        )
        
        manager.setAppRule(for: "com.test.app", rule: rule)
        manager.removeAppRule(for: "com.test.app")
        
        let retrieved = manager.getAppRule(for: "com.test.app")
        XCTAssertNil(retrieved)
    }
    
    func testGetDefaultAppRules() {
        // Should have default rules for common apps
        let photoshopRule = manager.getAppRule(for: "com.adobe.photoshop")
        XCTAssertNotNil(photoshopRule)
        XCTAssertEqual(photoshopRule?.nightShift, "off")
        
        let finalCutRule = manager.getAppRule(for: "com.apple.FinalCutPro")
        XCTAssertNotNil(finalCutRule)
        XCTAssertEqual(finalCutRule?.trueTone, "off")
    }
    
    func testGenerateDefaultConfig() {
        let configString = ConfigurationManager.generateDefaultConfig()
        
        // Should be valid JSON
        XCTAssertFalse(configString.isEmpty)
        
        // Should contain expected keys
        XCTAssertTrue(configString.contains("daemon"))
        XCTAssertTrue(configString.contains("recalibration"))
        XCTAssertTrue(configString.contains("per_app_rules"))
    }
}
