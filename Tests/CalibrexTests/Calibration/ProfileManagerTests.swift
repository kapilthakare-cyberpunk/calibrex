import XCTest
@testable import Calibrex

final class ProfileManagerTests: XCTestCase {
    
    var profileManager: ProfileManager!
    
    override func setUp() {
        super.setUp()
        profileManager = ProfileManager()
    }
    
    func testInitialState() {
        // Should start with no current profile
        XCTAssertNil(profileManager.currentProfilePath)
    }
    
    func testProfileHistory() {
        let history = profileManager.listProfiles()
        XCTAssertNotNil(history)
        // History should be an array (may be empty)
        XCTAssertTrue(history is [CalibrationRecord])
    }
    
    func testLatestProfile() {
        let latest = profileManager.latestProfile()
        // May be nil if no profiles exist
        if let latest = latest {
            XCTAssertFalse(latest.profilePath.isEmpty)
            XCTAssertGreaterThan(latest.deltaE, 0)
        }
    }
    
    func testPerAppRules() {
        let rules = profileManager.loadPerAppRules()
        
        // Should have default rules
        XCTAssertNotNil(rules["com.adobe.photoshop"])
        XCTAssertNotNil(rules["com.apple.FinalCutPro"])
        XCTAssertNotNil(rules["com.blackmagic-design.DaVinciResolve"])
    }
    
    func testDefaultAppRules() {
        let rules = profileManager.loadPerAppRules()
        
        // Photoshop should have Night Shift off
        if let photoshopRule = rules["com.adobe.photoshop"] {
            XCTAssertEqual(photoshopRule.nightShift, "off")
            XCTAssertEqual(photoshopRule.trueTone, "off")
        }
        
        // Final Cut should have Night Shift off
        if let finalCutRule = rules["com.apple.FinalCutPro"] {
            XCTAssertEqual(finalCutRule.nightShift, "off")
            XCTAssertEqual(finalCutRule.trueTone, "off")
        }
    }
    
    func testSavePerAppRules() {
        let newRules: [String: AppRule] = [
            "com.test.app": AppRule(nightShift: "on", trueTone: "on")
        ]
        
        profileManager.savePerAppRules(newRules)
        
        // Verify rules were saved (would need to check internal state)
        // This is a basic smoke test
    }
    
    func testCleanOldProfiles() {
        // This test verifies the method doesn't crash
        // Actual cleanup behavior depends on profile count
        profileManager.cleanOldProfiles(keeping: 5)
    }
}

// MARK: - CalibrationRecord Tests

extension ProfileManagerTests {
    
    func testCalibrationRecordInitialization() {
        let record = CalibrationRecord(
            profilePath: "/path/to/profile.icc",
            creationDate: Date(),
            deltaE: 1.5,
            hardware: "Spyder 5",
            displayModel: "LG UltraFine"
        )
        
        XCTAssertEqual(record.profilePath, "/path/to/profile.icc")
        XCTAssertEqual(record.deltaE, 1.5)
        XCTAssertEqual(record.hardware, "Spyder 5")
        XCTAssertEqual(record.displayModel, "LG UltraFine")
    }
}
