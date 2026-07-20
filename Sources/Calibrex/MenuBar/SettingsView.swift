import SwiftUI

/// Settings window for Calibrex
struct SettingsView: View {
    
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        TabView {
            GeneralSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            CalibrationSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Calibration", systemImage: "scope")
                }
            
            AppRulesTab(viewModel: viewModel)
                .tabItem {
                    Label("App Rules", systemImage: "app.badge")
                }
            
            AdvancedSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            viewModel.load()
        }
        .onDisappear {
            viewModel.save()
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $viewModel.launchAtLogin)
                    .onChange(of: viewModel.launchAtLogin) { value in
                        viewModel.toggleLaunchAgent(enabled: value)
                    }
                
                HStack {
                    Text("Launch agent status")
                    Spacer()
                    Text(viewModel.launchAgentStatus)
                        .foregroundColor(viewModel.launchAgentLoaded ? .green : .secondary)
                }
                
                Button("Open Logs") {
                    viewModel.openLaunchAgentLogs()
                }
                .controlSize(.small)
            }
            
            Section("Sensors") {
                Picker("Ambient light source", selection: $viewModel.ambientLightSource) {
                    Text("Auto-detect").tag("auto")
                    Text("MacBook built-in sensor").tag("iokit")
                    Text("USB sensor (TSL2591)").tag("usb_tsl2591")
                    Text("USB sensor (BH1750)").tag("usb_bh1750")
                    Text("Time-based estimate").tag("estimate")
                }
                
                Picker("Temperature source", selection: $viewModel.temperatureSource) {
                    Text("Auto-detect").tag("auto")
                    Text("SMC sensors").tag("smc")
                    Text("USB sensor (DHT22)").tag("usb_dht22")
                    Text("USB sensor (DS18B20)").tag("usb_ds18b20")
                    Text("None").tag("none")
                }
            }
        }
        .padding()
    }
}

// MARK: - Calibration Settings

struct CalibrationSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section("Recalibration") {
                Toggle("Enable monthly recalibration", isOn: $viewModel.monthlyRecalibration)
                
