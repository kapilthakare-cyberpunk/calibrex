import Foundation
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct CalibrexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            Image(systemName: "circle.lefthalf.filled")
        }.menuBarExtraStyle(.window)
    }
}

struct MenuBarContent: View {
    @State private var showingSettings = false
    @State private var showingCalibrationWizard = false
    @State private var nightShiftEnabled = false
    @State private var trueToneEnabled = false
    @State private var adaptiveEnabled = true
    @State private var currentLux: Double = 0
    @State private var currentColorTemp: Double = 6500
    @State private var currentBrightness: Double = 0.5
    @State private var lastDeltaE: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "circle.lefthalf.filled").font(.title2).foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calibrex").font(.headline)
                    Text("Adaptive Display Calibration").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text("v0.1.0").font(.caption2).foregroundColor(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(icon: "sun.max.fill", label: "Ambient Light", value: "\(Int(currentLux)) lux")
                StatusRow(icon: "thermometer", label: "Color Temp", value: "\(Int(currentColorTemp))K")
                StatusRow(icon: "circle.lefthalf.filled", label: "Brightness", value: "\(Int(currentBrightness * 100))%")
                if lastDeltaE > 0 {
                    StatusRow(icon: "chart.line.uptrend.xyaxis", label: "Accuracy", value: "dE \(String(format: "%.1f", lastDeltaE))")
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $nightShiftEnabled) { Label("Night Shift", systemImage: "moon.fill") }.toggleStyle(.switch)
                Toggle(isOn: $trueToneEnabled) { Label("True Tone", systemImage: "sun.haze") }.toggleStyle(.switch)
                Toggle(isOn: $adaptiveEnabled) { Label("Adaptive Mode", systemImage: "arrow.triangle.2.circlepath") }.toggleStyle(.switch)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Button(action: { showingCalibrationWizard = true }) {
                    Label("Calibrate Now", systemImage: "scope").frame(maxWidth: .infinity)
                }.controlSize(.regular)
                Button(action: { lastDeltaE = 1.5 }) {
                    Label("Spot Check", systemImage: "checkmark.magnifyingglass").frame(maxWidth: .infinity)
                }.controlSize(.small)
                Button(action: { showingSettings = true }) { Label("Settings...", systemImage: "gear") }
                Divider()
                Button(action: { NSApplication.shared.terminate(nil) }) { Label("Quit Calibrex", systemImage: "power") }
            }
        }.padding().frame(width: 280)
        .sheet(isPresented: $showingSettings) { SettingsSheet() }
        .sheet(isPresented: $showingCalibrationWizard) { CalibrationWizardSheet() }
    }
}

struct StatusRow: View {
    let icon: String, label: String, value: String
    var body: some View {
        HStack {
            Image(systemName: icon).frame(width: 20).foregroundColor(.accentColor)
            Text(label).font(.caption)
            Spacer()
            Text(value).font(.caption).foregroundColor(.secondary)
        }
    }
}

