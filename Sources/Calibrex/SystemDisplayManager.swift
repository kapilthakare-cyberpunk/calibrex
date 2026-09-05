import Foundation

/// Manages system-level display features: Night Shift, True Tone, and ambient light compensation.
///
/// Uses the CoreBrightness private framework (loaded via `dlopen` for runtime
/// access) to control Night Shift and True Tone. Falls back to shell commands
/// when the private framework APIs are unavailable.
///
/// - Night Shift is controlled via `CBBlueLightClient.setEnabled:`
///   (requires `enableNotifications` + `setActive:` before use).
/// - True Tone is controlled via `CBTrueToneClient.setEnabled:`
///   (requires `activate` before use).
final class SystemDisplayManager: ObservableObject {

    // MARK: - Properties

    /// Handle to the loaded CoreBrightness private framework (nil if unavailable).
    private var cbFramework: UnsafeMutableRawPointer?

    /// Whether the CoreBrightness framework was successfully loaded.
    private let coreBrightnessAvailable: Bool

    // MARK: - Init

    init() {
        cbFramework = dlopen(
            "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
            RTLD_NOW | RTLD_LOCAL
        )

        if cbFramework == nil {
            let err = String(cString: dlerror())
            print("[SystemDisplayManager] Could not load CoreBrightness framework: \(err)")
        }

        coreBrightnessAvailable = cbFramework != nil
    }

    deinit {
        if let framework = cbFramework {
            dlclose(framework)
        }
    }

    // MARK: - Night Shift

    /// Enables or disables macOS Night Shift (blue-light filtering).
    ///
    /// - Parameter enabled: Whether Night Shift should be active.
    /// - Returns: `true` if the operation succeeded.
    @discardableResult
    func setNightShift(enabled: Bool) -> Bool {
        // Primary: CoreBrightness private API (CBBlueLightClient)
        if setNightShiftViaCoreBrightness(enabled: enabled) {
            print("[SystemDisplayManager] Night Shift \(enabled ? "enabled" : "disabled") via CoreBrightness")
            return true
        }

        // Fallback: write preferences and restart the relevant service
        if setNightShiftViaShell(enabled: enabled) {
            print("[SystemDisplayManager] Night Shift \(enabled ? "enabled" : "disabled") via shell fallback")
            return true
        }

        print("[SystemDisplayManager] Failed to toggle Night Shift")
        return false
    }

