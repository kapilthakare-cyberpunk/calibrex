# Known Issues & Next Session Features

## Issue: Spyder X2 Ultra Detection (BUG)
**Status:** Open
**Description:** Spyder X2 Ultra detection shows "detected" even when disconnected.
**Root Cause:** ArgyllCMS device list is cached; not checking live USB state.
**Fix Needed:** Implement real-time USB device enumeration before showing "detected".

---

## Feature: Fully Autonomous Calibration Flow
**Status:** Planned
**Description:** One-button autonomous calibration from start to finish.

### Flow
1. User connects colorimeter (Spyder X2 Ultra)
2. User clicks "Start Auto Calibration" button
3. **Pre-calibration checks:**
   - Detect colorimeter connection
   - Read current ambient light (lux, color temp)
   - Read current room temperature
   - Apply pre-calibration settings:
     - Set display brightness to optimal level for calibration
     - Disable Night Shift
     - Disable True Tone
     - Disable Adaptive Mode
     - Set display to native resolution
     - Disable any GPU color adjustments
4. **Calibration sequence:**
   - Generate calibration targets via ArgyllCMS
   - Run dispread measurement sequence (~2-3 minutes)
   - Generate ICC profile from measurement data
   - Apply profile to display
   - Verify profile accuracy (delta-E check)
5. **Post-calibration:**
   - Open Finder to profile export folder
   - Show notification with calibration results
   - Re-enable user's preferred settings
6. **Profile export:**
   - Save ICC profile to ~/Library/ColorSync/Profiles/Calibrex/
   - Copy to Desktop for easy access
   - Show profile in Finder

### Ambient-Adaptive Settings
Before calibration starts, the system should:
- Read ambient lux level
- Read ambient color temperature
- Calculate optimal calibration settings based on ambient conditions
- Apply these settings to ensure accurate measurements
- Log all pre-calibration state for restoration after calibration

### UI Changes Needed
- Replace "Calibrate Now" with "Auto Calibrate" button
- Show pre-calibration checklist with checkmarks
- Show real-time measurement progress with patch count
- Show final delta-E result with quality rating
- Button to open profile folder in Finder
