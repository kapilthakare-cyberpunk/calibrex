import Foundation
import Combine
import AppKit

/// View model powering the menu bar UI
@MainActor
class MenuBarViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var currentLux: Double = 0
    @Published var currentColorTemp: Double = 6500
    @Published var currentBrightness: Double = 0.5
    @Published var currentProfile: String? = nil
    @Published var lastDeltaE: Double = 0
    
    @Published var nightShiftEnabled: Bool = false
    @Published var trueToneEnabled: Bool = false
    @Published var adaptiveEnabled: Bool = true
    
    // MARK: - Dependencies
    
    private let sensorHub = SensorHub()
    private let coreBrightness = CoreBrightnessClient()
    private let profileManager = ProfileManager()
    private let configManager = ConfigurationManager()
    private let notificationManager = NotificationManager()
    
    private var isInitialized = false
    private var updateTimer: Timer?
    
    // MARK: - Initialization
    
    func initialize() {
        guard !isInitialized else { return }
        
        // Initialize CoreBrightness
        coreBrightness.initialize()
        
        // Read initial state
        nightShiftEnabled = coreBrightness.isNightShiftEnabled()
        trueToneEnabled = coreBrightness.isTrueToneEnabled()
        currentBrightness = coreBrightness.getBrightness()
        
        // Load current profile
        currentProfile = profileManager.currentProfilePath.map { url in
            URL(fileURLWithPath: url).lastPathComponent
        }
        
        // Start periodic updates
        startPeriodicUpdates()
        
        isInitialized = true
        print("[MenuBar] Initialized")
    }
    
    func refresh() {
        initialize()
        updateSensorReadings()
    }
    
    // MARK: - Sensor Updates
    
    private func startPeriodicUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSensorReadings()
            }
        }
    }
    
    private func updateSensorReadings() {
        Task {
            let lux = await sensorHub.readLux()
            let colorTemp = await sensorHub.readColorTemp()
            
            self.currentLux = lux
            self.currentColorTemp = colorTemp
        }
    }
    
    // MARK: - Controls
    
    func setNightShift(_ enabled: Bool) {
        coreBrightness.setNightShift(enabled)
        nightShiftEnabled = enabled
        print("[MenuBar] Night Shift: \(enabled ? "ON" : "OFF")")
    }
    
    func setTrueTone(_ enabled: Bool) {
        coreBrightness.setTrueTone(enabled)
        trueToneEnabled = enabled
        print("[MenuBar] True Tone: \(enabled ? "ON" : "OFF")")
    }
    
    func setAdaptive(_ enabled: Bool) {
        adaptiveEnabled = enabled
        print("[MenuBar] Adaptive Mode: \(enabled ? "ON" : "OFF")")
        
        // Save to config
        configManager.updateDaemonSettings { settings in
            // Store adaptive state
        }
    }
    
    // MARK: - Actions
    
    func startCalibration() {
        print("[MenuBar] Starting calibration...")
        
        Task {
            // TODO: Trigger full calibration workflow
            // For now, send notification
            notificationManager.notifyCalibrationComplete(deltaE: 0, profileName: "Test")
        }
    }
    
    func spotCheck() {
        print("[MenuBar] Running spot check...")
        
        Task {
            // TODO: Run spot check workflow
            // For now, send notification
            notificationManager.notifyProfileVerification(deltaE: 1.5, quality: "Very Good")
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        updateTimer?.invalidate()
    }
}