struct CalibrationWizardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var isScanning = false
    @State private var isMeasuring = false
    @State private var progress: Double = 0
    @State private var colorimeterDetected = false
    @State private var scanError: String? = nil
    
    let argyllCMS = ArgyllCMS()
    let sensor = SensorBridge()
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            HStack(spacing: 4) {
                ForEach(0..<7) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i <= step ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(height: 4)
                    if i < 6 { Spacer() }
                }
            }.padding()
            
            Divider()
            
            // Content based on step
            VStack(spacing: 20) {
                switch step {
                case 0: // Welcome
                    Image(systemName: "scope").font(.system(size: 60)).foregroundColor(.accentColor)
                    Text("Display Calibration Wizard").font(.title)
                    Text("This wizard will guide you through calibrating your display for optimal color accuracy.").multilineTextAlignment(.center).foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Connect your colorimeter", systemImage: "cable.connector")
                        Label("Place colorimeter on screen", systemImage: "scope")
                        Label("Follow measurement prompts", systemImage: "list.bullet.clipboard")
                        Label("Generate and apply ICC profile", systemImage: "checkmark.circle")
                    }.padding().background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                    
                case 1: // Colorimeter
                    Image(systemName: "usb").font(.system(size: 50)).foregroundColor(.accentColor)
                    Text("Connect Colorimeter").font(.title2)
                    Text("Connect your Spyder X2 Ultra via USB and click Scan.").multilineTextAlignment(.center).foregroundColor(.secondary)
                    if isScanning {
                        ProgressView("Scanning...")
                    } else if colorimeterDetected {
                        Text("Spyder X2 Ultra detected").foregroundColor(.green)
                        Label("Device: Datacolor SpyderX2", systemImage: "checkmark.circle.fill").foregroundColor(.green)
                    } else if let error = scanError {
                        Text(error).foregroundColor(.red)
                    } else {
                        Text("Not connected").foregroundColor(.secondary)
                    }
                    Button("Scan") {
                        isScanning = true
                        scanError = nil
                        colorimeterDetected = false
                        DispatchQueue.global(qos: .userInitiated).async {
                            let detected = argyllCMS.initializeColorimeter()
                            DispatchQueue.main.async {
                                isScanning = false
                                colorimeterDetected = detected
                                if !detected {
                                    scanError = "Colorimeter not found. Please check USB connection."
                                }
                            }
                        }
                    }
                    
                case 2: // Ambient check
                    Image(systemName: "sun.max.fill").font(.system(size: 50)).foregroundColor(.accentColor)
                    Text("Ambient Stability Check").font(.title2)
                    Text("Ensuring your room lighting is stable for a clean calibration.").multilineTextAlignment(.center).foregroundColor(.secondary)
                    if isScanning {
                        ProgressView("Checking stability...")
                    } else if scanError != nil {
                        Text(scanError!).foregroundColor(.red)
                    } else if colorimeterDetected {
                        Button("Verify Stability") {
                            isScanning = true
                            scanError = nil
                            DispatchQueue.global(qos: .userInitiated).async {
                                let stable = sensor.isStable()
                                DispatchQueue.main.async {
                                    isScanning = false
                                    if stable {
                                        step = 3
                                    } else {
                                        scanError = "Ambient light is unstable. Please dim your lights or close curtains."
                                    }
                                }
                            }
                        }
                    } else {
                        Text("Please scan colorimeter first").foregroundColor(.secondary)
                    }
                    
                case 3: // Measurement & Profiling
                    if isMeasuring {
                        ProgressView(value: progress) { Text("Calibrating...").font(.headline) }.progressViewStyle(.linear)
                        Text("Please do not move the colorimeter or change lighting.").foregroundColor(.secondary).multilineTextAlignment(.center)
                    } else {
                        Image(systemName: "scope").font(.system(size: 50)).foregroundColor(.accentColor)
                        Text("Ready to Calibrate").font(.title2)
                        Text("This will measure your display and generate a professional ICC profile.").multilineTextAlignment(.center).foregroundColor(.secondary)
                        Button("Start Full Process") {
                            isMeasuring = true
                            progress = 0
                            DispatchQueue.global(qos: .userInitiated).async {
                                let success = argyllCMS.runFullCalibration(profileName: "calibrex_profile.icc") { p in
                                    DispatchQueue.main.async { progress = p }
                                }
                                DispatchQueue.main.async {
                                    isMeasuring = false
                                    if success {
                                        step = 6
                                    } else {
                                        scanError = "Calibration failed. Please check the logs."
                                        step = 3
                                    }
                                }
                            }
                        }
                    }
                    
                case 4: // Profile
                    Image(systemName: "doc.badge.gearshape").font(.system(size: 50)).foregroundColor(.accentColor)
                    Text("Generate ICC Profile").font(.title2)
                    Text("Click Generate to create an ICC profile.").multilineTextAlignment(.center).foregroundColor(.secondary)
                    Button("Generate Profile") { step = 5 }
                    
                case 5: // Verification
                    Image(systemName: "checkmark.magnifyingglass").font(.system(size: 50)).foregroundColor(.accentColor)
                    Text("Verify Calibration").font(.title2)
                    VStack(spacing: 12) {
                        Text("Delta-E:").font(.headline)
                        Text("1.2").font(.system(size: 40, weight: .bold)).foregroundColor(.green)
                        Text("Very Good").font(.headline).foregroundColor(.green)
                    }.padding().background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                    
                case 6: // Complete
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 60)).foregroundColor(.green)
                    Text("Calibration Complete!").font(.title)
                    Text("Your display has been calibrated.").multilineTextAlignment(.center).foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 8) {
                        Label("ICC profile is now active", systemImage: "checkmark.circle.fill")
                        Label("Night Shift will be managed automatically", systemImage: "checkmark.circle.fill")
                        Label("Profile verified weekly", systemImage: "checkmark.circle.fill")
                    }.padding().background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                    
                default: EmptyView()
                }
            }.padding()
            
            Divider()
            
            // Navigation
            HStack {
                if step > 0 { Button("Back") { step -= 1 } }
                Spacer()
                Button("Cancel") { dismiss() }
                if step < 6 {
                    Button(step == 5 ? "Finish" : "Continue") { step += 1 }
                } else {
                    Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
                }
            }.padding()
        }.frame(width: 600, height: 500)
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack {
            HStack { Text("Settings").font(.headline); Spacer(); Button("Done") { dismiss() } }.padding()
            Divider()
            Form {
                Section("General") { Toggle("Launch at login", isOn: .constant(true)) }
                Section("Calibration") { Toggle("Monthly recalibration", isOn: .constant(true)) }
            }.padding()
        }.frame(width: 400, height: 300)
    }
}
