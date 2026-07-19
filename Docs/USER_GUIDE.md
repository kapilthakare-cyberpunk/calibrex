# Calibrex User Guide

## Introduction

Calibrex is an adaptive display calibration daemon for macOS that continuously monitors ambient conditions and adapts your display output for optimal color accuracy.

## Features

- **Ambient Sensing** — Reads lux, color temperature, and room temperature
- **Auto-calibration** — Monthly calibration with drift detection
- **Per-app Rules** — Different settings for different applications
- **USB Sensor Support** — TSL2591 and BH1750 ambient light sensors
- **Colorimeter Integration** — Spyder and i1 Display Pro support
- **Menu Bar UI** — Quick controls and status display

## Installation

### Requirements

- macOS 13 (Ventura) or later
- Apple Silicon or Intel Mac
- Colorimeter (optional): Datacolor Spyder or X-Rite i1 Display
- USB sensor (optional): TSL2591 or BH1750 via Arduino/ESP32

### Install from GitHub

1. Download the latest release from GitHub
2. Drag Calibrex.app to your Applications folder
3. Launch Calibrex
4. Grant required permissions when prompted

### Install via Homebrew

```bash
brew tap kapilthakare-cyberpunk/calibrex
brew install --cask calibrex
```

## Getting Started

### First Launch

1. Calibrex will request notification permissions
2. The menu bar icon appears (circle.fill)
3. Click the icon to see status and controls

### Initial Calibration

1. Click "Calibrate Now" in the menu bar
2. Follow the calibration wizard:
   - Connect colorimeter via USB
   - Place colorimeter on screen
   - Wait for measurements to complete
   - Review verification results
3. Profile is automatically applied

## Menu Bar

### Status Display

| Indicator | Meaning |
|-----------|---------|
| **Ambient Light** | Current lux reading |
| **Color Temp** | Current color temperature (K) |
| **Brightness** | Current display brightness (%) |
| **Profile** | Active ICC profile name |
| **Accuracy** | Delta-E accuracy rating |

### Quick Controls

| Control | Function |
|---------|----------|
| **Night Shift** | Toggle macOS Night Shift |
| **True Tone** | Toggle True Tone (if supported) |
| **Adaptive Mode** | Enable/disable automatic adjustments |

### Actions

| Action | Function |
|--------|----------|
| **Calibrate Now** | Open calibration wizard |
| **Spot Check** | Verify current profile accuracy |
| **Settings** | Open settings window |
| **Quit** | Exit Calibrex |

## Settings

### General

| Setting | Description | Default |
|---------|-------------|---------|
| Launch at login | Start Calibrex on login | On |
| Show menu bar icon | Show/hide menu bar icon | On |
| Ambient light source | Sensor priority | Auto-detect |

### Calibration

| Setting | Description | Default |
|---------|-------------|---------|
| Monthly recalibration | Enable monthly calibration | On |
| Spot-check interval | Days between spot-checks | 7 days |
| Delta-E threshold | Accuracy threshold for alerts | 3.0 |
| Profile quality | Calibration quality level | High |

### App Rules

Per-app rules control Night Shift and True Tone behavior:

| App | Night Shift | True Tone |
|-----|-------------|-----------|
| Adobe Photoshop | Off | Off |
| Final Cut Pro | Off | Off |
| DaVinci Resolve | Off | Off |

### Advanced

| Setting | Description | Default |
|---------|-------------|---------|
| Ambient light poll | Lux reading interval | 60s |
| Color temp poll | Color temp interval | 120s |
| Transition duration | Adjustment animation | 2.0s |
| Lux threshold | Change threshold | 15% |

## USB Sensors

### Supported Sensors

| Sensor | Type | Precision |
|--------|------|-----------|
| TSL2591 | High-precision luminosity | 188 μlux - 88,000 lux |
| BH1750 | Ambient light | 1 lux - 65535 lux |

### Arduino Setup

1. Flash the Calibrex firmware to Arduino/ESP32
2. Connect sensor (TSL2591 or BH1750) via I2C
3. Connect Arduino via USB
4. Calibrex auto-detects the sensor

### Wiring

#### TSL2591

| TSL2591 | Arduino Uno | ESP32 |
|---------|-------------|-------|
| VIN | 3.3V | 3.3V |
| GND | GND | GND |
| SCL | A5 | GPIO22 |
| SDA | A4 | GPIO21 |

#### BH1750

| BH1750 | Arduino Uno | ESP32 |
|--------|-------------|-------|
| VIN | 3.3V/5V | 3.3V |
| GND | GND | GND |
| SCL | A5 | GPIO22 |
| SDA | A4 | GPIO21 |

## Calibration

### Full Calibration

1. Connect colorimeter
2. Click "Calibrate Now"
3. Follow wizard steps
4. Profile is applied automatically

### Spot Check

1. Click "Spot Check"
2. Place colorimeter on screen
3. View delta-E result

### Recalibration

Calibrex recommends recalibration when:
- Monthly cycle completes
- Delta-E exceeds threshold (3.0)
- Display hardware changes

## Adaptive Mode

When enabled, Calibrex automatically adjusts:

- **Brightness** — Based on ambient lux
- **White point** — Based on ambient color temperature
- **Night Shift** — Disabled for color-critical apps
- **True Tone** — Disabled for color-critical apps

### Thresholds

| Signal | Threshold | Action |
|--------|-----------|--------|
| Lux change | > 15% | Adjust brightness |
| Color temp change | > 200K | Adjust white point |
| App focus change | Instant | Switch settings |

## Troubleshooting

### No colorimeter detected

- Check USB connection
- Try different USB port
- Verify ArgyllCMS is installed

### Sensor not reading

- Check I2C wiring
- Verify sensor power (3.3V)
- Check Arduino firmware

### Night Shift not toggling

- Grant CoreBrightness permissions
- Restart Calibrex
- Check System Settings → Privacy

### Profile not applying

- Verify ArgyllCMS is installed
- Check profile file permissions
- Restart display

## Uninstalling

1. Quit Calibrex
2. Remove from Applications
3. Remove launch agent:
   ```bash
   rm ~/Library/LaunchAgents/com.calibrex.daemon.plist
   ```
4. Remove config:
   ```bash
   rm -rf ~/Library/Application\ Support/Calibrex
   ```
