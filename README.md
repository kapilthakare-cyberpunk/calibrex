# Calibrex

**Adaptive Display Calibration Daemon**

An always-on, context-aware display calibration system that continuously measures ambient conditions and adapts your display output for optimal color accuracy — with zero user intervention after initial setup.

## Vision

Calibrex detects your system, reads ambient light and temperature, drives a colorimeter, generates ICC profiles, and continuously adapts your display calibration based on environment changes. One setup, lifetime accuracy.

## Core Features

- **System Detection** — Auto-identifies OS, display hardware, GPU, and connected colorimeters
- **Ambient Sensing** — Reads lux, color temperature, and room temperature via built-in sensors or USB peripherals
- **Colorimeter Integration** — Drives Spyder, X-Rite, and other ArgyllCMS-compatible devices
- **ICC Profile Generation** — Creates and applies display profiles using ArgyllCMS color science
- **Adaptive Calibration** — Continuously adjusts brightness, white point, and gamma based on ambient conditions
- **Per-App Profiles** — Switches calibration context when color-critical apps gain focus
- **Scheduled Recalibration** — Monthly baseline + drift-triggered recalibration via delta-E monitoring
- **Smooth Transitions** — Interpolates adjustments over 2-5 seconds to avoid jarring changes

## Architecture

```
calibrex/
├── Sources/Calibrex/
│   ├── Core/           # Daemon lifecycle, event loop, config
│   ├── Sensors/        # Ambient light, temperature, colorimeter I/O
│   ├── Calibration/    # ArgyllCMS integration, profile generation
│   ├── Adaptation/     # Adaptive engine, transition smoothing
│   ├── Profiles/       # ICC profile management, per-app rules
│   └── Utils/          # System detection, logging, extensions
├── Tests/
├── Docs/               # Technical spec, architecture decisions
├── Scripts/            # Build, install, calibration helpers
└── Config/             # Default configuration, plist files
```

## Adaptation Tiers

| Signal | Frequency | Action |
|--------|-----------|--------|
| App focus change | Event-driven | Switch profile, toggle Night Shift/True Tone |
| Ambient lux | Every 60s | Adjust brightness curve |
| Ambient color temp | Every 120s | Shift white point target |
| Room temperature | Every 5-10min | Factor into aging model |
| Spot-check (delta-E) | Weekly | Verify profile accuracy |
| Full recalibration | Monthly + drift-triggered | Re-run colorimeter + colprof |

## Platform Support

- **macOS** (MVP) — Apple Silicon + Intel, macOS 13+
- **Linux** (planned) — colord integration
- **Windows** (planned) — DDC/CI + WCS

## Dependencies

- [ArgyllCMS](https://www.argyllcms.com) — Color science engine
- [Argyll-macos-arm](https://github.com/lisanet/Argyll-macos-arm) — Apple Silicon support
- macOS private frameworks: CoreBrightness, DisplayServices, IOKit

## License

MIT
