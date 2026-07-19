import XCTest
@testable import Calibrex

final class DaemonConfigTests: XCTestCase {
    
    func testDefaultConfig() {
        let config = DaemonConfig.default
        
        XCTAssertEqual(config.pollIntervalLux, 60)
        XCTAssertEqual(config.pollIntervalColorTemp, 120)
        XCTAssertEqual(config.pollIntervalTemperature, 300)
        XCTAssertEqual(config.transitionDuration, 2.0)
        XCTAssertEqual(config.luxChangeThreshold, 0.15)
        XCTAssertEqual(config.colorTempChangeThreshold, 200)
    }
    
    func testConfigLoadFromJSON() throws {
        let json: [String: Any] = [
            "daemon": [
                "poll_interval_lux": 30,
                "poll_interval_color_temp": 60,
                "poll_interval_temperature": 180,
                "transition_duration": 1.5,
                "lux_change_threshold": 0.20,
                "color_temp_change_threshold": 300
            ]
        ]
        
        let config = try XCTUnwrap(DaemonConfig.load(from: json))
        
        XCTAssertEqual(config.pollIntervalLux, 30)
        XCTAssertEqual(config.pollIntervalColorTemp, 60)
        XCTAssertEqual(config.pollIntervalTemperature, 180)
        XCTAssertEqual(config.transitionDuration, 1.5)
        XCTAssertEqual(config.luxChangeThreshold, 0.20)
        XCTAssertEqual(config.colorTempChangeThreshold, 300)
    }
    
    func testConfigLoadFromMissingFile() {
        let config = DaemonConfig.load(from: "/nonexistent/path.json")
        XCTAssertNil(config)
    }
    
    func testConfigLoadFromEmptyJSON() {
        let json: [String: Any] = [:]
        
        // Should return defaults when daemon key is missing
        let config = DaemonConfig.load(from: json)
        XCTAssertNotNil(config)
    }
}
