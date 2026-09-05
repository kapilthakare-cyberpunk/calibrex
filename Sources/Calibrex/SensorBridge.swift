import Foundation

/// SensorBridge handles communication with the Calibrex USB sensor firmware.
class SensorBridge {
    private let devicePath: String
    private var fileHandle: FileHandle?

    init(devicePath: String = "/dev/cu.usbserial-110") {
        self.devicePath = devicePath
    }

    private func openDevice() -> Bool {
        guard fileHandle == nil else { return true }
        do {
            fileHandle = try FileHandle(forUpdating: URL(fileURLWithPath: devicePath))
            return true
        } catch {
            print("[SensorBridge] Error opening device \(devicePath): \(error)")
            return false
        }
    }

    private func sendCommand(_ command: String) -> String {
        guard openDevice() else { return "ERROR:COULD_NOT_OPEN_DEVICE" }

        let cmdData = (command + "\n").data(using: .utf8)!
        fileHandle?.write(cmdData)

        // Read response (simple blocking read for this implementation)
        let data = fileHandle?.readData(ofLength: 1024) ?? Data()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func identify() -> String {
        return sendCommand("IDENTIFY")
    }

    func readLux() -> Double? {
        let response = sendCommand("READ")
        if response.contains("LUX:") {
            let parts = response.components(separatedBy: "LUX:")
            if parts.count > 1 {
                let luxString = parts[1].components(separatedBy: "|")[0]
                return Double(luxString)
            }
        }
        return nil
    }

    func isStable(samples: Int = 5, threshold: Double = 5.0) -> Bool {
        var readings: [Double] = []
        for _ in 0..<samples {
            if let lux = readLux() {
                readings.append(lux)
            }
            Thread.sleep(forTimeInterval: 0.2)
        }

        guard readings.count >= 2 else { return false }

        let minLux = readings.min() ?? 0
        let maxLux = readings.max() ?? 0
        return (maxLux - minLux) < threshold
    }

    func close() {
        fileHandle?.closeFile()
        fileHandle = nil
    }
}
