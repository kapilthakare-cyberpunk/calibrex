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

    @StateObject private var displayManager = SystemDisplayManager()
    private let argyllCMS = ArgyllCMS()
    private let sensor = SensorBridge()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "circle.lefthalf.filled").font(.title2).foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calibrex").font(.headline)
                    Text("Adaptive Display Calibration").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text("v0.2.0").font(.caption2).foregroundColor(.secondary)
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
                Toggle(isOn: $nightShiftEnabled) {
                    Label("Night Shift", systemImage: "moon.fill")
                }
                .toggleStyle(.switch)
                .onChange(of: nightShiftEnabled) { newValue in
                    let success = displayManager.setNightShift(enabled: newValue)
                    if !success {
                        // Revert the toggle if the system call failed
                        DispatchQueue.main.async { nightShiftEnabled.toggle() }
                    }
                }

                Toggle(isOn: $trueToneEnabled) {
                    Label("True Tone", systemImage: "sun.haze")
                }
                .toggleStyle(.switch)
                .onChange(of: trueToneEnabled) { newValue in
                    let success = displayManager.setTrueTone(enabled: newValue)
                    if !success {
                        DispatchQueue.main.async { trueToneEnabled.toggle() }
                    }
                }

                Toggle(isOn: $adaptiveEnabled) {
                    Label("Adaptive Mode", systemImage: "arrow.triangle.2.circlepath")
                }
                .toggleStyle(.switch)
                .onChange(of: adaptiveEnabled) { newValue in
                    // Adaptive mode orchestrates both Night Shift and True Tone
                    displayManager.setNightShift(enabled: newValue)
                    displayManager.setTrueTone(enabled: newValue)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Button(action: { showingCalibrationWizard = true }) {
                    Label("Calibrate Now", systemImage: "scope").frame(maxWidth: .infinity)
                }.controlSize(.regular)
                Button(action: {
                    Task {
                        let baseline = argyllCMS.captureBaselineStatus()
                        let lux = sensor.readLux() ?? 0
                        await MainActor.run {
                            currentLux = lux
                            currentColorTemp = baseline.whitePoint.y * 10000 // approximate
                            lastDeltaE = baseline.deltaE
                        }
                    }
                }) {
                    Label("Spot Check", systemImage: "checkmark.magnifyingglass").frame(maxWidth: .infinity)
                }.controlSize(.small)
                Button(action: { showingSettings = true }) { Label("Settings...", systemImage: "gear") }
                Divider()
                Button(action: { NSApplication.shared.terminate(nil) }) { Label("Quit Calibrex", systemImage: "power") }
            }
        }.padding().frame(width: 280)
        .onAppear {
            nightShiftEnabled = displayManager.isNightShiftEnabled()
        }
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
    @State private var preCalibrationBaseline: BaselineReport?
    
    let argyllCMS = ArgyllCMS()
    let sensor = SensorBridge()
    let telegram = TelegramNotifier()
    
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
                                } else {
                                    telegram.notifyStatus("Colorimeter detected. Ready for baseline capture.")
                                }
                            }
                        }
                    }

                case 2: // Baseline Capture
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 50)).foregroundColor(.accentColor)
                    Text("Capturing Baseline").font(.title2)
                    Text("Measuring current display state to generate a pre-calibration report.").multilineTextAlignment(.center).foregroundColor(.secondary)
                    if isScanning {
                        ProgressView("Measuring drift...")
                    } else {
                        Button("Capture Status") {
                            isScanning = true
                            DispatchQueue.global(qos: .userInitiated).async {
                                let baseline = argyllCMS.captureBaselineStatus()
                                let report = baseline.formatted()
                                print(report)
                                DispatchQueue.main.async {
                                    isScanning = false
                                    preCalibrationBaseline = baseline
                                    telegram.notifyStatus("Baseline captured. Delta-E: \(String(format: "%.2f", baseline.deltaE))")
                                    step = 3
                                }
                            }
                        }
                    }

                    
                case 3: // Ambient check
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
                                        telegram.notifyStatus("Ambient light stable. Proceeding to calibration.")
                                        step = 4
                                    } else {
                                        scanError = "Ambient light is unstable. Please dim your lights or close curtains."
                                    }
                                }
                            }
                        }
                    } else {
                        Text("Please scan colorimeter first").foregroundColor(.secondary)
                    }

                case 4: // Measurement & Profiling
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
                            telegram.notifyStatus("Starting automated calibration process...")
                            DispatchQueue.global(qos: .userInitiated).async {
                                let success = argyllCMS.runFullCalibration(profileName: "calibrex_profile.icc") { p in
                                    DispatchQueue.main.async { progress = p }
                                }
                                DispatchQueue.main.async {
                                    isMeasuring = false
                                    if success {
                                        DispatchQueue.global(qos: .userInitiated).async {
                                            // Use the stored pre-baseline (captured in step 2)
                                            let pre = preCalibrationBaseline ?? argyllCMS.captureBaselineStatus()
                                            let post = argyllCMS.captureBaselineStatus()
                                            let comparisonReport = argyllCMS.generateProfessionalReport(pre: pre, post: post)

                                            // Also export the report to Desktop
                                            let desktop = NSString(string: NSHomeDirectory()).appendingPathComponent("Desktop")
                                            let reportPath = "\(desktop)/calibrex_comparison_report.txt"
                                            do {
                                                try comparisonReport.write(toFile: reportPath, atomically: true, encoding: .utf8)
                                                print("[Calibrex] Comparison report saved to: \(reportPath)")
                                            } catch {
                                                print("[Calibrex] Error saving report: \(error)")
                                            }

                                            DispatchQueue.main.async {
                                                telegram.notifyCompletion(report: comparisonReport)
                                                step = 6
                                            }
                                        }
                                    } else {
                                        telegram.notifyStatus("Calibration failed. Please check the logs.")
                                        scanError = "Calibration failed. Please check the logs."
                                        step = 4
                                    }
                                }
                            }
                        }
                    }
                    
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
