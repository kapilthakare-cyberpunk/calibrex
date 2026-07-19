import XCTest
@testable import Calibrex

final class SensorHubTests: XCTestCase {
    
    var sensorHub: SensorHub!
    
    override func setUp() {
        super.setUp()
        sensorHub = SensorHub()
    }
    
    override func tearDown() {
        sensorHub.disconnectAll()
        super.tearDown()
    }
    
    func testReadLuxReturnsValue() async {
        let lux = await sensorHub.readLux()
        
        // Lux should be non-negative
        XCTAssertGreaterThanOrEqual(lux, 0)
        
        // Lux should be reasonable (0-100000)
        XCTAssertLessThanOrEqual(lux, 100000)
    }
    
    func testReadColorTempReturnsValue() async {
        let colorTemp = await sensorHub.readColorTemp()
        
        // Color temperature should be in valid range (1800-10000K)
        XCTAssertGreaterThanOrEqual(colorTemp, 1800)
        XCTAssertLessThanOrEqual(colorTemp, 10000)
    }
    
    func testReadTemperatureReturnsValue() async {
        let temperature = await sensorHub.readTemperature()
        
        // Temperature should be reasonable (15-35°C for room temp)
        XCTAssertGreaterThanOrEqual(temperature, 15)
        XCTAssertLessThanOrEqual(temperature, 35)
    }
    
    func testDisconnectAll() {
        sensorHub.disconnectAll()
        
        // After disconnect, sensor should not be available
        // This is a basic smoke test
        XCTAssertFalse(sensorHub.sensorOpened)
    }
    
    func testEstimationFallbackLux() async {
        // Even without sensors, should return a reasonable estimate
        let lux = await sensorHub.readLux()
        XCTAssertGreaterThanOrEqual(lux, 0)
    }
    
    func testEstimationFallbackColorTemp() async {
        // Even without sensors, should return a reasonable estimate
        let colorTemp = await sensorHub.readColorTemp()
        XCTAssertGreaterThanOrEqual(colorTemp, 1800)
        XCTAssertLessThanOrEqual(colorTemp, 10000)
    }
}
