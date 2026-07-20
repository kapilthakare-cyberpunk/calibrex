import Foundation
import IOKit
import IOKit.serial

/// Detects USB device connect/disconnect events in real-time
class USBHotplugDetector {
    
    private var runLoopSource: CFRunLoopSource?
    private var notificationPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = IO_OBJECT_NULL
    private var removedIterator: io_iterator_t = IO_OBJECT_NULL
    
    private var knownDevices: [String: USBDevice] = [:]
    
    /// Callback when device is connected
    var onDeviceConnected: ((USBDevice) -> Void)?
    
    /// Callback when device is disconnected
    var onDeviceDisconnected: ((USBDevice) -> Void)?
    
    /// Callback when device list changes
    var onDeviceListChanged: (([USBDevice]) -> Void)?
    
    struct USBDevice {
        let id: String
        let name: String
        let vendorId: Int
        let productId: Int
        let path: String
        let type: USBDeviceType
        let connectedAt: Date
    }
    
    enum USBDeviceType {
        case arduino
        case esp32
        case colorimeter
        case sensor
        case unknown
        
        var description: String {
            switch self {
            case .arduino: return "Arduino"
            case .esp32: return "ESP32"
            case .colorimeter: return "Colorimeter"
            case .sensor: return "Sensor"
            case .unknown: return "Unknown"
            }
        }
    }
    
    // MARK: - Known Vendor IDs
    
    private static let knownVendorIds: [Int: String] = [
        0x2341: "Arduino",
        0x1A86: "CH340 (ESP32)",
        0x10C4: "CP210x (ESP32)",
        0x0403: "FTDI",
        0x03EB: "Atmel",
        0x1FC9: "NXP (Teensy)",
        0x2A03: "Arduino.org"
    ]
    
    // MARK: - Start/Stop Monitoring
    
    /// Start monitoring for USB events
    func startMonitoring() -> Bool {
        print("[USBHotplug] Starting USB monitoring...")
        
        // Create notification port
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        
        guard let notificationPort = notificationPort else {
            print("[USBHotplug] Failed to create notification port")
            return false
        }
        
        // Add to run loop
        if let source = IONotificationPortGetRunLoopSource(notificationPort)?.takeUnretainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
        
        // Set up matching for USB devices
        let matching = IOServiceMatching("IOUSBDevice")
        
        // Watch for device additions
        let addResult = IOServiceAddMatchingNotification(
            notificationPort,
            kIOFirstMatchNotification,
            matching,
            deviceAddedCallback,
            Unmanaged.passUnretained(self).toOpaque(),
            &addedIterator
        )
        
        guard addResult == KERN_SUCCESS else {
            print("[USBHotplug] Failed to add matching notification")
            return false
        }
        
        // Initial device enumeration
        processDeviceIterator(addedIterator)
        
        // Watch for device removals
        let removeResult = IOServiceAddMatchingNotification(
            notificationPort,
            kIOTerminatedNotification,
            matching,
            deviceRemovedCallback,
            Unmanaged.passUnretained(self).toOpaque(),
            &removedIterator
        )
        
        guard removeResult == KERN_SUCCESS else {
            print("[USBHotplug] Failed to add removal notification")
            return false
        }
        
        // Process initial removals
        processDeviceIterator(removedIterator)
        
        print("[USBHotplug] Monitoring started - \(knownDevices.count) devices found")
        return true
    }
    
    /// Stop monitoring for USB events
    func stopMonitoring() {
        print("[USBHotplug] Stopping USB monitoring...")
        
        if addedIterator != IO_OBJECT_NULL {
            IOObjectRelease(addedIterator)
            addedIterator = IO_OBJECT_NULL
        }
        
        if removedIterator != IO_OBJECT_NULL {
            IOObjectRelease(removedIterator)
            removedIterator = IO_OBJECT_NULL
        }
        
        if let notificationPort = notificationPort {
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
            self.runLoopSource = nil
        }
        
        print("[USBHotplug] Monitoring stopped")
    }
    
    // MARK: - Device Processing
    
    func processDeviceIterator(_ iterator: io_iterator_t) {
        var device = IOIteratorNext(iterator)
        
        while device != IO_OBJECT_NULL {
            processDevice(device)
            IOObjectRelease(device)
            device = IOIteratorNext(iterator)
        }
    }
    
    private func processDevice(_ device: io_service_t) {
        // Get device properties
        guard let properties = getDeviceProperties(device) else { return }
        
        let vendorId = properties.vendorId ?? 0
        let productId = properties.productId ?? 0
        let path = properties.path ?? ""
        let name = properties.product ?? "Unknown USB Device"
        
        let id = "\(vendorId):\(productId):\(path)"
        
        // Check if we already know this device
        if knownDevices[id] != nil {
            return // Already tracked
        }
        
        // Determine device type
        let type = identifyDeviceType(vendorId: vendorId, productId: productId, name: name)
        
        // Only track relevant devices
        guard type != .unknown || isRelevantDevice(vendorId: vendorId, productId: productId) else {
            return
        }
        
        let usbDevice = USBDevice(
            id: id,
            name: name,
            vendorId: vendorId,
            productId: productId,
            path: path,
            type: type,
            connectedAt: Date()
        )
        
        knownDevices[id] = usbDevice
        
        print("[USBHotplug] Device connected: \(name) (\(type.description))")
        
        // Notify callback
        DispatchQueue.main.async {
            self.onDeviceConnected?(usbDevice)
            self.onDeviceListChanged?(Array(self.knownDevices.values))
        }
    }
    