                HStack {
                    Text("Spot-check interval")
                    Spacer()
                    Picker("", selection: $viewModel.spotCheckDays) {
                        Text("3 days").tag(3)
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                HStack {
                    Text("Delta-E threshold")
                    Spacer()
                    TextField("", value: $viewModel.deltaEThreshold, format: .number)
                        .frame(width: 60)
                    Text("dE")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Profile Quality") {
                Picker("Default quality", selection: $viewModel.profileQuality) {
                    Text("Low (fast)").tag("low")
                    Text("Medium").tag("medium")
                    Text("High (accurate)").tag("high")
                    Text("Proof (best)").tag("proof")
                }
                
                Toggle("Auto-clean old profiles", isOn: $viewModel.autoCleanProfiles)
                
                if viewModel.autoCleanProfiles {
                    HStack {
                        Text("Keep last")
                        TextField("", value: $viewModel.maxProfiles, format: .number)
                            .frame(width: 40)
                        Text("profiles")
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - App Rules

struct AppRulesTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedBundleID: String? = nil
    
    var body: some View {
        HSplitView {
            // App list
            List(viewModel.appRules.keys.sorted(), id: \.self, selection: $selectedBundleID) { bundleID in
                Text(bundleID)
                    .font(.caption)
                    .padding(.vertical, 2)
            }
            .frame(minWidth: 200)
            
            // Rule editor
            if let bundleID = selectedBundleID {
                Form {
                    Section("Rules for \(bundleID)") {
                        Picker("Night Shift", selection: nightShiftBinding(for: bundleID)) {
                            Text("Default").tag("default")
                            Text("On").tag("on")
                            Text("Off").tag("off")
                        }
                        
                        Picker("True Tone", selection: trueToneBinding(for: bundleID)) {
                            Text("Default").tag("default")
                            Text("On").tag("on")
                            Text("Off").tag("off")
                        }
                        
                        TextField("Profile override", text: profileOverrideBinding(for: bundleID))
                    }
                    
                    Section {
                        Button("Remove Rule", role: .destructive) {
                            viewModel.removeAppRule(for: bundleID)
                            selectedBundleID = nil
                        }
                    }
                }
                .padding()
                .frame(minWidth: 300)
            } else {
                Text("Select an app to edit rules")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func nightShiftBinding(for bundleID: String) -> Binding<String> {
        Binding(
            get: { viewModel.appRules[bundleID]?.nightShift ?? "default" },
            set: { viewModel.updateAppRule(for: bundleID, nightShift: $0) }
        )
    }
    
    private func trueToneBinding(for bundleID: String) -> Binding<String> {
        Binding(
            get: { viewModel.appRules[bundleID]?.trueTone ?? "default" },
            set: { viewModel.updateAppRule(for: bundleID, trueTone: $0) }
        )
    }
    
    private func profileOverrideBinding(for bundleID: String) -> Binding<String> {
        Binding(
            get: { viewModel.appRules[bundleID]?.profileOverride ?? "" },
            set: { viewModel.updateAppRule(for: bundleID, profileOverride: $0) }
        )
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section("Poll Intervals") {
                HStack {
                    Text("Ambient light")
                    Spacer()
                    TextField("", value: $viewModel.pollIntervalLux, format: .number)
                        .frame(width: 60)
                    Text("seconds")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Color temperature")
                    Spacer()
                    TextField("", value: $viewModel.pollIntervalColorTemp, format: .number)
                        .frame(width: 60)
                    Text("seconds")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Room temperature")
                    Spacer()
                    TextField("", value: $viewModel.pollIntervalTemp, format: .number)
                        .frame(width: 60)
                    Text("seconds")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Adaptation") {
                HStack {
                    Text("Transition duration")
                    Spacer()
                    TextField("", value: $viewModel.transitionDuration, format: .number)
                        .frame(width: 60)
                    Text("seconds")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Lux change threshold")
                    Spacer()
                    TextField("", value: $viewModel.luxThreshold, format: .number)
                        .frame(width: 60)
                    Text("%")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Color temp threshold")
                    Spacer()
                    TextField("", value: $viewModel.colorTempThreshold, format: .number)
                        .frame(width: 60)
                    Text("K")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("ArgyllCMS") {
                TextField("ArgyllCMS path", text: $viewModel.argyllPath)
                    .font(.caption)
            }
        }
        .padding()
    }
}

// MARK: - View Model

@MainActor
class SettingsViewModel: ObservableObject {
    
    // General
    @Published var launchAtLogin: Bool = true
    @Published var showMenuBarIcon: Bool = true
    @Published var startAdaptive: Bool = true
    @Published var ambientLightSource: String = "auto"
    @Published var temperatureSource: String = "auto"
    
    // Calibration
    @Published var monthlyRecalibration: Bool = true
    @Published var spotCheckDays: Int = 7
    @Published var deltaEThreshold: Double = 3.0
    @Published var profileQuality: String = "high"
    @Published var autoCleanProfiles: Bool = true
    @Published var maxProfiles: Int = 5
    
    // App rules
    @Published var appRules: [String: AppRuleEntry] = [:]
    
    // Advanced
    @Published var pollIntervalLux: Double = 60
    @Published var pollIntervalColorTemp: Double = 120
    @Published var pollIntervalTemp: Double = 300
    @Published var transitionDuration: Double = 2.0
    @Published var luxThreshold: Double = 15
    @Published var colorTempThreshold: Double = 200
    @Published var argyllPath: String = "/usr/local/bin"
    
    // Launch agent
    @Published var launchAgentStatus: String = "Not installed"
    @Published var launchAgentLoaded: Bool = false
    
    struct AppRuleEntry {
        var nightShift: String
        var trueTone: String
        var profileOverride: String
    }
    
    private let configManager = ConfigurationManager()
    private let launchAgentManager = LaunchAgentManager()
    
    func load() {
        let config = configManager.config
        
        // Launch agent status
        let status = launchAgentManager.getStatus()
        launchAgentStatus = status.description
        launchAgentLoaded = (status == .loaded)
        
        // General
        launchAtLogin = config.daemon.launchAtLogin
        showMenuBarIcon = config.daemon.showMenuBarIcon
        
        // Calibration
        monthlyRecalibration = config.recalibration.monthlyEnabled
        spotCheckDays = config.recalibration.spotCheckIntervalDays
        deltaEThreshold = config.recalibration.deltaEThreshold
        profileQuality = config.profiles.defaultQuality
        autoCleanProfiles = config.profiles.autoClean
        maxProfiles = config.profiles.maxProfiles
        
        // App rules
        appRules = config.perAppRules.mapValues { rule in
            AppRuleEntry(
                nightShift: rule.nightShift,
                trueTone: rule.trueTone,
                profileOverride: rule.profileOverride ?? ""
            )
        }
        
        // Advanced
        pollIntervalLux = config.daemon.pollIntervalLux
        pollIntervalColorTemp = config.daemon.pollIntervalColorTemp
        pollIntervalTemp = config.daemon.pollIntervalTemperature
        transitionDuration = config.daemon.transitionDuration
        luxThreshold = config.daemon.luxChangeThreshold * 100
        colorTempThreshold = config.daemon.colorTempChangeThreshold
    }
    
    func save() {
        configManager.updateDaemonSettings { settings in
            settings.launchAtLogin = launchAtLogin
            settings.showMenuBarIcon = showMenuBarIcon
            settings.pollIntervalLux = pollIntervalLux
            settings.pollIntervalColorTemp = pollIntervalColorTemp
            settings.pollIntervalTemperature = pollIntervalTemp
            settings.transitionDuration = transitionDuration
            settings.luxChangeThreshold = luxThreshold / 100
            settings.colorTempChangeThreshold = colorTempThreshold
        }
        
        configManager.updateRecalibrationSettings { settings in
            settings.monthlyEnabled = monthlyRecalibration
            settings.spotCheckIntervalDays = spotCheckDays
            settings.deltaEThreshold = deltaEThreshold
        }
        
        // Save app rules
        for (bundleID, entry) in appRules {
            configManager.setAppRule(for: bundleID, rule: ConfigurationManager.CalibrexConfig.AppRuleConfig(
                nightShift: entry.nightShift,
                trueTone: entry.trueTone,
                profileOverride: entry.profileOverride.isEmpty ? nil : entry.profileOverride
            ))
        }
    }
    
    func updateAppRule(for bundleID: String, nightShift: String? = nil, trueTone: String? = nil, profileOverride: String? = nil) {
        var entry = appRules[bundleID] ?? AppRuleEntry(nightShift: "default", trueTone: "default", profileOverride: "")
        
        if let ns = nightShift { entry.nightShift = ns }
        if let tt = trueTone { entry.trueTone = tt }
        if let po = profileOverride { entry.profileOverride = po }
        
        appRules[bundleID] = entry
    }
    
    func removeAppRule(for bundleID: String) {
        appRules.removeValue(forKey: bundleID)
        configManager.removeAppRule(for: bundleID)
    }
    
    // MARK: - Launch Agent
    
    func toggleLaunchAgent(enabled: Bool) {
        if enabled {
            let success = launchAgentManager.install()
            launchAgentStatus = success ? "Loaded and running" : "Failed to install"
            launchAgentLoaded = success
        } else {
            let success = launchAgentManager.uninstall()
            launchAgentStatus = success ? "Not installed" : "Failed to uninstall"
            launchAgentLoaded = false
        }
    }
    
    func openLaunchAgentLogs() {
        launchAgentManager.openLogs()
    }
}
