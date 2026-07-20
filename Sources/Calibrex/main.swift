import Foundation
import SwiftUI

/// NSApplication delegate for menu bar behavior
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

/// Calibrex - Adaptive Display Calibration Daemon
@main
struct CalibrexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Image(systemName: "circle.lefthalf.filled")
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @State private var showingSettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calibrex").font(.headline)
            Text("Adaptive Display Calibration").font(.caption).foregroundColor(.secondary)
            Divider()
            Button("Settings...") { showingSettings = true }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding()
        .frame(width: 250)
    }
}
