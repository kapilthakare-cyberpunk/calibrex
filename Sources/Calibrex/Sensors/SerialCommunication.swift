import Foundation

/// USB Serial communication for Arduino/ESP32 sensor bridges
class SerialCommunication {
    
    private var fileDescriptor: Int32 = -1
    private var portPath: String = ""
    
    /// List available serial ports
    static func listPorts() -> [SerialPort] {
        var ports: [SerialPort] = []
        
        // Check /dev/cu.* for serial devices
        let devPath = "/dev"
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: devPath) else {
            return ports
        }
        
        for item in contents {
            if item.hasPrefix("cu.") || item.hasPrefix("tty.") {
                let path = "\(devPath)/\(item)"
                let name = item.replacingOccurrences(of: "cu.", with: "")
                    .replacingOccurrences(of: "tty.", with: "")
                
                // Identify device type
                let type = identifyDevice(name: name, path: path)
                
                ports.append(SerialPort(
                    name: name,
                    path: path,
                    type: type
                ))
            }
        }
        
        return ports
    }
    
    /// Identify Arduino/ESP32 devices
    private static func identifyDevice(name: String, path: String) -> SerialPortType {
        let lowerName = name.lowercased()
        
        // Arduino devices
        if lowerName.contains("arduino") || lowerName.contains("usbmodem") || lowerName.contains("usbserial") {
            return .arduino
        }
        
        // ESP32 devices
        if lowerName.contains("esp32") || lowerName.contains("cp210") || lowerName.contains("ch340") || lowerName.contains("ftdi") {
            return .esp32
        }
        
        return .unknown
    }
    
    /// Open serial connection
    func open(port: String, baudRate: Int = 115200) -> Bool {
        portPath = port
        
        // Open serial port
        fileDescriptor = Darwin.open(port, O_RDWR | O_NOCTTY | O_NDELAY)
        
        guard fileDescriptor >= 0 else {
            print("[Serial] Failed to open \(port)")
            return false
        }
        
        // Configure terminal
        var options = termios()
        tcgetattr(fileDescriptor, &options)
        
        // Set baud rate
        let speed = speed_t(baudRate)
        cfsetispeed(&options, speed)
        cfsetospeed(&options, speed)
        
        // 8N1 (8 data bits, no parity, 1 stop bit)
        options.c_cflag |= UInt(CSIZE | CS8)
        options.c_cflag &= ~UInt(PARENB)
        options.c_cflag &= ~UInt(CSTOPB)
        
        // Enable receiver
        options.c_cflag |= UInt(CREAD | CLOCAL)
        
        // Raw input
        options.c_lflag &= ~UInt(ICANON | ECHO | ECHOE | ISIG)
        
        // Raw output
        options.c_oflag &= ~UInt(OPOST)
        
        // No flow control
        options.c_cflag &= ~UInt(CRTSCTS)
        options.c_iflag &= ~UInt(IXON | IXOFF | IXANY)
        
        // Non-blocking read
        options.c_cc.16 = 0 // VMIN
        options.c_cc.17 = 1 // VTIME (0.1 seconds)
        
        tcsetattr(fileDescriptor, TCSANOW, &options)
        
        print("[Serial] Opened \(port) at \(baudRate) baud")
        return true
    }
    
    /// Close serial connection
    func close() {
        if fileDescriptor >= 0 {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
            print("[Serial] Closed \(portPath)")
        }
    }
    
    /// Write data to serial port
    func write(_ data: String) -> Bool {
        guard fileDescriptor >= 0 else { return false }
        
        let bytes = Array(data.utf8)
        let written = Darwin.write(fileDescriptor, bytes, bytes.count)
        
        return written == bytes.count
    }
    
    /// Write line to serial port (adds newline)
    func writeLine(_ data: String) -> Bool {
        return write(data + "\n")
    }
    
    /// Read line from serial port (until newline)
    func readLine() -> String? {
        guard fileDescriptor >= 0 else { return nil }
        
        var buffer = [UInt8](repeating: 0, count: 1024)
        var result = ""
        
        while true {
            let bytesRead = Darwin.read(fileDescriptor, &buffer, buffer.count)
            
            if bytesRead > 0 {
                if let str = String(bytes: buffer[0..<bytesRead], encoding: .utf8) {
                    result += str
                    
                    // Check for complete line
                    if let range = result.range(of: "\n") {
                        return String(result[..<range.lowerBound])
                    }
                }
            } else {
                // No more data
                break
            }
        }
        
        return result.isEmpty ? nil : result
    }
    
    /// Read all available data
    func readAll() -> String? {
        guard fileDescriptor >= 0 else { return nil }
        
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = Darwin.read(fileDescriptor, &buffer, buffer.count)
        
        guard bytesRead > 0 else { return nil }
        
        return String(bytes: buffer[0..<bytesRead], encoding: .utf8)
    }
    
    /// Flush input buffer
    func flushInput() {
        guard fileDescriptor >= 0 else { return }
        tcflush(fileDescriptor, TCIFLUSH)
    }
    
    /// Check if port is open
    var isOpen: Bool {
        return fileDescriptor >= 0
    }
    
    deinit {
        close()
    }
}

// MARK: - Types

struct SerialPort: Identifiable {
    let name: String
    let path: String
    let type: SerialPortType
    
    var id: String { path }
}

enum SerialPortType {
    case arduino
    case esp32
    case unknown
    
    var description: String {
        switch self {
        case .arduino: return "Arduino"
        case .esp32: return "ESP32"
        case .unknown: return "Unknown"
        }
    }
}
