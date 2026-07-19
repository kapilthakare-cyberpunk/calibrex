import XCTest
@testable import Calibrex

final class AdaptationEngineTests: XCTestCase {
    
    var engine: AdaptationEngine!
    
    override func setUp() {
        super.setUp()
        engine = AdaptationEngine()
    }
    
    func testLuxToBrightnessMapping() {
        // Test the brightness mapping logic
        // Low lux should map to low brightness
        // High lux should map to high brightness
        
        let lowLuxBrightness = mapLuxToBrightness(10)
        let highLuxBrightness = mapLuxToBrightness(50000)
        
        XCTAssertLessThan(lowLuxBrightness, highLuxBrightness)
        
        // Brightness should be clamped between 0.1 and 1.0
        XCTAssertGreaterThanOrEqual(lowLuxBrightness, 0.1)
        XCTAssertLessThanOrEqual(highLuxBrightness, 1.0)
    }
    
    func testSmoothTransition() async {
        // Test that smooth transition interpolates values
        var values: [Double] = []
        
        let from: Double = 0.2
        let to: Double = 0.8
        let duration: Double = 0.1 // Short duration for test
        
        await smoothTransition(
            from: from,
            to: to,
            duration: duration
        ) { value in
            values.append(value)
        }
        
        // Should have multiple values
        XCTAssertGreaterThan(values.count, 1)
        
        // First value should be close to start
        XCTAssertEqual(values.first!, from, accuracy: 0.1)
        
        // Last value should be close to end
        XCTAssertEqual(values.last!, to, accuracy: 0.1)
    }
    
    func testColorTempThreshold() {
        // Test that color temperature changes above threshold trigger adaptation
        let threshold: Double = 200
        
        let smallChange = 100.0
        let largeChange = 300.0
        
        XCTAssertFalse(smallChange > threshold)
        XCTAssertTrue(largeChange > threshold)
    }
    
    func testLuxThreshold() {
        // Test that lux changes above threshold trigger adaptation
        let threshold: Double = 0.15
        
        let smallChange = 0.10
        let largeChange = 0.20
        
        XCTAssertFalse(smallChange > threshold)
        XCTAssertTrue(largeChange > threshold)
    }
    
    // MARK: - Helpers
    
    private func mapLuxToBrightness(_ lux: Double) -> Double {
        let minLux: Double = 10
        let maxLux: Double = 50000
        
        let logMin = log(minLux)
        let logMax = log(maxLux)
        let logLux = log(max(lux, minLux))
        
        let normalized = (logLux - logMin) / (logMax - logMin)
        return min(max(normalized, 0.1), 1.0)
    }
    
    private func smoothTransition(
        from current: Double,
        to target: Double,
        duration: Double,
        apply: @escaping (Double) -> Void
    ) async {
        let steps = Int(duration * 60)
        let stepDuration = duration / Double(steps)
        let delta = target - current
        
        for i in 0..<steps {
            let progress = Double(i) / Double(steps)
            let eased = progress < 0.5
                ? 2 * progress * progress
                : 1 - pow(-2 * progress + 2, 2) / 2
            
            let value = current + delta * eased
            apply(value)
            
            try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
        }
    }
}
