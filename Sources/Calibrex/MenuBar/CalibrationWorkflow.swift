import Foundation
import Combine
import SwiftUI

/// Workflow manager for calibration wizard
@MainActor
class CalibrationWorkflow: ObservableObject {
    
    // MARK: - Current State
    
    @Published var currentStep: CalibrationStep = .welcome
    @Published var canProceed: Bool = true
    
    // MARK: - Colorimeter
    
    @Published var colorimeters: [ColorimeterDevice] = []
    @Published var selectedColorimeter: ColorimeterDevice? = nil
    @Published var isScanning: Bool = false
    
    // MARK: - Display
    
    @Published var currentDisplay: DisplayInfo? = nil
    
    // MARK: - Measurement
    
    @Published var measurementState: MeasurementState = .ready
    @Published var measurementProgress: Double = 0
    
    // MARK: - Profile
    
    @Published var isGeneratingProfile: Bool = false
    @Published var profileGenerated: Bool = false
    @Published var profilePath: String? = nil
    
    // MARK: - Verification
    
    @Published var isVerifying: Bool = false
    @Published var verificationDeltaE: Double? = nil
    
    // MARK: - Dependencies
    
    private let argyll = ArgyllCMS()
    private let profileManager = ProfileManager()
    
    private var targetsDir: String?
    
    // MARK: - Types
    
    struct DisplayInfo {
        let name: String
        let resolution: String
        let serialNumber: String?
    }
    
    enum MeasurementState {
        case ready
        case measuring
        case complete
    }
    
    // MARK: - Workflow Control
    
    func start() {
        currentStep = .welcome
        canProceed = true
    }
    
    func cancel() {
        measurementState = .ready
        measurementProgress = 0
    }
    
    func nextStep() {
        guard let nextIndex = CalibrationStep.allCases.firstIndex(of: currentStep)?.advanced(by: 1),
              nextIndex < CalibrationStep.allCases.count else {
            return
        }
        
        currentStep = CalibrationStep.allCases[nextIndex]
        updateCanProceed()
    }
    
    func previousStep() {
        guard let prevIndex = CalibrationStep.allCases.firstIndex(of: currentStep)?.advanced(by: -1),
              prevIndex >= 0 else {
            return
        }
        
        currentStep = CalibrationStep.allCases[prevIndex]
        updateCanProceed()
    }
    
    private func updateCanProceed() {
        switch currentStep {
        case .welcome:
            canProceed = true
        case .colorimeter:
            canProceed = selectedColorimeter != nil
        case .display:
            canProceed = true // Auto-detect display
        case .measurement:
            canProceed = measurementState == .complete
        case .profile:
            canProceed = profileGenerated
        case .verification:
            canProceed = verificationDeltaE != nil
        case .complete:
            canProceed = true
        }
    }
    
    // MARK: - Colorimeter Scanning
    
    func scanColorimeters() {
        isScanning = true
        
        Task.detached {
            let devices = await self.argyll.detectColorimeters()
            
            await MainActor.run {
                self.colorimeters = devices
                self.isScanning = false
                
                // Auto-select if only one device
                if devices.count == 1 {
                    self.selectedColorimeter = devices.first
                }
            }
        }
    }
    
    // MARK: - Display Detection
    
    func detectDisplay() {
        // Get current display info from system
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPDisplaysDataType"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try? process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // Parse display info
        var name = "Unknown Display"
        var resolution = "Unknown"
        
        for line in output.components(separatedBy: .newlines) {
            if line.contains("Display Type:") || line.contains("Resolution:") {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    if line.contains("Display Type:") {
                        name = value
                    } else if line.contains("Resolution:") {
                        resolution = value
                    }
                }
            }
        }
        
        currentDisplay = DisplayInfo(
            name: name,
            resolution: resolution,
            serialNumber: nil
        )
    }
    
    // MARK: - Measurement
    
    func startMeasurement() {
        guard let device = selectedColorimeter else { return }
        
        measurementState = .measuring
        measurementProgress = 0
        
        Task.detached {
            // Generate targets
            guard let targets = await self.argyll.generateTargets() else {
                await MainActor.run {
                    self.measurementState = .ready
                }
                return
            }
            
            await MainActor.run {
                self.targetsDir = targets
            }
            
            // Run measurement
            let success = await self.argyll.calibrateDisplay(
                device: device,
                targetsDir: targets
            ) { current, total in
                Task { @MainActor in
                    self.measurementProgress = Double(current) / Double(total)
                }
            }
            
            await MainActor.run {
                if success {
                    self.measurementState = .complete
                    self.updateCanProceed()
                } else {
                    self.measurementState = .ready
                }
            }
        }
    }
    
    // MARK: - Profile Generation
    
    func generateProfile() {
        guard let targets = targetsDir else { return }
        
        isGeneratingProfile = true
        let profileName = "calibrex_\(formatDate(Date()))"
        
        Task.detached { [profileName] in
            // Generate ICC profile
            
            guard let path = await self.argyll.generateProfile(
                from: targets,
                quality: .high,
                outputName: profileName
            ) else {
                await MainActor.run {
                    self.isGeneratingProfile = false
                }
                return
            }
            
            // Apply profile
            let applied = await self.argyll.applyProfile(path)
            
            await MainActor.run {
                self.isGeneratingProfile = false
                self.profileGenerated = applied
                self.profilePath = path
                self.updateCanProceed()
            }
        }
    }
    
    // MARK: - Verification
    
    func verifyCalibration() {
        guard let device = selectedColorimeter,
              let profile = profilePath else { return }
        
        isVerifying = true
        
        Task.detached {
            let deltaE = await self.argyll.verifyProfile(
                device: device,
                profilePath: profile
            )
            
            await MainActor.run {
                self.isVerifying = false
                self.verificationDeltaE = deltaE ?? 0
                self.updateCanProceed()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
}

// MARK: - Calibration Step

enum CalibrationStep: CaseIterable {
    case welcome
    case colorimeter
    case display
    case measurement
    case profile
    case verification
    case complete
    
    func color(for current: CalibrationStep) -> Color {
        let cases = CalibrationStep.allCases
        guard let currentIndex = cases.firstIndex(of: current),
              let selfIndex = cases.firstIndex(of: self) else {
            return .gray
        }
        
        if selfIndex < currentIndex {
            return .green
        } else if selfIndex == currentIndex {
            return .accentColor
        } else {
            return .gray.opacity(0.3)
        }
    }
}