    func handleDeviceRemoval(_ device: io_service_t) {
        guard let properties = getDeviceProperties(device) else { return }
        
        let vendorId = properties.vendorId ?? 0
        let productId = properties.productId ?? 0
        let path = properties.path ?? ""
        
        let id = "\(vendorId):\(productId):\(path)"
        
        guard let removedDevice = knownDevices[id] else {
            return
        }
        
        knownDevices.removeValue(forKey: id)
        
        print("[USBHotplug] Device disconnected: \(removedDevice.name)")
        
        // Notify callback
        DispatchQueue.main.async {
            self.onDeviceDisconnected?(removedDevice)
            self.onDeviceListChanged?(Array(self.knownDevices.values))
        }
    }
    
    // MARK: - Device Properties
    
    private func getDeviceProperties(_ device: io_service_t) -> (vendorId: Int?, productId: Int?, path: String?, product: String?)? {
        var vendorId: Int?
        var productId: Int?
        var path: String?
        var product: String?
        
        // Get vendor ID
        if let vendorRef = IORegistryEntryCreateCFProperty(device, "idVendor" as CFString, nil, 0) {
            vendorId = vendorRef.takeRetainedValue() as? Int
        }
        
        // Get product ID
        if let productRef = IORegistryEntryCreateCFProperty(device, "idProduct" as CFString, nil, 0) {
            productId = productRef.takeRetainedValue() as? Int
        }
        
        // Get product name
        if let nameRef = IORegistryEntryCreateCFProperty(device, "USB Product Name" as CFString, nil, 0) {
            product = nameRef.takeRetainedValue() as? String
        }
        
        // Get path
        if let pathRef = IORegistryEntryCreateCFProperty(device, "USB Port Path" as CFString, nil, 0) {
            path = pathRef.takeRetainedValue() as? String
        }
        
        guard vendorId != nil || productId != nil else {
            return nil
        }
        
        return (vendorId, productId, path, product)
    }
    
    // MARK: - Device Type Identification
    
    private func identifyDeviceType(vendorId: Int, productId: Int, name: String) -> USBDeviceType {
        let lowerName = name.lowercased()
        
        // Arduino detection
        if vendorId == 0x2341 || vendorId == 0x2A03 || lowerName.contains("arduino") {
            return .arduino
        }
        
        // ESP32 detection (CH340, CP210x, FTDI chips)
        if vendorId == 0x1A86 || vendorId == 0x10C4 || vendorId == 0x0403 {
            if lowerName.contains("esp") || lowerName.contains("cp210") || lowerName.contains("ch340") {
                return .esp32
            }
        }
        
        // Colorimeter detection
        if lowerName.contains("spyder") || lowerName.contains("colorimeter") {
            return .colorimeter
        }
        
        // Sensor detection
        if lowerName.contains("tsl2591") || lowerName.contains("bh1750") || lowerName.contains("sensor") {
            return .sensor
        }
        
        return .unknown
    }
    
    private func isRelevantDevice(vendorId: Int, productId: Int) -> Bool {
        // Check if this is a known Arduino/ESP32 device
        return USBHotplugDetector.knownVendorIds.keys.contains(vendorId)
    }
    
    // MARK: - Public Accessors
    
    /// Get list of currently connected devices
    func getConnectedDevices() -> [USBDevice] {
        return Array(knownDevices.values)
    }
    
    /// Get connected devices of specific type
    func getDevices(ofType type: USBDeviceType) -> [USBDevice] {
        return knownDevices.values.filter { $0.type == type }
    }
    
    /// Get connected Arduino/ESP32 devices
    func getMicrocontrollerDevices() -> [USBDevice] {
        return knownDevices.values.filter { $0.type == .arduino || $0.type == .esp32 }
    }
    
    /// Get connected colorimeter devices
    func getColorimeterDevices() -> [USBDevice] {
        return knownDevices.values.filter { $0.type == .colorimeter }
    }
    
    /// Check if specific device type is connected
    func hasDeviceOfType(_ type: USBDeviceType) -> Bool {
        return knownDevices.values.contains { $0.type == type }
    }
    
    /// Get device count
    var deviceCount: Int {
        return knownDevices.count
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - C Callback Functions

private func deviceAddedCallback(
    refCon: UnsafeMutableRawPointer?,
    iterator: io_iterator_t
) {
    guard let refCon = refCon else { return }
    
    let detector = Unmanaged<USBHotplugDetector>.fromOpaque(refCon).takeUnretainedValue()
    detector.processDeviceIterator(iterator)
}

private func deviceRemovedCallback(
    refCon: UnsafeMutableRawPointer?,
    iterator: io_iterator_t
) {
    guard let refCon = refCon else { return }
    
    let detector = Unmanaged<USBHotplugDetector>.fromOpaque(refCon).takeUnretainedValue()
    
    var device = IOIteratorNext(iterator)
    while device != IO_OBJECT_NULL {
        detector.handleDeviceRemoval(device)
        IOObjectRelease(device)
        device = IOIteratorNext(iterator)
    }
}
