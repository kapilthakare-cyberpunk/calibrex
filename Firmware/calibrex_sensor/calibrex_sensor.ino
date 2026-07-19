/*
 * Calibrex Sensor Bridge Firmware
 * 
 * Bridges TSL2591 and BH1750 ambient light sensors to
 * the Calibrex macOS daemon via USB serial.
 * 
 * Protocol:
 *   IDENTIFY        -> "TSL2591" or "BH1750"
 *   READ            -> "VISIBLE:12345|IR:67890|LUX:123.45" (TSL2591)
 *                   -> "LUX:1234.56" (BH1750)
 *   GAIN:0-3        -> "OK" (TSL2591 only)
 *   AUTOGAIN:ON/OFF -> "OK" (TSL2591 only)
 *   TIME:100-600    -> "OK" (TSL2591 only)
 *   MODE:1-6        -> "OK" (BH1750 only)
 *   MTIME:140-1269  -> "OK" (BH1750 only)
 *   RESET           -> "OK" (BH1750 only)
 *   POWER:ON/OFF    -> "OK" (BH1750 only)
 * 
 * Baud Rate: 115200
 * 
 * Hardware:
 *   TSL2591: I2C (SDA, SCL)
 *   BH1750:  I2C (SDA, SCL)
 * 
 * Libraries:
 *   - Adafruit TSL2591 Library
 *   - BH1750 (claws/BH1750)
 *   - Wire (built-in)
 */

#include <Wire.h>
#include <Adafruit_TSL2591.h>
#include <BH1750.h>

// ============================================================
// Configuration
// ============================================================

#define SERIAL_BAUD       115200
#define BOOT_DELAY_MS     2000
#define AUTO_DETECT       true

// ============================================================
// Sensor Objects
// ============================================================

Adafruit_TSL2591 tsl = Adafruit_TSL2591(2591);
BH1750 bh;

// ============================================================
// State
// ============================================================

enum SensorType {
  SENSOR_NONE,
  SENSOR_TSL2591,
  SENSOR_BH1750
};

SensorType activeSensor = SENSOR_NONE;
bool autoGainEnabled = false;

// TSL2591 settings
tsl2591Gain_t currentGain = TSL2591_GAIN_HIGH;
int integrationTime = 100;

// BH1750 settings
BH1750Mode_t currentMode = BH1750::CONTINUOUS_HIGH_RES_MODE;
float measurementTime = 120.0;

// ============================================================
// Setup
// ============================================================

void setup() {
  Serial.begin(SERIAL_BAUD);
  delay(BOOT_DELAY_MS);
  Wire.begin();
  
  if (AUTO_DETECT) {
    activeSensor = detectSensor();
  } else {
    if (tsl.begin()) {
      activeSensor = SENSOR_TSL2591;
      configureTSL2591();
    }
  }
  
  if (activeSensor != SENSOR_NONE) {
    Serial.print("READY:");
    Serial.println(getSensorName());
  } else {
    Serial.println("ERROR:NO_SENSOR");
  }
}

// ============================================================
// Main Loop
// ============================================================

void loop() {
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    command.trim();
    command.toUpperCase();
    processCommand(command);
  }
  delay(10);
}

// ============================================================
// Sensor Detection
// ============================================================

SensorType detectSensor() {
  if (tsl.begin()) {
    configureTSL2591();
    return SENSOR_TSL2591;
  }
  
  if (bh.begin(BH1750::CONTINUOUS_HIGH_RES_MODE)) {
    return SENSOR_BH1750;
  }
  
  return SENSOR_NONE;
}

const char* getSensorName() {
  switch (activeSensor) {
    case SENSOR_TSL2591: return "TSL2591";
    case SENSOR_BH1750:  return "BH1750";
    default:             return "NONE";
  }
}

void configureTSL2591() {
  tsl.setGain(currentGain);
  tsl.setTiming(currentGain, integrationTime);
}

// ============================================================
// Command Processor
// ============================================================

void processCommand(const String& cmd) {
  if (cmd == "IDENTIFY") {
    handleIdentify();
  }
  else if (cmd == "READ") {
    handleRead();
  }
  else if (cmd.startsWith("GAIN:")) {
    handleSetGain(cmd.substring(5));
  }
  else if (cmd.startsWith("AUTOGAIN:")) {
    handleSetAutoGain(cmd.substring(9));
  }
  else if (cmd.startsWith("TIME:")) {
    handleSetIntegrationTime(cmd.substring(5));
  }
  else if (cmd.startsWith("MODE:")) {
    handleSetMode(cmd.substring(5));
  }
  else if (cmd.startsWith("MTIME:")) {
    handleSetMeasurementTime(cmd.substring(6));
  }
  else if (cmd == "RESET") {
    handleReset();
  }
  else if (cmd.startsWith("POWER:")) {
    handleSetPower(cmd.substring(6));
  }
  else {
    Serial.println("ERROR:UNKNOWN_COMMAND");
  }
}

// ============================================================
// Command Handlers
// ============================================================

void handleIdentify() {
  Serial.println(getSensorName());
}

void handleRead() {
  switch (activeSensor) {
    case SENSOR_TSL2591: readTSL2591(); break;
    case SENSOR_BH1750:  readBH1750();  break;
    default: Serial.println("ERROR:NO_SENSOR"); break;
  }
}

