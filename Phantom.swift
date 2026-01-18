#!/usr/bin/env swift

import SwiftUI
import AppKit
import Combine

// MARK: - App Manager
class AppManager: ObservableObject {
    static let shared = AppManager()
    
    @Published var managedApps: [ManagedApp] = []
    
    private let electronApps: [(name: String, bundleId: String, path: String)] = [
        ("Antigravity", "com.google.antigravity", "/Applications/Antigravity.app"),
        ("Visual Studio Code", "com.microsoft.VSCode", "/Applications/Visual Studio Code.app"),
        ("Cursor", "com.todesktop.230313mzl4w4u92", "/Applications/Cursor.app"),
        ("Slack", "com.tinyspeck.slackmacgap", "/Applications/Slack.app"),
        ("Discord", "com.hnc.Discord", "/Applications/Discord.app"),
        ("Notion", "notion.id", "/Applications/Notion.app"),
        ("Figma", "com.figma.Desktop", "/Applications/Figma.app"),
        ("Obsidian", "md.obsidian", "/Applications/Obsidian.app"),
        ("Postman", "com.postmanlabs.mac", "/Applications/Postman.app"),
        ("Spotify", "com.spotify.client", "/Applications/Spotify.app"),
        ("WhatsApp", "net.whatsapp.WhatsApp", "/Applications/WhatsApp.app"),
        ("Telegram", "ru.keepcoder.Telegram", "/Applications/Telegram.app"),
        ("1Password", "com.1password.1password", "/Applications/1Password.app"),
        ("Windsurf", "com.codeium.windsurf", "/Applications/Windsurf.app"),
    ]
    
    private init() {
        scanForElectronApps()
    }
    
    func scanForElectronApps() {
        var apps: [ManagedApp] = []
        
        for appInfo in electronApps {
            let appPath = appInfo.path
            guard FileManager.default.fileExists(atPath: appPath) else { continue }
            
            let possibleMainJsPaths = [
                "\(appPath)/Contents/Resources/app/out/main.js",
                "\(appPath)/Contents/Resources/app/main.js",
                "\(appPath)/Contents/Resources/app.asar.unpacked/main.js"
            ]
            
            var mainJsPath: String? = nil
            for path in possibleMainJsPaths {
                if FileManager.default.fileExists(atPath: path) {
                    mainJsPath = path
                    break
                }
            }
            
            guard let jsPath = mainJsPath else { continue }
            
            let icon = NSWorkspace.shared.icon(forFile: appPath)
            icon.size = NSSize(width: 36, height: 36)
            
            let isProtected = checkIfProtected(mainJsPath: jsPath)
            let isRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == appInfo.bundleId
            }
            
            let app = ManagedApp(
                name: appInfo.name,
                bundleId: appInfo.bundleId,
                appPath: appPath,
                mainJsPath: jsPath,
                icon: icon,
                isProtected: isProtected,
                isRunning: isRunning
            )
            
            apps.append(app)
        }
        
        DispatchQueue.main.async {
            self.managedApps = apps
        }
    }
    
    private func checkIfProtected(mainJsPath: String) -> Bool {
        do {
            let content = try String(contentsOfFile: mainJsPath, encoding: .utf8)
            return content.contains("PHANTOM CONTENT PROTECTION")
        } catch {
            return false
        }
    }
}

