# Calibrex API Reference

## Overview

Calibrex is an adaptive display calibration daemon that continuously monitors ambient conditions and adapts display output for optimal color accuracy.

## Core Classes

### PlatformDetector

Auto-detects the current OS and returns platform-specific backends.

```swift
// Get current platform
let platform = PlatformDetector.current  // .macOS, .linux, .windows, .unknown

// Get platform-specific controllers
let display = PlatformDetector.displayController()
let sensor = PlatformDetector.ambientLightSensor()
let profiles = PlatformDetector.colorProfileManager()
```

### SensorHub

Reads ambient environmental signals from sensors.

```swift
let sensorHub = SensorHub()

// Read ambient light in lux
let lux = await sensorHub.readLux()

// Read color temperature in Kelvin
let colorTemp = await sensorHub.readColorTemp()

// Read room temperature in Celsius
let temperature = await sensorHub.readTemperature()

// Disconnect all sensors
sensorHub.disconnectAll()
```

### AdaptationEngine

Adjusts display based on ambient conditions.

```swift
let engine = AdaptationEngine()

// Initialize with CoreBrightness
engine.initialize()

// Handle app focus change
await engine.handleAppChange(from: "com.apple.Safari", to: "com.adobe.photoshop")

// Adjust brightness based on lux
await engine.adjustBrightness(for: 5000)

// Adjust white point based on color temperature
await engine.adjustWhitePoint(for: 4000)
```

### ArgyllCMS

Wraps ArgyllCMS command-line tools for colorimeter integration.

```swift
let argyll = ArgyllCMS()

// Detect connected colorimeters
let devices = argyll.detectColorimeters()

// Read display measurement
if let device = devices.first {
    let measurement = argyll.readDisplay(device: device)
    
    // Generate calibration targets
    let targetsDir = argyll.generateTargets()
    
    // Run calibration
    argyll.calibrateDisplay(device: device, targetsDir: targetsDir)
    
    // Generate ICC profile
    let profilePath = argyll.generateProfile(from: targetsDir, quality: .high)
    
    // Apply profile
    argyll.applyProfile(profilePath!)
    
    // Verify profile
    let deltaE = argyll.verifyProfile(device: device, profilePath: profilePath!)
}
```

### RecalibrationScheduler

Manages periodic recalibration and drift detection.

```swift
let scheduler = RecalibrationScheduler(argyll: argyll, profileManager: profileManager)

// Check if recalibration is needed
if let type = scheduler.checkRecalibrationNeeded() {
    switch type {
    case .monthlyDue(let lastCal, let days):
        print("Recalibration due after \(days) days")
    case .driftDetected(let deltaE):
        print("Display drift: \(deltaE)")
    }
}

// Execute full calibration
let result = await scheduler.executeFullCalibration(device: device)

// Execute spot check
let spotResult = await scheduler.executeSpotCheck(device: device)
```

### ProfileManager

Manages ICC profiles for display calibration.

```swift
let profileManager = ProfileManager()

// Store a new profile
let path = profileManager.storeProfile(
    at: tempPath,
    deltaE: 1.5,
    hardware: "Spyder 5",
    displayModel: "LG UltraFine"
)

// Get current profile
let current = profileManager.currentProfilePath

// Get profile history
let history = profileManager.listProfiles()

// Activate a profile
profileManager.activateProfile(record)

// Clean old profiles
profileManager.cleanOldProfiles(keeping: 5)
```

### ConfigurationManager

Manages Calibrex configuration.

```swift
let configManager = ConfigurationManager()

// Load config
let config = configManager.config

// Update daemon settings
configManager.updateDaemonSettings { settings in
    settings.pollIntervalLux = 30
    settings.launchAtLogin = true
}

// Update recalibration settings
configManager.updateRecalibrationSettings { settings in
    settings.monthlyEnabled = true
    settings.deltaEThreshold = 3.0
}

// Manage app rules
configManager.setAppRule(for: "com.adobe.photoshop", rule: AppRuleConfig(
    nightShift: "off",
    trueTone: "off",
    profileOverride: nil
))
```

### NotificationManager

Manages Calibrex notifications.

```swift
let notifications = NotificationManager()

// Request permission
notifications.requestAuthorization()

// Send notifications
notifications.notifyCalibrationComplete(deltaE: 1.5, profileName: "calibrex.icc")
notifications.notifyRecalibrationDue(daysSinceLast: 30)
notifications.notifySensorConnected(name: "TSL2591", type: "Luminosity")
notifications.notifyProfileApplied(profileName: "calibrex.icc")

// Schedule reminders
notifications.scheduleReminder(
    title: "Recalibration Due",
    body: "Don't forget to recalibrate",
    in: 60,  // minutes
    identifier: "reminder_1"
)
```