void handleSetGain(const String& value) {
  if (activeSensor != SENSOR_TSL2591) {
    Serial.println("ERROR:WRONG_SENSOR");
    return;
  }
  
  int gain = value.toInt();
  if (gain < 0 || gain > 3) {
    Serial.println("ERROR:INVALID_GAIN");
    return;
  }
  
  switch (gain) {
    case 0: currentGain = TSL2591_GAIN_LOW;  break;
    case 1: currentGain = TSL2591_GAIN_MED;  break;
    case 2: currentGain = TSL2591_GAIN_HIGH; break;
    case 3: currentGain = TSL2591_GAIN_MAX;  break;
  }
  
  tsl.setGain(currentGain);
  Serial.println("OK");
}

void handleSetAutoGain(const String& value) {
  if (activeSensor != SENSOR_TSL2591) {
    Serial.println("ERROR:WRONG_SENSOR");
    return;
  }
  autoGainEnabled = (value == "ON");
  Serial.println("OK");
}

void handleSetIntegrationTime(const String& value) {
  if (activeSensor != SENSOR_TSL2591) {
    Serial.println("ERROR:WRONG_SENSOR");
    return;
  }
  
  int time = value.toInt();
  if (time < 100 || time > 600) {
    Serial.println("ERROR:INVALID_TIME");
    return;
  }
  
  integrationTime = time;
  tsl.setTiming(currentGain, integrationTime);
  Serial.println("OK");
}

void handleSetMode(const String& value) {
  if (activeSensor != SENSOR_BH1750) {
    Serial.println("ERROR:WRONG_SENSOR");
    return;
  }
  
  int mode = value.toInt();
  if (mode < 1 || mode > 6) {
    Serial.println("ERROR:INVALID_MODE");
    return;
  }
  
  switch (mode) {
    case 1: currentMode = BH1750::CONTINUOUS_HIGH_RES_MODE;      break;
    case 2: currentMode = BH1750::CONTINUOUS_HIGH_RES_MODE_2;    break;
    case 3: currentMode = BH1750::CONTINUOUS_LOW_RES_MODE;       break;
    case 4: currentMode = BH1750::ONE_TIME_HIGH_RES_MODE;        break;
    case 5: currentMode = BH1750::ONE_TIME_HIGH_RES_MODE_2;      break;
    case 6: currentMode = BH1750::ONE_TIME_LOW_RES_MODE;         break;
  }
  
  bh.setMode(currentMode);
  Serial.println("OK");
}

void handleSetMeasurementTime(const String& value) {
  if (activeSensor != SENSOR_BH1750) {
    Serial.println("ERROR:WRONG_SENSOR");
    return;
  }
  
  float time = value.toFloat();
  if (time < 140.0 || time > 1269.0) {
    Serial.println("ERROR:INVALID_TIME");
    return;
  }
  
  measurementTime = time;
  bh.setMTreg((uint8_t)time);
  Serial.println("OK");
}

void handleReset() {
  if (activeSensor == SENSOR_BH1750) {
    bh.reset();
    bh.setMode(currentMode);
    Serial.println("OK");
  } else {
    Serial.println("ERROR:NOT_SUPPORTED");
  }
}

void handleSetPower(const String& value) {
  if (activeSensor != SENSOR_BH1750) {
    Serial.println("ERROR:WRONG_SENSOR");
    return;
  }
  
  if (value == "ON") {
    bh.powerOn();
    bh.setMode(currentMode);
    Serial.println("OK");
  } else if (value == "OFF") {
    bh.powerOff();
    Serial.println("OK");
  } else {
    Serial.println("ERROR:INVALID_VALUE");
  }
}

// ============================================================
// Sensor Reading
// ============================================================

void readTSL2591() {
  if (autoGainEnabled) {
    autoAdjustGain();
  }
  
  uint32_t lum = tsl.getFullLuminosity();
  uint16_t ir = lum >> 16;
  uint16_t visible = lum & 0xFFFF;
  float lux = tsl.calculateLux(visible, ir);
  
  Serial.print("VISIBLE:");
  Serial.print(visible);
  Serial.print("|IR:");
  Serial.print(ir);
  Serial.print("|LUX:");
  Serial.println(lux, 2);
}

void readBH1750() {
  float lux = bh.readLightLevel();
  Serial.print("LUX:");
  Serial.println(lux, 2);
}

// ============================================================
// Auto-Gain for TSL2591
// ============================================================

void autoAdjustGain() {
  uint32_t lum = tsl.getFullLuminosity();
  uint16_t ir = lum >> 16;
  uint16_t visible = lum & 0xFFFF;
  
  if (visible > 40000 || ir > 40000) {
    if (currentGain == TSL2591_GAIN_MAX) {
      currentGain = TSL2591_GAIN_HIGH;
    } else if (currentGain == TSL2591_GAIN_HIGH) {
      currentGain = TSL2591_GAIN_MED;
    } else if (currentGain == TSL2591_GAIN_MED) {
      currentGain = TSL2591_GAIN_LOW;
    }
    tsl.setGain(currentGain);
    delay(100);
  }
  else if (visible < 100 && ir < 100) {
    if (currentGain == TSL2591_GAIN_LOW) {
      currentGain = TSL2591_GAIN_MED;
    } else if (currentGain == TSL2591_GAIN_MED) {
      currentGain = TSL2591_GAIN_HIGH;
    } else if (currentGain == TSL2591_GAIN_HIGH) {
      currentGain = TSL2591_GAIN_MAX;
    }
    tsl.setGain(currentGain);
    delay(100);
  }
}