// MARK: - Managed App Model
class ManagedApp: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    let bundleId: String
    let appPath: String
    let mainJsPath: String
    let icon: NSImage?
    
    @Published var isProtected: Bool
    @Published var isRunning: Bool
    
    private var backupPath: String {
        mainJsPath + ".phantom.backup"
    }
    
    private let patchCode = """
// ==== PHANTOM CONTENT PROTECTION START ====
// Stealth mode: Invisible to screenshots, screen recording, and screen sharing
import { app } from 'electron';

// Hide dock icon on macOS
if (process.platform === 'darwin') {
    try { app.dock.hide(); } catch(e) {}
}

// Apply content protection to all windows
app.on('browser-window-created', (event, window) => {
    try {
        window.setContentProtection(true);
        if (process.platform === 'darwin') {
            window.setHiddenInMissionControl(true);
        }
    } catch (e) {
        console.error('[Phantom] Error:', e.message);
    }
});

console.log('[Phantom] Stealth mode activated');
// ==== PHANTOM CONTENT PROTECTION END ====

"""
    
    init(name: String, bundleId: String, appPath: String, mainJsPath: String, icon: NSImage?, isProtected: Bool, isRunning: Bool) {
        self.name = name
        self.bundleId = bundleId
        self.appPath = appPath
        self.mainJsPath = mainJsPath
        self.icon = icon
        self.isProtected = isProtected
        self.isRunning = isRunning
    }
    
    func toggleProtection() -> Bool {
        if isProtected {
            return disableProtection()
        } else {
            return enableProtection()
        }
    }
    
    private func enableProtection() -> Bool {
        do {
            if !FileManager.default.fileExists(atPath: backupPath) {
                let originalContent = try String(contentsOfFile: mainJsPath, encoding: .utf8)
                try originalContent.write(toFile: backupPath, atomically: true, encoding: .utf8)
            }
            
            let backupContent = try String(contentsOfFile: backupPath, encoding: .utf8)
            let patchedContent = patchCode + backupContent
            try patchedContent.write(toFile: mainJsPath, atomically: true, encoding: .utf8)
            
            DispatchQueue.main.async { self.isProtected = true }
            return true
        } catch {
            print("Failed to enable protection: \(error)")
            return false
        }
    }
    
    private func disableProtection() -> Bool {
        do {
            if FileManager.default.fileExists(atPath: backupPath) {
                let backupContent = try String(contentsOfFile: backupPath, encoding: .utf8)
                try backupContent.write(toFile: mainJsPath, atomically: true, encoding: .utf8)
            }
            
            DispatchQueue.main.async { self.isProtected = false }
            return true
        } catch {
            print("Failed to disable protection: \(error)")
            return false
        }
    }
    
    func restart() {
        let workspace = NSWorkspace.shared
        
        if let runningApp = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) {
            runningApp.terminate()
            
            DispatchQueue.global(qos: .userInitiated).async {
                var attempts = 0
                while runningApp.isTerminated == false && attempts < 50 {
                    Thread.sleep(forTimeInterval: 0.1)
                    attempts += 1
                }
                
                Thread.sleep(forTimeInterval: 0.5)
                
                DispatchQueue.main.async {
                    let url = URL(fileURLWithPath: self.appPath)
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                        if error == nil {
                            DispatchQueue.main.async { self.isRunning = true }
                        }
                    }
                }
            }
        } else {
            let url = URL(fileURLWithPath: appPath)
            workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == self.bundleId
            }
        }
    }
}

// MARK: - Visual Effect View
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Header View
struct HeaderView: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.6, green: 0.2, blue: 0.9), Color(red: 0.3, green: 0.4, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.purple.opacity(0.4), radius: 8, x: 0, y: 4)
                
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Phantom")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Stealth Mode Manager")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { AppManager.shared.scanForElectronApps() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.secondary.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .help("Refresh app list")
        }
        .padding(20)
    }
}

// MARK: - App Card View
struct AppCardView: View {
    @ObservedObject var app: ManagedApp
    @State private var isHovering = false
    @State private var showingRestartAlert = false
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 14) {
            // App Icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "app.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(app.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(app.isProtected ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        
                        Text(app.isProtected ? "Protected" : "Visible")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    if app.isRunning {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 5, height: 5)
                            Text("Running")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Toggle Switch
            Button(action: { toggleProtection() }) {
                ZStack {
                    Capsule()
                        .fill(app.isProtected ?
                              LinearGradient(colors: [Color(red: 0.6, green: 0.2, blue: 0.9), Color(red: 0.3, green: 0.4, blue: 1.0)], startPoint: .leading, endPoint: .trailing) :
                              LinearGradient(colors: [Color.gray.opacity(0.25), Color.gray.opacity(0.35)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: 48, height: 28)
                        .shadow(color: app.isProtected ? Color.purple.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .offset(x: app.isProtected ? 10 : -10)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: app.isProtected)
                }
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.6 : 1.0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 0.9 : 0.6))
                .shadow(color: .black.opacity(isHovering ? 0.12 : 0.06), radius: isHovering ? 10 : 5, x: 0, y: isHovering ? 4 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .alert("Restart \(app.name)?", isPresented: $showingRestartAlert) {
            Button("Restart Now", role: .destructive) {
                app.restart()
            }
            Button("Later", role: .cancel) { }
        } message: {
            Text("Changes will take effect after restart.")
        }
    }
    
    private func toggleProtection() {
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let success = app.toggleProtection()
            
            DispatchQueue.main.async {
                isProcessing = false
                if success {
                    showingRestartAlert = true
                }
            }
        }
    }
}

// MARK: - Footer View
struct FooterView: View {
    @State private var isHoveringQuit = false
    
    var body: some View {
        HStack {
            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack(spacing: 5) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .medium))
                    Text("Quit Phantom")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(isHoveringQuit ? .primary : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(isHoveringQuit ? 0.15 : 0))
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHoveringQuit = hovering
                }
            }
            
            Spacer()
            
            Text("v1.0.0")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - Main View
struct PhantomMainView: View {
    @StateObject private var appManager = AppManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.02)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 1)
            
            if appManager.managedApps.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No Electron apps found")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Install supported apps like VS Code,\nCursor, Slack, or Discord")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(appManager.managedApps) { app in
                            AppCardView(app: app)
                        }
                    }
                    .padding(16)
                }
            }
            
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.02)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 1)
            
            FooterView()
        }
        .frame(width: 340, height: 520)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye.slash.circle.fill", accessibilityDescription: "Phantom")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 520)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: PhantomMainView())
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}

// MARK: - Main Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