## Protocols

### DisplayControllerProtocol

```swift
protocol DisplayControllerProtocol {
    func getBrightness() -> Double
    func setBrightness(_ level: Double) -> Bool
    func getWhitePoint() -> Double
    func setWhitePoint(_ kelvin: Double) -> Bool
    func isBlueLightFilterEnabled() -> Bool
    func setBlueLightFilter(_ enabled: Bool) -> Bool
    func getBlueLightFilterTemperature() -> Double
    func setBlueLightFilterTemperature(_ kelvin: Double) -> Bool
    func supportsWideColorGamut() -> Bool
    func getDisplayInfo() -> DisplayInfo
}
```

### AmbientLightProtocol

```swift
protocol AmbientLightProtocol {
    func open() -> Bool
    func close()
    func readLux() -> Double?
    var isAvailable: Bool { get }
}
```

### ColorProfileProtocol

```swift
protocol ColorProfileProtocol {
    func getCurrentProfile() -> String?
    func applyProfile(_ path: String) -> Bool
    func listProfiles() -> [ColorProfile]
    func installProfile(_ path: String) -> Bool
    func removeProfile(_ path: String) -> Bool
    func getColorSpace() -> String
}
```

## Types

### DisplayInfo

```swift
struct DisplayInfo {
    let name: String
    let manufacturer: String
    let model: String
    let serialNumber: String?
    let resolution: String
    let colorDepth: Int
    let supportsHDR: Bool
    let supportsTrueTone: Bool
}
```

### ColorProfile

```swift
struct ColorProfile {
    let name: String
    let path: String
    let creationDate: Date?
    let isDefault: Bool
}
```

### CalibrationRecord

```swift
struct CalibrationRecord {
    let profilePath: String
    let creationDate: Date
    let deltaE: Double
    let hardware: String
    let displayModel: String
}
```

### USBDevice

```swift
struct USBDevice {
    let id: String
    let name: String
    let vendorId: Int
    let productId: Int
    let path: String
    let type: USBDeviceType
    let connectedAt: Date
}
```

## Enums

### Platform

```swift
enum Platform: String, CaseIterable {
    case macOS = "macOS"
    case linux = "Linux"
    case windows = "Windows"
    case unknown = "Unknown"
}
```

### ProfileQuality

```swift
enum ProfileQuality {
    case low      // -ql
    case medium   // -qm
    case high     // -qh
    case proof    // -qp
}
```

### CalibrationStep

```swift
enum CalibrationStep: CaseIterable {
    case welcome
    case colorimeter
    case display
    case measurement
    case profile
    case verification
    case complete
}
```

## Serial Protocol (Arduino Firmware)

### Commands

| Command | Response | Description |
|---------|----------|-------------|
| `IDENTIFY` | `TSL2591` or `BH1750` | Identify connected sensor |
| `READ` | `VISIBLE:12345\|IR:67890\|LUX:123.45` | Read TSL2591 data |
| `READ` | `LUX:1234.56` | Read BH1750 data |
| `GAIN:0-3` | `OK` | Set TSL2591 gain |
| `AUTOGAIN:ON/OFF` | `OK` | Enable/disable TSL2591 auto-gain |
| `TIME:100-600` | `OK` | Set TSL2591 integration time |
| `MODE:1-6` | `OK` | Set BH1750 measurement mode |
| `MTIME:140-1269` | `OK` | Set BH1750 measurement time |
| `RESET` | `OK` | Reset BH1750 sensor |
| `POWER:ON/OFF` | `OK` | Power on/off BH1750 |

### Baud Rate

Default: **115200**

## Configuration

### config.json

```json
{
  "daemon": {
    "poll_interval_lux": 60,
    "poll_interval_color_temp": 120,
    "poll_interval_temperature": 300,
    "transition_duration": 2.0,
    "lux_change_threshold": 0.15,
    "color_temp_change_threshold": 200,
    "launch_at_login": true,
    "show_menu_bar_icon": true
  },
  "recalibration": {
    "monthly_enabled": true,
    "spot_check_interval_days": 7,
    "delta_e_threshold": 3.0,
    "auto_recalibrate": false
  },
  "per_app_rules": {
    "com.adobe.photoshop": {
      "night_shift": "off",
      "true_tone": "off"
    }
  },
  "profiles": {
    "max_profiles": 5,
    "default_quality": "high",
    "auto_clean": true
  }
}
```
