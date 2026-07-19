# Calibrex Architecture

## Overview

Calibrex is designed as a modular, cross-platform adaptive display calibration system. The architecture follows a layered approach with clear separation of concerns.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Calibrex                             │
├─────────────────────────────────────────────────────────────┤
│  Menu Bar UI  │  Settings  │  Calibration Wizard           │
├─────────────────────────────────────────────────────────────┤
│                    Adaptation Engine                         │
│  (Brightness, White Point, Night Shift, True Tone)          │
├─────────────────────────────────────────────────────────────┤
│                    Core Services                             │
│  SensorHub │ ProfileManager │ RecalibrationScheduler        │
├─────────────────────────────────────────────────────────────┤
│                   Platform Abstraction                       │
│  DisplayController │ AmbientLight │ ColorProfile            │
├─────────────────────────────────────────────────────────────┤
│  macOS          │  Linux            │  Windows              │
│  CoreBrightness │  xrandr/colord    │  DDC/CI/WCS           │
│  IOKit          │  IIO              │  WMI                   │
│  ColorSync      │  ICC profiles     │  Registry              │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Platform Abstraction Layer

**Purpose**: Provides consistent API across macOS, Linux, and Windows.

**Components**:
- `PlatformDetector` — Auto-detects OS and returns platform-specific backends
- `DisplayControllerProtocol` — Brightness, white point, blue light control
- `AmbientLightProtocol` — Ambient light sensing
- `ColorProfileProtocol` — ICC profile management

**Design Pattern**: Strategy Pattern — Platform-specific implementations conform to shared protocols.

### 2. Sensor Hub

**Purpose**: Reads ambient environmental signals from multiple sources.

**Components**:
- `SensorHub` — Orchestrates sensor readings with priority fallback
- `AmbientLightSensor` — IOKit-based MacBook sensor
- `USBSensorManager` — Manages USB-connected sensors
- `USBHotplugDetector` — Real-time USB event monitoring

**Sensor Priority**:
1. USB sensor (TSL2591/BH1750) — Most accurate
2. Built-in sensor (IOKit) — MacBook only
3. Time-based estimation — Fallback

### 3. Adaptation Engine

**Purpose**: Adjusts display based on ambient conditions.

**Components**:
- `AdaptationEngine` — Core adaptive loop
- `CoreBrightnessClient` — macOS Night Shift/True Tone control

**Adaptation Rules**:
| Signal | Threshold | Action |
|--------|-----------|--------|
| Lux change | > 15% | Adjust brightness |
| Color temp change | > 200K | Adjust white point |
| App focus change | Instant | Switch settings |

### 4. Calibration Pipeline

**Purpose**: Manages colorimeter-based calibration and ICC profiles.

**Components**:
- `ArgyllCMS` — Wraps ArgyllCMS CLI tools
- `RecalibrationScheduler` — Monthly calibration + drift detection
- `ProfileManager` — ICC profile storage and management

**Calibration Flow**:
```
1. Detect colorimeter
2. Generate target patches
3. Measure display response
4. Generate ICC profile
5. Apply profile
6. Verify accuracy (delta-E)
```

### 5. Configuration System

**Purpose**: Manages daemon settings and per-app rules.

**Components**:
- `ConfigurationManager` — JSON config file handling
- `DaemonConfig` — Runtime configuration

**Config Location**: `~/Library/Application Support/Calibrex/config.json`

### 6. Notification System

**Purpose**: Alerts user for calibration events.

**Components**:
- `NotificationManager` — UNUserNotificationCenter integration

**Notification Types**:
- Calibration complete/failed
- Recalibration due
- Drift detected
- Sensor connected/disconnected

## Data Flow

### Ambient Sensing Loop

```
┌──────────────┐
│ SensorHub    │
│ readLux()    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Adaptation   │
│ Engine       │
│ adjustBrightness()
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ CoreBrightness│
│ setBrightness()
└──────────────┘
```

### Calibration Flow

```
┌──────────────┐
│ User clicks  │
│ Calibrate    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ ArgyllCMS    │
│ detectColorimeters()
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ User places  │
│ colorimeter  │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ ArgyllCMS    │
│ calibrateDisplay()
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ ArgyllCMS    │
│ generateProfile()
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ ProfileManager│
│ storeProfile()
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Notifications│
│ notifyCalibrationComplete()
└──────────────┘
```

## File Structure

```
calibrex/
├── Sources/Calibrex/
│   ├── main.swift                    # Daemon entry point
│   ├── Core/                         # Core services
│   │   ├── DaemonConfig.swift
│   │   ├── SystemDetector.swift
│   │   ├── ConfigurationManager.swift
│   │   ├── LaunchAgentManager.swift
│   │   └── NotificationManager.swift
│   ├── Sensors/                      # Sensor reading
│   │   ├── SensorHub.swift
│   │   ├── AmbientLightSensor.swift
│   │   ├── SerialCommunication.swift
│   │   ├── TSL2591Sensor.swift
│   │   ├── BH1750Sensor.swift
│   │   ├── USBSensorManager.swift
│   │   └── USBHotplugDetector.swift
│   ├── Calibration/                  # Calibration pipeline
│   │   ├── ArgyllCMS.swift
│   │   └── RecalibrationScheduler.swift
│   ├── Profiles/                     # Profile management
│   │   └── ProfileManager.swift
│   ├── Adaptation/                   # Adaptive display control
│   │   └── AdaptationEngine.swift
│   ├── Platform/                     # Cross-platform abstraction
│   │   ├── PlatformDetector.swift
│   │   ├── PlatformProtocols.swift
│   │   ├── macOS/
│   │   ├── Linux/
│   │   └── Windows/
│   ├── MenuBar/                      # SwiftUI UI
│   │   ├── CalibrexMenuBarApp.swift
│   │   ├── MenuBarViewModel.swift
│   │   ├── SettingsView.swift
│   │   ├── CalibrationWizardView.swift
│   │   └── CalibrationWorkflow.swift
│   └── Utils/                        # Utilities
│       └── CoreBrightness.swift
├── Firmware/                         # Arduino firmware
│   └── calibrex_sensor/
├── Tests/                            # Unit tests
├── Docs/                             # Documentation
└── Config/                           # Configuration files
```

## Key Design Decisions

### 1. Protocol-Based Abstraction

All platform-specific code is behind protocols, allowing:
- Easy testing with mocks
- Future platform support
- Clean separation of concerns

### 2. Event-Driven Architecture

USB hot-plug and app focus changes use event-driven patterns:
- IOKit notifications for USB events
- NSWorkspace notifications for app changes
- Combine publishers for reactive updates

### 3. Priority-Based Fallback

Sensor readings use priority fallback:
1. Most accurate source (USB sensor)
2. Built-in source (IOKit)
3. Estimation (time-based)

### 4. Threshold-Gated Adaptation

Changes only trigger adaptation when exceeding thresholds:
- Prevents constant micro-adjustments
- Reduces CPU usage
- Matches human perception

### 5. Persistent State

All state is persisted to disk:
- Calibration history
- Configuration
- Launch agent status
- Profile records

## Security Considerations

- **Private Frameworks**: CoreBrightness usage requires app signing
- **USB Access**: Requires USB permissions on macOS
- **Profile Installation**: Requires admin privileges for system profiles
- **Launch Agent**: Runs with user privileges only

## Performance

- **Polling Intervals**: Configurable (default 60s for lux)
- **Transition Duration**: Smooth 2s animations
- **CPU Usage**: < 0.1% during normal operation
- **Memory Usage**: ~20MB baseline
