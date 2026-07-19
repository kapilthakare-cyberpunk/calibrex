import Foundation

/// Calibrex Daemon - Adaptive Display Calibration System
/// 
/// Continuously monitors ambient conditions and adapts display
/// calibration for optimal color accuracy.
@main
struct CalibrexDaemon {
    static func main() async {
        print("Calibrex v0.1.0 - Adaptive Display Calibration Daemon")
        print("Starting...")
        
        let config = DaemonConfig.load()
        let sensorHub = SensorHub()
        let systemDetector = SystemDetector()
        let adaptationEngine = AdaptationEngine()
        
        // System detection on first run
        await systemDetector.detect()
        
        // Initialize adaptation engine
        let engineReady = adaptationEngine.initialize()
        guard engineReady else {
            print("[Calibrex] Failed to initialize CoreBrightness, exiting")
            return
        }
        
        // Main daemon loop
        await runDaemonLoop(
            config: config,
            sensorHub: sensorHub,
            systemDetector: systemDetector,
            adaptationEngine: adaptationEngine
        )
    }
    
    static func runDaemonLoop(
        config: DaemonConfig,
        sensorHub: SensorHub,
        systemDetector: SystemDetector,
        adaptationEngine: AdaptationEngine
    ) async {
        var lastLux: Double = 0
        var lastColorTemp: Double = 0
        var lastApp: String = ""
        
        while true {
            // Read sensors
            let lux = await sensorHub.readLux()
            let colorTemp = await sensorHub.readColorTemp()
            let currentApp = await systemDetector.currentAppBundle()
            
            // App focus change - immediate adaptation
            if currentApp != lastApp {
                await adaptationEngine.handleAppChange(
                    from: lastApp,
                    to: currentApp
                )
                lastApp = currentApp
            }
            
            // Ambient lux change - threshold-gated
            if lastLux > 0 {
                let luxDelta = abs(lux - lastLux) / lastLux
                if luxDelta > config.luxChangeThreshold {
                    await adaptationEngine.adjustBrightness(for: lux)
                    lastLux = lux
                }
            } else {
                lastLux = lux
            }
            
            // Color temperature change - threshold-gated
            if abs(colorTemp - lastColorTemp) > config.colorTempChangeThreshold {
                await adaptationEngine.adjustWhitePoint(for: colorTemp)
                lastColorTemp = colorTemp
            }
            
            // Sleep until next poll
            try? await Task.sleep(nanoseconds: UInt64(config.pollIntervalLux * 1_000_000_000))
        }
    }
}
