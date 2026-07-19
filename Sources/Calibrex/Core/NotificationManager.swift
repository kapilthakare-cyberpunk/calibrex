import Foundation
import UserNotifications
import AppKit

/// Manages Calibrex notifications for calibration events
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    /// Notification categories
    enum NotificationCategory: String {
        case calibration = "CALIBRATION"
        case recalibration = "RECALIBRATION"
        case sensor = "SENSOR"
        case profile = "PROFILE"
        case drift = "DRIFT"
    }
    
    /// Notification actions
    enum NotificationAction: String {
        case calibrateNow = "CALIBRATE_NOW"
        case spotCheck = "SPOT_CHECK"
        case openSettings = "OPEN_SETTINGS"
        case snooze = "SNOOZE"
        case dismiss = "DISMISS"
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        notificationCenter.delegate = self
        requestAuthorization()
        registerCategories()
    }
    
    /// Request notification permission
    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("[Notifications] Authorization granted")
            } else if let error = error {
                print("[Notifications] Authorization error: \(error)")
            } else {
                print("[Notifications] Authorization denied")
            }
        }
    }
    
    /// Register notification categories with actions
    func registerCategories() {
        // Calibration complete
        let calibrateAction = UNNotificationAction(
            identifier: NotificationAction.calibrateNow.rawValue,
            title: "Calibrate Now",
            options: .foreground
        )
        
        let spotCheckAction = UNNotificationAction(
            identifier: NotificationAction.spotCheck.rawValue,
            title: "Spot Check",
            options: .foreground
        )
        
        let calibrationCategory = UNNotificationCategory(
            identifier: NotificationCategory.calibration.rawValue,
            actions: [calibrateAction, spotCheckAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // Recalibration due
        let snoozeAction = UNNotificationAction(
            identifier: NotificationAction.snooze.rawValue,
            title: "Remind Tomorrow",
            options: []
        )
        
        let recalibrationCategory = UNNotificationCategory(
            identifier: NotificationCategory.recalibration.rawValue,
            actions: [calibrateAction, snoozeAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // Sensor events
        let sensorCategory = UNNotificationCategory(
            identifier: NotificationCategory.sensor.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // Profile events
        let profileCategory = UNNotificationCategory(
            identifier: NotificationCategory.profile.rawValue,
            actions: [spotCheckAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // Drift detected
        let driftCategory = UNNotificationCategory(
            identifier: NotificationCategory.drift.rawValue,
            actions: [calibrateAction, snoozeAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        notificationCenter.setNotificationCategories([
            calibrationCategory,
            recalibrationCategory,
            sensorCategory,
            profileCategory,
            driftCategory
        ])
    }
    
    // MARK: - Calibration Notifications
    
    /// Calibration completed successfully
    func notifyCalibrationComplete(deltaE: Double, profileName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Calibration Complete"
        content.subtitle = "Display accuracy: Delta-E \(String(format: "%.1f", deltaE))"
        content.body = "Profile '\(profileName)' has been applied to your display."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.calibration.rawValue
        content.userInfo = [
            "deltaE": deltaE,
            "profileName": profileName
        ]
        
        // Add badge
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "calibration_complete_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    /// Calibration failed
    func notifyCalibrationFailed(error: String) {
        let content = UNMutableNotificationContent()
        content.title = "Calibration Failed"
        content.body = error
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.calibration.rawValue
        
        let request = UNNotificationRequest(
            identifier: "calibration_failed_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Recalibration Notifications
    
    /// Monthly recalibration due
    func notifyRecalibrationDue(daysSinceLast: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Recalibration Due"
        content.body = "It's been \(daysSinceLast) days since your last calibration. Recalibrate for optimal color accuracy."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.recalibration.rawValue
        content.userInfo = ["daysSinceLast": daysSinceLast]
        
        let request = UNNotificationRequest(
            identifier: "recalibration_due",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    /// Spot-check recalibration recommended
    func notifySpotCheckRecommended(deltaE: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Display Drift Detected"
        content.body = "Your display accuracy has decreased (Delta-E: \(String(format: "%.1f", deltaE))). Consider recalibrating."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.drift.rawValue
        content.userInfo = ["deltaE": deltaE]
        
        let request = UNNotificationRequest(
            identifier: "spot_check_recommended_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Sensor Notifications
    
    /// USB sensor connected
    func notifySensorConnected(name: String, type: String) {
        let content = UNMutableNotificationContent()
        content.title = "Sensor Connected"
        content.body = "\(name) (\(type)) detected and ready for calibration."
        content.sound = nil // Silent for sensor events
        content.categoryIdentifier = NotificationCategory.sensor.rawValue
        content.userInfo = ["sensorName": name, "sensorType": type]
        
        let request = UNNotificationRequest(
            identifier: "sensor_connected_\(name)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    /// USB sensor disconnected
    func notifySensorDisconnected(name: String) {
        let content = UNMutableNotificationContent()
        content.title = "Sensor Disconnected"
        content.body = "\(name) has been unplugged."
        content.sound = nil
        content.categoryIdentifier = NotificationCategory.sensor.rawValue
        content.userInfo = ["sensorName": name]
        
        let request = UNNotificationRequest(
            identifier: "sensor_disconnected_\(name)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Profile Notifications
    
    /// Profile applied successfully
    func notifyProfileApplied(profileName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Profile Applied"
        content.body = "ICC profile '\(profileName)' is now active."
        content.sound = nil
        content.categoryIdentifier = NotificationCategory.profile.rawValue
        content.userInfo = ["profileName": profileName]
        
        let request = UNNotificationRequest(
            identifier: "profile_applied_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    /// Profile verification complete
    func notifyProfileVerification(deltaE: Double, quality: String) {
        let content = UNMutableNotificationContent()
        content.title = "Profile Verification"
        content.body = "Accuracy: \(quality) (Delta-E: \(String(format: "%.1f", deltaE)))"
        content.sound = nil
        content.categoryIdentifier = NotificationCategory.profile.rawValue
        content.userInfo = ["deltaE": deltaE, "quality": quality]
        
        let request = UNNotificationRequest(
            identifier: "profile_verification_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Adaptive Mode Notifications
    
    /// Adaptive mode adjusted display
    func notifyAdaptiveAdjustment(brightness: Double, colorTemp: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Display Adjusted"
        content.body = "Brightness: \(Int(brightness * 100))%, Color Temp: \(Int(colorTemp))K"
        content.sound = nil // Silent for adaptive adjustments
        content.categoryIdentifier = NotificationCategory.profile.rawValue
        
        let request = UNNotificationRequest(
            identifier: "adaptive_adjustment_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Scheduled Notifications
    
    /// Schedule a reminder notification
    func scheduleReminder(
        title: String,
        body: String,
        in minutes: Int,
        identifier: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(minutes * 60),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    /// Cancel a scheduled notification
    func cancelNotification(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    /// Cancel all pending notifications
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    /// Clear delivered notifications
    func clearDelivered() {
        notificationCenter.removeAllDeliveredNotificationRequests()
    }
    
    // MARK: - Badge Management
    
    /// Set badge count
    func setBadgeCount(_ count: Int) {
        NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : ""
    }
    
    /// Clear badge
    func clearBadge() {
        setBadgeCount(0)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification actions
        let actionIdentifier = response.actionIdentifier
        
        switch actionIdentifier {
        case NotificationAction.calibrateNow.rawValue:
            NotificationCenter.default.post(
                name: .calibrexShouldCalibrate,
                object: nil
            )
            
        case NotificationAction.spotCheck.rawValue:
            NotificationCenter.default.post(
                name: .calibrexShouldSpotCheck,
                object: nil
            )
            
        case NotificationAction.snooze.rawValue:
            // Schedule reminder for tomorrow
            scheduleReminder(
                title: "Recalibration Reminder",
                body: "Don't forget to recalibrate your display.",
                in: 24 * 60, // 24 hours
                identifier: "snooze_reminder"
            )
            
        case NotificationAction.openSettings.rawValue:
            NotificationCenter.default.post(
                name: .calibrexShouldOpenSettings,
                object: nil
            )
            
        default:
            break
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let calibrexShouldCalibrate = Notification.Name("calibrexShouldCalibrate")
    static let calibrexShouldSpotCheck = Notification.Name("calibrexShouldSpotCheck")
    static let calibrexShouldOpenSettings = Notification.Name("calibrexShouldOpenSettings")
}
