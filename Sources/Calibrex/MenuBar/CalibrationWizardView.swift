import SwiftUI

/// Full calibration workflow wizard
struct CalibrationWizardView: View {
    
    @StateObject private var workflow = CalibrationWorkflow()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar
                .padding()
            
            Divider()
            
            // Step content
            currentStepView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Navigation buttons
            navigationBar
                .padding()
        }
        .frame(width: 600, height: 500)
        .onAppear {
            workflow.start()
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(CalibrationStep.allCases, id: \.self) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(step.color(for: workflow.currentStep))
                    .frame(height: 4)
                
                if step != CalibrationStep.allCases.last {
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Step Content
    
    @ViewBuilder
    private var currentStepView: some View {
        switch workflow.currentStep {
        case .welcome:
            WelcomeStep(workflow: workflow)
        case .colorimeter:
            ColorimeterStep(workflow: workflow)
        case .display:
            DisplayStep(workflow: workflow)
        case .measurement:
            MeasurementStep(workflow: workflow)
        case .profile:
            ProfileStep(workflow: workflow)
        case .verification:
            VerificationStep(workflow: workflow)
        case .complete:
            CompleteStep(workflow: workflow)
        }
    }
    
    // MARK: - Navigation Bar
    
    private var navigationBar: some View {
        HStack {
            // Back button
            if workflow.currentStep != .welcome {
                Button("Back") {
                    workflow.previousStep()
                }
                .controlSize(.regular)
            }
            
            Spacer()
            
            // Cancel button
            Button("Cancel") {
                workflow.cancel()
                dismiss()
            }
            .controlSize(.regular)
            
            // Next/Finish button
            if workflow.currentStep == .complete {
                Button("Done") {
                    dismiss()
                }
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            } else {
                Button(workflow.currentStep == .verification ? "Finish" : "Continue") {
                    workflow.nextStep()
                }
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
                .disabled(!workflow.canProceed)
            }
        }
    }
}

// MARK: - Steps

struct WelcomeStep: View {
    @ObservedObject var workflow: CalibrationWorkflow
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "scope")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Display Calibration Wizard")
                .font(.title)
            
            Text("This wizard will guide you through calibrating your display for optimal color accuracy.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Connect your colorimeter", systemImage: "cable.connector")
                Label("Place colorimeter on screen", systemImage: "scope")
                Label("Follow measurement prompts", systemImage: "list.bullet.clipboard")
                Label("Generate and apply ICC profile", systemImage: "checkmark.circle")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
        }
        .padding()
    }
}

struct ColorimeterStep: View {
    @ObservedObject var workflow: CalibrationWorkflow
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "usb")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            
            Text("Connect Colorimeter")
                .font(.title2)
            
            Text("Connect your colorimeter via USB and click Scan when ready.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            if workflow.isScanning {
                ProgressView("Scanning...")
            } else if let device = workflow.selectedColorimeter {
                Label(device.name, systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if workflow.colorimeters.isEmpty {
                Text("No colorimeters found")
                    .foregroundColor(.orange)
                
                Button("Scan Again") {
                    workflow.scanColorimeters()
                }
            } else {
                Picker("Select colorimeter", selection: $workflow.selectedColorimeter) {
                    Text("Select...").tag(nil as ColorimeterDevice?)
                    ForEach(workflow.colorimeters, id: \.id) { device in
                        Text("\(device.name) (\(device.type.description))").tag(device as ColorimeterDevice?)
                    }
                }
            }
            
            // Tips
            VStack(alignment: .leading, spacing: 4) {
                Label("Supported: Spyder 2/3/4/5, i1 Display Pro", systemImage: "info.circle")
                Label("Keep colorimeter lens clean", systemImage: "exclamationmark.triangle")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct DisplayStep: View {
    @ObservedObject var workflow: CalibrationWorkflow
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "display")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            
            Text("Display Selection")
                .font(.title2)
            
            Text("Calibrex will calibrate the current display. Ensure only one display is connected for best results.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            if let display = workflow.currentDisplay {
                VStack(spacing: 8) {
                    Label(display.name, systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text(display.resolution)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
            }
            
            // Placement instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Placement Instructions:")
                    .font(.headline)
                
                Label("Center colorimeter on screen", systemImage: "1.circle")
                Label("Ensure no ambient light on lens", systemImage: "2.circle")
                Label("Keep display at normal viewing brightness", systemImage: "3.circle")
            }
            .padding()
        }
        .padding()
    }
}

struct MeasurementStep: View {
    @ObservedObject var workflow: CalibrationWorkflow
    
    var body: some View {
        VStack(spacing: 20) {
            if workflow.measurementState == .measuring {
                ProgressView(value: workflow.measurementProgress) {
                    Text("Measuring...")
                } progressViewStyle(.linear)
                
                Text("Display will show color patches automatically")
                    .foregroundColor(.secondary)
                
                Text("Do not move the colorimeter or look away")
                    .font(.caption)
                    .foregroundColor(.orange)
                    
            } else if workflow.measurementState == .complete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                
                Text("Measurement Complete")
                    .font(.title2)
                
            } else {
                Image(systemName: "scope")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)
                
                Text("Ready to Measure")
                    .font(.title2)
                
                Text("Click Start to begin the measurement process. The display will cycle through color patches.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            if workflow.measurementState == .ready {
                workflow.startMeasurement()
            }
        }
    }
}

