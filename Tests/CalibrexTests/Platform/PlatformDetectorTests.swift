import XCTest
@testable import Calibrex

final class PlatformDetectorTests: XCTestCase {
    
    func testCurrentPlatform() {
        // On macOS, should detect macOS
        #if os(macOS)
        XCTAssertEqual(PlatformDetector.current, .macOS)
        #elseif os(Linux)
        XCTAssertEqual(PlatformDetector.current, .linux)
        #elseif os(Windows)
        XCTAssertEqual(PlatformDetector.current, .windows)
        #else
        XCTAssertEqual(PlatformDetector.current, .unknown)
        #endif
    }
    
    func testDisplayController() {
        let controller = PlatformDetector.displayController()
        XCTAssertNotNil(controller)
        
        // Should return platform-specific implementation
        #if os(macOS)
        XCTAssertTrue(controller is MacDisplayController)
        #elseif os(Linux)
        XCTAssertTrue(controller is LinuxDisplayController)
        #elseif os(Windows)
        XCTAssertTrue(controller is WindowsDisplayController)
        #endif
    }
    
    func testAmbientLightSensor() {
        let sensor = PlatformDetector.ambientLightSensor()
        XCTAssertNotNil(sensor)
        
        // Should return platform-specific implementation
        #if os(macOS)
        XCTAssertTrue(sensor is MacOSAmbientLightSensor)
        #elseif os(Linux)
        XCTAssertTrue(sensor is LinuxAmbientLightSensor)
        #elseif os(Windows)
        XCTAssertTrue(sensor is WindowsAmbientLightSensor)
        #endif
    }
    
    func testColorProfileManager() {
        let manager = PlatformDetector.colorProfileManager()
        XCTAssertNotNil(manager)
        
        // Should return platform-specific implementation
        #if os(macOS)
        XCTAssertTrue(manager is MacOSColorProfileManager)
        #elseif os(Linux)
        XCTAssertTrue(manager is LinuxColorProfileManager)
        #elseif os(Windows)
        XCTAssertTrue(manager is WindowsColorProfileManager)
        #endif
    }
    
    func testPlatformDisplayName() {
        XCTAssertEqual(PlatformDetector.Platform.macOS.displayName, "macOS")
        XCTAssertEqual(PlatformDetector.Platform.linux.displayName, "Linux")
        XCTAssertEqual(PlatformDetector.Platform.windows.displayName, "Windows")
        XCTAssertEqual(PlatformDetector.Platform.unknown.displayName, "Unknown")
    }
    
    func testAllPlatformsHaveDisplayNames() {
        for platform in PlatformDetector.Platform.allCases {
            XCTAssertFalse(platform.displayName.isEmpty)
        }
    }
}
