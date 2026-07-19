# Technical Specification

## Overview

Calibrex is a macOS daemon (MVP) that provides adaptive display calibration through continuous ambient sensing and automated colorimeter-driven profile generation.

## System Requirements

- macOS 13 (Ventura) or later
- Apple Silicon or Intel Mac
- Colorimeter: Datacolor Spyder or X-Rite i1 Display (via ArgyllCMS)
- Optional: USB ambient light sensor (TSL2591/BH1750 via Arduino bridge)

## Core Components

### 1. SystemDetector

Identifies the host system on first run:

- OS version and architecture (arm64/x86_64)
- Display model, manufacturer, and capabilities via EDID
- GPU model and supported color depth
- Connected colorimeters (USB enumeration)
- Ambient light sensor availability (built-in MacBook or USB)

### 2. SensorHub

Reads all environmental signals:

- **Ambient Lux** — IOKit HID ambient light sensor (MacBook) or USB sensor
- **Ambient Color Temperature** — Calculated from RGB ambient readings or dedicated sensor
- **Room Temperature** — IOKit SMC temperature sensors or USB thermometer
- **Display EDID** — Current display state, resolution, color mode

### 3. ColorimeterDriver

Wraps ArgyllCMS CLI commands:

- `dispread` — Display measurement with colorimeter
- `spotread` — Single-point color measurement
- `colprof` — ICC profile generation from measurement data
- `targen` — Generate calibration target patches

### 4. AdaptationEngine

The core adaptive loop:

```
loop every 60s:
    lux = sensorHub.readLux()
    colorTemp = sensorHub.readColorTemp()
    app = systemDetector.currentApp()
    
    if app != lastApp:
        switchProfile(app)
        toggleNightShift(app)
    
    if abs(lux - lastLux) / lastLux > 0.15:
        adjustBrightness(lux)
    
    if abs(colorTemp - lastColorTemp) > 200:
        adjustWhitePoint(colorTemp)
    
    smoothTransition(duration: 2.0)
```

### 5. ProfileManager

Manages ICC profiles:

- Store profiles in ~/Library/ColorSync/Profiles/Calibrex/
- Track profile creation date, delta-E accuracy, hardware used
- Apply profiles via macOS ColorSync/colord
- Per-app profile rules (stored in JSON config)

### 6. RecalibrationScheduler

Handles periodic calibration:

- Monthly full calibration (colorimeter required)
- Weekly spot-check (single patch, delta-E comparison)
- Drift-triggered recalibration (delta-E > 3.0)
- User notification when recalibration needed

## Data Flow

```
Ambient Sensors ──→ SensorHub ──→ AdaptationEngine ──→ Display Output
                          │                │
Colorimeter ────→ ColorimeterDriver ──→ ProfileManager
                          │                │
System Info ────→ SystemDetector ───→ RecalibrationScheduler
```

## Configuration

```json
{
  "daemon": {
    "poll_interval_lux": 60,
    "poll_interval_color_temp": 120,
    "poll_interval_temperature": 300,
    "transition_duration": 2.0,
    "lux_change_threshold": 0.15,
    "color_temp_change_threshold": 200
  },
  "recalibration": {
    "monthly_enabled": true,
    "spot_check_interval_days": 7,
    "delta_e_threshold": 3.0
  },
  "per_app_rules": {
    "com.adobe.photoshop": { "night_shift": "off", "true_tone": "off" },
    "com.apple.FinalCutPro": { "night_shift": "off", "true_tone": "off" }
  }
}
```

## Private Frameworks Used

- `CoreBrightness` (CBBlueLightClient) — Night Shift control
- `DisplayServices` — True Tone capability detection
- `IOKit` — Ambient light sensor, display EDID, temperature
- `ColorSync` — ICC profile application
