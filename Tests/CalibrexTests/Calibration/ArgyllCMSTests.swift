import XCTest
@testable import Calibrex

final class ArgyllCMSTests: XCTestCase {
    
    var argyll: ArgyllCMS!
    
    override func setUp() {
        super.setUp()
        argyll = ArgyllCMS()
    }
    
    func testProfileQualityFlags() {
        XCTAssertEqual(ProfileQuality.low.flag, "-ql")
        XCTAssertEqual(ProfileQuality.medium.flag, "-qm")
        XCTAssertEqual(ProfileQuality.high.flag, "-qh")
        XCTAssertEqual(ProfileQuality.proof.flag, "-qp")
    }
    
    func testColorimeterDeviceTypes() {
        let spyder = ColorimeterDevice(id: "spyder", name: "Spyder 5", type: .spyder)
        XCTAssertEqual(spyder.type.description, "Spyder")
        
        let i1 = ColorimeterDevice(id: "i1", name: "i1 Display Pro", type: .i1Display)
        XCTAssertEqual(i1.type.description, "i1 Display")
    }
    
    func testDisplayMeasurementInitialization() {
        let measurement = DisplayMeasurement(
            r: 0.5,
            g: 0.4,
            b: 0.3,
            whitePointX: 0.3127,
            whitePointY: 0.3290,
            lux: 100
        )
        
        XCTAssertEqual(measurement.r, 0.5)
        XCTAssertEqual(measurement.g, 0.4)
        XCTAssertEqual(measurement.b, 0.3)
        XCTAssertEqual(measurement.whitePointX, 0.3127, accuracy: 0.0001)
        XCTAssertEqual(measurement.whitePointY, 0.3290, accuracy: 0.0001)
        XCTAssertEqual(measurement.lux, 100)
    }
    
    func testArraySafeAccess() {
        let array = [1, 2, 3, 4, 5]
        
        XCTAssertEqual(array[safe: 0], 1)
        XCTAssertEqual(array[safe: 2], 3)
        XCTAssertEqual(array[safe: 10], nil)
        XCTAssertEqual(array[safe: -1], nil)
    }
}
