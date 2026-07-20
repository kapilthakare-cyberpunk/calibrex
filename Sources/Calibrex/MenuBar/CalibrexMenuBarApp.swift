import SwiftUI

/// Menu bar view for Calibrex
struct MenuBarView: View {
    
    @StateObject private var viewModel = MenuBarViewModel()
    @State private var showingSettings = false
    @State private var showingCalibrationWizard = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            Divider()
            statusSection
            Divider()
            controlsSection
            Divider()
            actionsSection
        }
        .padding()
        .frame(width: 280)
        .onAppear { viewModel.refresh() }
        .sheet(isPresented: $showingCalibrationWizard) { CalibrationWizardView() }
    }
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "circle.lefthalf.filled")
                .font(.title2)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Calibrex").font(.headline)
                Text("Adaptive Display Calibration").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text("v0.1.0").font(.caption2).foregroundColor(.secondary)
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            StatusRow(icon: "sun.max.fill", label: "Ambient Light", value: "\(Int(viewModel.currentLux)) lux")
            StatusRow(icon: "thermometer", label: "Color Temp", value: "\(Int(viewModel.currentColorTemp))K")
            StatusRow(icon: "circle.lefthalf.filled", label: "Brightness", value: "\(Int(viewModel.currentBrightness * 100))%")
            if let profile = viewModel.currentProfile {
                StatusRow(icon: "checkmark.circle.fill", label: "Profile", value: profile)
            }
            if viewModel.lastDeltaE > 0 {
                StatusRow(icon: "chart.line.uptrend.xyaxis", label: "Accuracy", value: "dE \(String(format: "%.1f", viewModel.lastDeltaE))")
            }
        }
    }
    
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $viewModel.nightShiftEnabled) { Label("Night Shift", systemImage: "moon.fill") }
                .toggleStyle(.switch)
                .onChange(of: viewModel.nightShiftEnabled) { viewModel.setNightShift($0) }
            Toggle(isOn: $viewModel.trueToneEnabled) { Label("True Tone", systemImage: "sun.haze") }
                .toggleStyle(.switch)
                .onChange(of: viewModel.trueToneEnabled) { viewModel.setTrueTone($0) }
            Toggle(isOn: $viewModel.adaptiveEnabled) { Label("Adaptive Mode", systemImage: "arrow.triangle.2.circlepath") }
                .toggleStyle(.switch)
                .onChange(of: viewModel.adaptiveEnabled) { viewModel.setAdaptive($0) }
        }
    }
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showingCalibrationWizard = true }) {
                Label("Calibrate Now", systemImage: "scope").frame(maxWidth: .infinity)
            }.controlSize(.regular)
            Button(action: { viewModel.spotCheck() }) {
                Label("Spot Check", systemImage: "checkmark.magnifyingglass").frame(maxWidth: .infinity)
            }.controlSize(.small)
            Button(action: { showingSettings = true }) { Label("Settings...", systemImage: "gear") }
            Divider()
            Button(action: { NSApplication.shared.terminate(nil) }) { Label("Quit Calibrex", systemImage: "power") }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }
}

struct StatusRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon).frame(width: 20).foregroundColor(.accentColor)
            Text(label).font(.caption)
            Spacer()
            Text(value).font(.caption).foregroundColor(.secondary)
        }
    }
}
