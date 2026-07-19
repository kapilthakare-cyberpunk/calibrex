# Calibrex Sensor Bridge Firmware

Arduino/ESP32 firmware that bridges TSL2591 and BH1750 ambient light sensors to the Calibrex macOS daemon via USB serial.

## Supported Sensors

| Sensor | Type | Interface | Precision |
|--------|------|-----------|-----------|
| **TSL2591** | High-precision luminosity | I2C | 188 μlux - 88,000 lux |
| **BH1750** | Ambient light | I2C | 1 lux - 65535 lux |

## Wiring

### TSL2591 (I2C)

| TSL2591 Pin | Arduino Uno | ESP32 |
|-------------|-------------|-------|
| VIN | 3.3V | 3.3V |
| GND | GND | GND |
| SCL | A5 | GPIO22 |
| SDA | A4 | GPIO21 |

### BH1750 (I2C)

| BH1750 Pin | Arduino Uno | ESP32 |
|------------|-------------|-------|
| VIN | 3.3V/5V | 3.3V |
| GND | GND | GND |
| SCL | A5 | GPIO22 |
| SDA | A4 | GPIO21 |
| ADDR | GND (0x23) | GND (0x23) |

## Arduino IDE Setup

1. Install Arduino IDE
2. Go to **Sketch > Include Library > Manage Libraries**
3. Search and install:
   - `Adafruit TSL2591`
   - `BH1750` by Christopher Laws
4. Select your board and port
5. Upload `calibrex_sensor.ino`

## PlatformIO Setup (ESP32)

```ini
; platformio.ini
[env:esp32]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
lib_deps = 
    adafruit/Adafruit TSL2591 Library
    claws/BH1750
```

## Serial Protocol

### Commands

| Command | Response | Description |
|---------|----------|-------------|
| `IDENTIFY` | `TSL2591` or `BH1750` | Identify connected sensor |
| `READ` | `VISIBLE:12345\|IR:67890\|LUX:123.45` | Read TSL2591 data |
| `READ` | `LUX:1234.56` | Read BH1750 data |
| `GAIN:0` | `OK` | Set TSL2591 gain (0-3) |
| `AUTOGAIN:ON` | `OK` | Enable TSL2591 auto-gain |
| `TIME:100` | `OK` | Set TSL2591 integration time (100-600ms) |
| `MODE:1` | `OK` | Set BH1750 measurement mode (1-6) |
| `MTIME:120` | `OK` | Set BH1750 measurement time (140-1269ms) |
| `RESET` | `OK` | Reset BH1750 sensor |
| `POWER:ON` | `OK` | Power on BH1750 |

### Baud Rate

Default: **115200**

### Test with Serial Monitor

1. Open Arduino IDE Serial Monitor
2. Set baud rate to 115200
3. Type `IDENTIFY` and press Enter
4. Should respond with `TSL2591` or `BH1750`
5. Type `READ` to get sensor data

## Auto-Detection

The firmware auto-detects which sensor is connected:
1. First tries TSL2591 (I2C address 0x29)
2. If not found, tries BH1750 (I2C address 0x23)
3. Reports `READY:TSL2591` or `READY:BH1750` on boot

## Error Handling

| Error | Meaning |
|-------|---------|
| `ERROR:NO_SENSOR` | No sensor detected on I2C |
| `ERROR:UNKNOWN_COMMAND` | Invalid command received |
| `ERROR:WRONG_SENSOR` | Command not supported by connected sensor |
| `ERROR:INVALID_GAIN` | Gain value out of range (0-3) |
| `ERROR:INVALID_MODE` | Mode value out of range (1-6) |
| `ERROR:INVALID_TIME` | Time value out of range |

## Troubleshooting

### No sensor detected
- Check wiring (SDA, SCL, VIN, GND)
- Verify I2C address with I2C scanner sketch
- Ensure sensor is powered (3.3V for TSL2591, 3.3V/5V for BH1750)

### Garbled serial output
- Verify baud rate is 115200
- Check for USB driver issues
- Try different USB cable (data vs charge only)

### Unstable readings
- Add 4.7kΩ pull-up resistors on SDA and SCL lines
- Keep sensor wires short (< 30cm)
- Shield I2C wires from electrical noise
