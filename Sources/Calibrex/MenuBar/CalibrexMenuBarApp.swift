import SwiftUI

/// Menu bar app for Calibrex
/// Shows status and provides quick controls
@main
struct CalibrexMenuBarApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image("MenuBarIcon")
                .resizable()
                .frame(width: 18, height: 18)
        }
        .menuBarExtraStyle(.window)
    }
}

/// NSApplication delegate for menu bar behavior
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - menu bar only app
        NSApp.setActivationPolicy(.accessory)
    }
}

/// Menu bar popup view
struct MenuBarView: View {
    
    @StateObject private var viewModel = MenuBarViewModel()
    @State private var showingSettings = false
    @State private var showingCalibrationWizard = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerSection
            
            Divider()
            
            // Status
            statusSection
            
            Divider()
            
            // Quick controls
            controlsSection
            
            Divider()
            
            // Actions
            actionsSection
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            viewModel.refresh()
        }
        .sheet(isPresented: $showingCalibrationWizard) {
            CalibrationWizardView()
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "circle.lefthalf.filled")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Calibrex")
                    .font(.headline)
                Text("Adaptive Display Calibration")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("v0.1.0")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            StatusRow(
                icon: "sun.max.fill",
                label: "Ambient Light",
                value: "\(Int(viewModel.currentLux)) lux"
            )
            
            StatusRow(
                icon: "thermometer",
                label: "Color Temp",
                value: "\(Int(viewModel.currentColorTemp))K"
            )
            
            StatusRow(
                icon: "circle.lefthalf.filled",
                label: "Brightness",
                value: "\(Int(viewModel.currentBrightness * 100))%"
            )
            
            if let profile = viewModel.currentProfile {
                StatusRow(
                    icon: "checkmark.circle.fill",
                    label: "Profile",
                    value: profile
                )
            }
            
            if viewModel.lastDeltaE > 0 {
                StatusRow(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Accuracy",
                    value: "dE \(String(format: "%.1f", viewModel.lastDeltaE))"
                )
            }
        }
    }
    
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Night Shift toggle
            Toggle(isOn: $viewModel.nightShiftEnabled) {
                Label("Night Shift", systemImage: "moon.fill")
            }
            .toggleStyle(.switch)
            .onChange(of: viewModel.nightShiftEnabled) { _, newValue in
                viewModel.setNightShift(newValue)
            }
            
            // True Tone toggle
            Toggle(isOn: $viewModel.trueToneEnabled) {
                Label("True Tone", systemImage: "sun.haze")
            }
            .toggleStyle(.switch)
            .onChange(of: viewModel.trueToneEnabled) { _, newValue in
                viewModel.setTrueTone(newValue)
            }
            
            // Adaptive mode toggle
            Toggle(isOn: $viewModel.adaptiveEnabled) {
                Label("Adaptive Mode", systemImage: "arrow.triangle.2.circlepath")
            }
            .toggleStyle(.switch)
            .onChange(of: viewModel.adaptiveEnabled) { _, newValue in
                viewModel.setAdaptive(newValue)
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Calibrate button
            Button(action: {
                showingCalibrationWizard = true
            }) {
                Label("Calibrate Now", systemImage: "scope")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.regular)
            
            // Spot check button
            Button(action: {
                viewModel.spotCheck()
            }) {
                Label("Spot Check", systemImage: "checkmark.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
            
            // Settings button
            Button(action: {
                showingSettings = true
            }) {
                Label("Settings...", systemImage: "gear")
            }
            
            Divider()
            
            // Quit button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit Calibrex", systemImage: "power")
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

/// Status row component
struct StatusRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.accentColor)
            
            Text(label)
                .font(.caption)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
}