struct ProfileStep: View {
    @ObservedObject var workflow: CalibrationWorkflow
    
    var body: some View {
        VStack(spacing: 20) {
            if workflow.isGeneratingProfile {
                ProgressView("Generating ICC profile...")
                
            } else if workflow.profileGenerated {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                
                Text("Profile Generated")
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Label("ICC profile created", systemImage: "doc.badge.gearshape")
                    Label("Profile installed to system", systemImage: "folder")
                    Label("Profile applied to display", systemImage: "display")
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                
            } else {
                Image(systemName: "doc.badge.gearshape")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)
                
                Text("Generate ICC Profile")
                    .font(.title2)
                
                Text("Click Generate to create an ICC profile from the measurement data.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            if workflow.measurementState == .complete && !workflow.isGeneratingProfile && !workflow.profileGenerated {
                workflow.generateProfile()
            }
        }
    }
}

struct VerificationStep: View {
    @ObservedObject var workflow: CalibrationWorkflow
    
    var body: some View {
        VStack(spacing: 20) {
            if workflow.isVerifying {
                ProgressView("Verifying calibration...")
                
            } else if let deltaE = workflow.verificationDeltaE {
                VStack(spacing: 12) {
                    Text("Verification Result")
                        .font(.title2)
                    
                    // Delta-E display
                    HStack {
                        Text("Delta-E:")
                            .font(.headline)
                        
                        Text(String(format: "%.1f", deltaE))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(deltaE < 2 ? .green : deltaE < 4 ? .orange : .red)
                    }
                    
                    // Quality rating
                    Text(qualityText(for: deltaE))
                        .font(.headline)
                        .foregroundColor(deltaE < 2 ? .green : deltaE < 4 ? .orange : .red)
                    
                    // Explanation
                    VStack(alignment: .leading, spacing: 4) {
                        Label("< 1.0: Not perceptible", systemImage: "circle.fill")
                            .foregroundColor(.green)
                        Label("1.0-2.0: Perceptible through close observation", systemImage: "circle.fill")
                            .foregroundColor(.green)
                        Label("2.0-3.5: Perceptible at a glance", systemImage: "circle.fill")
                            .foregroundColor(.orange)
                        Label("3.5-5.0: Colors match poorly", systemImage: "circle.fill")
                            .foregroundColor(.red)
                        Label("> 5.0: Colors are different", systemImage: "circle.fill")
                            .foregroundColor(.red)
                    }
                    .font(.caption)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                
            } else {
                Image(systemName: "checkmark.magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)
                
                Text("Verify Calibration")
                    .font(.title2)
                
                Text("Click Verify to check the accuracy of your calibration.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private func qualityText(for deltaE: Double) -> String {
        if deltaE < 1.0 { return "Excellent" }
        if deltaE < 2.0 { return "Very Good" }
        if deltaE < 3.5 { return "Good" }
        if deltaE < 5.0 { return "Fair" }
        return "Poor"
    }
}

struct CompleteStep: View {
    @ObservedObject var workflow: CalibrationWorkflow
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Calibration Complete!")
                .font(.title)
            
            Text("Your display has been calibrated for optimal color accuracy.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("ICC profile is now active", systemImage: "checkmark.circle.fill")
                Label("Night Shift will be managed automatically", systemImage: "checkmark.circle.fill")
                Label("Profile will be verified weekly", systemImage: "checkmark.circle.fill")
                Label("Recalibration scheduled monthly", systemImage: "checkmark.circle.fill")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
            
            if let deltaE = workflow.verificationDeltaE {
                Text("Final accuracy: Delta-E \(String(format: "%.1f", deltaE))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    CalibrationWizardView()
}
