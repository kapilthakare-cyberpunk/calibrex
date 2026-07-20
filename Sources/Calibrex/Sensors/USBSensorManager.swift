import Foundation

/// Manages USB-connected ambient sensors with hot-plug detection
/// Auto-detects and reads from TSL2591, BH1750, and temperature sensors
class USBSensorManager {
    
    private var tsl2591: TSL2591Sensor?
    private var bh1750: BH1750Sensor?
    
    private var connectedSensors: [String: ConnectedSensor] = [:]
    private let hotplugDetector = USBHotplugDetector()
    private var isMonitoring = false
    
    /// Callback when sensors change
    var onSensorsChanged: (([ConnectedSensor]) -> Void)?
    
    struct ConnectedSensor {
        let name: String
        let type: SensorType
        let port: String
    }
    
    enum SensorType {
        case tsl2591
        case bh1750
        case dht22
        case ds18b20
    }
    
    // MARK: - Hot-plug Monitoring
    
    /// Start monitoring for USB connect/disconnect events
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        hotplugDetector.onDeviceConnected = { [weak self] device in
            self?.handleDeviceConnected(device)
        }
        
        hotplugDetector.onDeviceDisconnected = { [weak self] device in
            self?.handleDeviceDisconnected(device)
        }
        
        if hotplugDetector.startMonitoring() {
            isMonitoring = true
            print("[USBManager] Hot-plug monitoring started")
        }
    }
    
    /// Stop monitoring for USB events
    func stopMonitoring() {
        hotplugDetector.stopMonitoring()
        isMonitoring = false
        print("[USBManager] Hot-plug monitoring stopped")
    }
    
    private func handleDeviceConnected(_ device: USBHotplugDetector.USBDevice) {
        print("[USBManager] Device connected: \(device.name)")
        
        // Try to connect to the new device
        _ = scanAndConnect()
        
        // Notify listeners
        DispatchQueue.main.async {
            self.onSensorsChanged?(Array(self.connectedSensors.values))
        }
    }
    
    private func handleDeviceDisconnected(_ device: USBHotplugDetector.USBDevice) {
        print("[USBManager] Device disconnected: \(device.name)")
        
        // Check if it was a connected sensor
        for (key, sensor) in connectedSensors {
            if sensor.port.contains(String(device.vendorId, radix: 16)) ||
               sensor.name.lowercased().contains(device.name.lowercased()) {
                disconnectSensor(key: key)
                break
            }
        }
        
        // Notify listeners
        DispatchQueue.main.async {
            self.onSensorsChanged?(Array(self.connectedSensors.values))
        }
    }
    
    private func disconnectSensor(key: String) {
        switch key {
        case "tsl2591":
            tsl2591?.disconnect()
            tsl2591 = nil
        case "bh1750":
            bh1750?.disconnect()
            bh1750 = nil
        default:
            break
        }
        connectedSensors.removeValue(forKey: key)
        print("[USBManager] Disconnected sensor: \(key)")
    }
    
    /// Scan for and connect to available sensors
    func scanAndConnect() -> [ConnectedSensor] {
        print("[USBManager] Scanning for sensors...")
        
        let ports = SerialCommunication.listPorts()
        var found: [ConnectedSensor] = []
        
        for port in ports where port.type != .unknown {
            // Try TSL2591
            let tsl = TSL2591Sensor()
            if tsl.connect(port: port.path) {
                let sensor = ConnectedSensor(
                    name: "TSL2591",
                    type: .tsl2591,
                    port: port.path
                )
                connectedSensors["tsl2591"] = sensor
                tsl2591 = tsl
                found.append(sensor)
                print("[USBManager] Found TSL2591 on \(port.name)")
                continue
            }
            
            // Try BH1750
            let bh = BH1750Sensor()
            if bh.connect(port: port.path) {
                let sensor = ConnectedSensor(
                    name: "BH1750",
                    type: .bh1750,
                    port: port.path
                )
                connectedSensors["bh1750"] = sensor
                bh1750 = bh
                found.append(sensor)
                print("[USBManager] Found BH1750 on \(port.name)")
                continue
            }
            
            // Try temperature sensors (DHT22, DS18B20)
            if let tempSensor = connectTempSensor(port: port.path) {
                found.append(tempSensor)
            }
        }
        
        print("[USBManager] Found \(found.count) sensors")
        return found
    }
    
    /// Try to connect to a temperature sensor
    private func connectTempSensor(port: String) -> ConnectedSensor? {
        let serial = SerialCommunication()
        
        guard serial.open(port: port, baudRate: 9600) else { return nil }
        
        Thread.sleep(forTimeInterval: 2.0)
        serial.flushInput()
        
        serial.writeLine("IDENTIFY")
        
        if let response = serial.readLine() {
            if response.contains("DHT22") || response.contains("DHT") {
                print("[USBManager] Found DHT22 on \(port)")
                // TODO: Store DHT22 connection
                return ConnectedSensor(name: "DHT22", type: .dht22, port: port)
            }
            
            if response.contains("DS18B20") || response.contains("DS18") {
                print("[USBManager] Found DS18B20 on \(port)")
                // TODO: Store DS18B20 connection
                return ConnectedSensor(name: "DS18B20", type: .ds18b20, port: port)
            }
        }
        
        serial.close()
        return nil
    }
    
    // MARK: - Readings
    
    /// Read ambient light in lux from any connected light sensor
    func readLux() -> Double? {
        // Priority: TSL2591 > BH1750 > nil
        
        if let tsl = tsl2591, let data = tsl.read() {
            return data.lux
        }
        
        if let bh = bh1750, let data = bh.read() {
            return data.lux
        }
        
        return nil
    }
    
    /// Read color temperature from TSL2591
    func readColorTemp() -> Double? {
        guard let tsl = tsl2591, let data = tsl.read() else {
            return nil
        }
        
        return data.colorTemperature
    }
    
    /// Read room temperature from connected temp sensor
    func readTemperature() -> Double? {
        // TODO: Implement temperature reading from DHT22/DS18B20
        return nil
    }
    
    /// Read all available data
    func readAll() -> USBReadings {
        let lux = readLux()
        let colorTemp = readColorTemp()
        let temperature = readTemperature()
        
        return USBReadings(
            lux: lux,
            colorTemperature: colorTemp,
            temperature: temperature,
            timestamp: Date()
        )
    }
    
    // MARK: - Configuration
    
    /// Configure TSL2591 gain
    func setTSL2591Gain(_ gain: TSL2591Sensor.Gain) {
        tsl2591?.setGain(gain)
    }
    
    /// Configure BH1750 mode
    func setBH1750Mode(_ mode: BH1750Sensor.MeasurementMode) {
        bh1750?.setMode(mode)
    }
    
    /// Disconnect all sensors
    func disconnectAll() {
        tsl2591?.disconnect()
        bh1750?.disconnect()
        tsl2591 = nil
        bh1750 = nil
        connectedSensors.removeAll()
        print("[USBManager] Disconnected all sensors")
    }
    
    /// Get list of connected sensors
    func getConnectedSensors() -> [ConnectedSensor] {
        return Array(connectedSensors.values)
    }
    
    /// Check if any light sensor is connected
    var hasLightSensor: Bool {
        return tsl2591 != nil || bh1750 != nil
    }
    
    /// Check if any temperature sensor is connected
    var hasTempSensor: Bool {
        return connectedSensors.values.contains { $0.type == .dht22 || $0.type == .ds18b20 }
    }
    
    deinit {
        disconnectAll()
    }
}

// MARK: - Data Types

struct USBReadings {
    let lux: Double?
    let colorTemperature: Double?
    let temperature: Double?
    let timestamp: Date
}