    /// Reads the current Night Shift state from macOS preferences.
    func isNightShiftEnabled() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["-currentHost", "read", "com.apple.CoreDisplay", "NightShiftEnabled"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return output == "1" || output == "true"
        } catch {
            print("[SystemDisplayManager] Error reading Night Shift state: \(error)")
            return false
        }
    }

    // MARK: - Night Shift Implementation

    /// Uses `CBBlueLightClient` from the CoreBrightness framework to toggle Night Shift.
    ///
    /// CBBlueLightClient requires three steps:
    /// 1. `enableNotifications` — start listening for system display events
    /// 2. `setActive:` — connect to the brightness system service
    /// 3. `setEnabled:` — actually enable/disable blue light reduction
    private func setNightShiftViaCoreBrightness(enabled: Bool) -> Bool {
        guard coreBrightnessAvailable, cbFramework != nil else { return false }

        guard let instance = createPrivateInstance(className: "CBBlueLightClient") else {
            return false
        }

        // Step 1: Enable notifications
        if instance.responds(to: NSSelectorFromString("enableNotifications")) {
            instance.perform(NSSelectorFromString("enableNotifications"))
        }

        // Step 2: Set active
        if instance.responds(to: NSSelectorFromString("setActive:")) {
            instance.perform(NSSelectorFromString("setActive:"), with: NSNumber(value: true))
        }

        // Step 3: Set enabled
        let selector = NSSelectorFromString("setEnabled:")
        if instance.responds(to: selector) {
            instance.perform(selector, with: NSNumber(value: enabled))
            syncPreferences()
            return true
        }

        // Fallback: try setEnabled:withOption:
        let altSelector = NSSelectorFromString("setEnabled:withOption:")
        if instance.responds(to: altSelector) {
            instance.perform(altSelector, with: NSNumber(value: enabled), with: NSNumber(value: 0))
            syncPreferences()
            return true
        }

        return false
    }

    /// Fallback that writes Night Shift preferences and restarts NotificationCenter.
    private func setNightShiftViaShell(enabled: Bool) -> Bool {
        let value = enabled ? "true" : "false"
        let script = """
        defaults -currentHost write com.apple.CoreDisplay NightShiftEnabled -bool \(value) 2>/dev/null
        defaults -currentHost write com.apple.CoreDisplay NightShiftSchedule -int 2 2>/dev/null
        killall NotificationCenter 2>/dev/null
        """
        return runShellScript(script)
    }

    // MARK: - True Tone

    /// Enables or disables macOS True Tone.
    ///
    /// - Parameter enabled: Whether True Tone should be active.
    /// - Returns: `true` if the operation succeeded.
    @discardableResult
    func setTrueTone(enabled: Bool) -> Bool {
        if setTrueToneViaCoreBrightness(enabled: enabled) {
            print("[SystemDisplayManager] True Tone \(enabled ? "enabled" : "disabled") via CoreBrightness")
            return true
        }

        print("[SystemDisplayManager] Failed to toggle True Tone")
        return false
    }

    // MARK: - True Tone Implementation

    /// Uses `CBTrueToneClient` from the CoreBrightness framework to toggle True Tone.
    ///
    /// CBTrueToneClient requires two steps:
    /// 1. `activate` — connect to the display services
    /// 2. `setEnabled:` — actually enable/disable True Tone
    private func setTrueToneViaCoreBrightness(enabled: Bool) -> Bool {
        guard coreBrightnessAvailable, cbFramework != nil else { return false }

        guard let instance = createPrivateInstance(className: "CBTrueToneClient") else {
            return false
        }

        // Step 1: Activate
        if instance.responds(to: NSSelectorFromString("activate")) {
            instance.perform(NSSelectorFromString("activate"))
        }

        // Step 2: Set enabled
        let selector = NSSelectorFromString("setEnabled:")
        if instance.responds(to: selector) {
            instance.perform(selector, with: NSNumber(value: enabled))
            syncPreferences()
            return true
        }

        return false
    }

    /// Reads the current True Tone state from macOS preferences.
    func isTrueToneEnabled() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["-currentHost", "read", "com.apple.CoreDisplay", "TrueToneEnabled"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return output == "1" || output == "true"
        } catch {
            print("[SystemDisplayManager] Error reading True Tone state: \(error)")
            return false
        }
    }

    // MARK: - Ambient Light Compensation

    /// Enables or disables ambient light compensation (auto-brightness-style).
    @discardableResult
    func setAmbientLightCompensation(enabled: Bool) -> Bool {
        guard coreBrightnessAvailable, cbFramework != nil else { return false }

        // Try CBAdaptationClient (color adaptation = ambient light compensation)
        if let instance = createPrivateInstance(className: "CBAdaptationClient") {
            // Enable notifications first
            if instance.responds(to: NSSelectorFromString("enableNotifications")) {
                instance.perform(NSSelectorFromString("enableNotifications"))
            }
            // Set active if available
            if instance.responds(to: NSSelectorFromString("setActive:")) {
                instance.perform(NSSelectorFromString("setActive:"), with: NSNumber(value: true))
            }
            // Set enabled
            let selector = NSSelectorFromString("setEnabled:")
            if instance.responds(to: selector) {
                instance.perform(selector, with: NSNumber(value: enabled))
                syncPreferences()
                return true
            }
        }

        return false
    }

    // MARK: - Helpers

    /// Loads a private CoreBrightness class and returns an initialized instance
    /// (alloc → init).
    private func createPrivateInstance(className: String) -> NSObject? {
        guard let cls: AnyClass = NSClassFromString(className) else {
            print("[SystemDisplayManager] Class \(className) not found in CoreBrightness")
            return nil
        }

        let nsCls = cls as! NSObject.Type

        // alloc()
        guard let allocResult = nsCls.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue()
                as? NSObject else {
            print("[SystemDisplayManager] Failed to alloc \(className)")
            return nil
        }

        // init()
        guard let instance = allocResult.perform(NSSelectorFromString("init"))?.takeUnretainedValue()
                as? NSObject else {
            print("[SystemDisplayManager] Failed to init \(className)")
            return nil
        }

        return instance
    }

    /// Tells the display system to persist any pending preference changes
    /// by restarting NotificationCenter (which manages Night Shift scheduling).
    private func syncPreferences() {
        let script = "killall NotificationCenter 2>/dev/null; true"
        _ = runShellScript(script)
    }

    /// Runs a shell script and returns whether it succeeded.
    @discardableResult
    private func runShellScript(_ script: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", script]
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            print("[SystemDisplayManager] Shell script error: \(error)")
            return false
        }
    }
}
