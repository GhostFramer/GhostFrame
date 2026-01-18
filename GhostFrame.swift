#!/usr/bin/env swift

import SwiftUI
import AppKit
import Combine
import Carbon.HIToolbox

// MARK: - Settings Manager (Persistence)
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    private let managedAppsKey = "managedApps"
    private let settingsKey = "appSettings"
    
    @Published var showMenuBarIcon: Bool = true {
        didSet { saveSettings() }
    }
    @Published var launchAtLogin: Bool = false {
        didSet { saveSettings() }
    }
    @Published var shortcuts: ShortcutSettings = ShortcutSettings() {
        didSet { saveSettings() }
    }
    
    struct ShortcutSettings: Codable {
        var toggleApp: String = "⌘⇧G"
        var toggleStealth: String = "⌘⇧S"
        var minimizeApp: String = "⌘⇧M"
        var maximizeApp: String = "⌘⇧F"
    }
    
    struct SavedApp: Codable {
        let path: String
        let isProtected: Bool
        let hideDock: Bool
    }
    
    private init() {
        loadSettings()
    }
    
    func loadSettings() {
        if let data = defaults.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            showMenuBarIcon = settings.showMenuBarIcon
            launchAtLogin = settings.launchAtLogin
            shortcuts = settings.shortcuts
        }
    }
    
    func saveSettings() {
        let settings = AppSettings(
            showMenuBarIcon: showMenuBarIcon,
            launchAtLogin: launchAtLogin,
            shortcuts: shortcuts
        )
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }
    
    func loadManagedApps() -> [SavedApp] {
        if let data = defaults.data(forKey: managedAppsKey),
           let apps = try? JSONDecoder().decode([SavedApp].self, from: data) {
            return apps
        }
        return []
    }
    
    func saveManagedApps(_ apps: [ManagedApp]) {
        let savedApps = apps.map { SavedApp(path: $0.appPath, isProtected: $0.isProtected, hideDock: $0.hideDock) }
        if let data = try? JSONEncoder().encode(savedApps) {
            defaults.set(data, forKey: managedAppsKey)
        }
    }
    
    struct AppSettings: Codable {
        let showMenuBarIcon: Bool
        let launchAtLogin: Bool
        let shortcuts: ShortcutSettings
    }
}

// MARK: - App Manager
class AppManager: ObservableObject {
    static let shared = AppManager()
    
    @Published var managedApps: [ManagedApp] = []
    @Published var availableApps: [AvailableApp] = []
    
    private init() {
        loadManagedApps()
        scanAllApplications()
    }
    
    func loadManagedApps() {
        let savedApps = SettingsManager.shared.loadManagedApps()
        var apps: [ManagedApp] = []
        
        for saved in savedApps {
            if let app = createManagedApp(from: saved.path) {
                app.isProtected = saved.isProtected
                app.hideDock = saved.hideDock
                apps.append(app)
            }
        }
        
        managedApps = apps
    }
    
    func saveManagedApps() {
        SettingsManager.shared.saveManagedApps(managedApps)
    }
    
    func scanAllApplications() {
        var apps: [AvailableApp] = []
        let appDirs = ["/Applications", "/System/Applications", NSHomeDirectory() + "/Applications"]
        
        for dir in appDirs {
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                for item in contents where item.hasSuffix(".app") {
                    let path = "\(dir)/\(item)"
                    if isElectronApp(path: path) && !managedApps.contains(where: { $0.appPath == path }) {
                        let name = item.replacingOccurrences(of: ".app", with: "")
                        let icon = NSWorkspace.shared.icon(forFile: path)
                        icon.size = NSSize(width: 32, height: 32)
                        apps.append(AvailableApp(name: name, path: path, icon: icon))
                    }
                }
            }
        }
        
        availableApps = apps.sorted { $0.name < $1.name }
    }
    
    func isElectronApp(path: String) -> Bool {
        let possiblePaths = [
            "\(path)/Contents/Resources/app/out/main.js",
            "\(path)/Contents/Resources/app/main.js",
            "\(path)/Contents/Resources/app.asar",
            "\(path)/Contents/Frameworks/Electron Framework.framework"
        ]
        return possiblePaths.contains { FileManager.default.fileExists(atPath: $0) }
    }
    
    func addApp(from available: AvailableApp) {
        if let app = createManagedApp(from: available.path) {
            managedApps.append(app)
            availableApps.removeAll { $0.path == available.path }
            saveManagedApps()
        }
    }
    
    func removeApp(_ app: ManagedApp) {
        // Disable protection first
        if app.isProtected {
            _ = app.disableProtection()
        }
        managedApps.removeAll { $0.id == app.id }
        saveManagedApps()
        scanAllApplications()
    }
    
    private func createManagedApp(from path: String) -> ManagedApp? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        
        let possibleMainJsPaths = [
            "\(path)/Contents/Resources/app/out/main.js",
            "\(path)/Contents/Resources/app/main.js"
        ]
        
        var mainJsPath: String? = nil
        for p in possibleMainJsPaths {
            if FileManager.default.fileExists(atPath: p) {
                mainJsPath = p
                break
            }
        }
        
        guard let jsPath = mainJsPath else { return nil }
        
        let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let bundleId = Bundle(path: path)?.bundleIdentifier ?? ""
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 40, height: 40)
        
        let isProtected = checkIfProtected(mainJsPath: jsPath)
        let isRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleId }
        
        return ManagedApp(
            name: name,
            bundleId: bundleId,
            appPath: path,
            mainJsPath: jsPath,
            icon: icon,
            isProtected: isProtected,
            isRunning: isRunning,
            hideDock: false
        )
    }
    
    private func checkIfProtected(mainJsPath: String) -> Bool {
        guard let content = try? String(contentsOfFile: mainJsPath, encoding: .utf8) else { return false }
        return content.contains("GHOSTFRAME CONTENT PROTECTION")
    }
    
    func toggleAllStealth() {
        for app in managedApps {
            if !app.isProtected {
                _ = app.enableProtection()
            }
        }
        saveManagedApps()
    }
}

// MARK: - Available App (for adding)
struct AvailableApp: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: NSImage
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
    @Published var hideDock: Bool
    
    private var backupPath: String { mainJsPath + ".ghostframe.backup" }
    
    init(name: String, bundleId: String, appPath: String, mainJsPath: String, icon: NSImage?, isProtected: Bool, isRunning: Bool, hideDock: Bool) {
        self.name = name
        self.bundleId = bundleId
        self.appPath = appPath
        self.mainJsPath = mainJsPath
        self.icon = icon
        self.isProtected = isProtected
        self.isRunning = isRunning
        self.hideDock = hideDock
    }
    
    private func getPatchCode() -> String {
        return """
// ==== GHOSTFRAME CONTENT PROTECTION START ====
import { app } from 'electron';

\(hideDock ? "if (process.platform === 'darwin') { try { app.dock.hide(); } catch(e) {} }" : "")

app.on('browser-window-created', (event, window) => {
    try {
        window.setContentProtection(true);
        if (process.platform === 'darwin') {
            window.setHiddenInMissionControl(true);
        }
    } catch (e) {}
});

console.log('[GhostFrame] Stealth mode activated');
// ==== GHOSTFRAME CONTENT PROTECTION END ====

"""
    }
    
    func toggleProtection() -> Bool {
        return isProtected ? disableProtection() : enableProtection()
    }
    
    func enableProtection() -> Bool {
        do {
            if !FileManager.default.fileExists(atPath: backupPath) {
                let original = try String(contentsOfFile: mainJsPath, encoding: .utf8)
                try original.write(toFile: backupPath, atomically: true, encoding: .utf8)
            }
            
            let backup = try String(contentsOfFile: backupPath, encoding: .utf8)
            let patched = getPatchCode() + backup
            try patched.write(toFile: mainJsPath, atomically: true, encoding: .utf8)
            
            DispatchQueue.main.async { self.isProtected = true }
            AppManager.shared.saveManagedApps()
            return true
        } catch {
            print("Enable failed: \(error)")
            return false
        }
    }
    
    func disableProtection() -> Bool {
        do {
            if FileManager.default.fileExists(atPath: backupPath) {
                let backup = try String(contentsOfFile: backupPath, encoding: .utf8)
                try backup.write(toFile: mainJsPath, atomically: true, encoding: .utf8)
            }
            DispatchQueue.main.async { self.isProtected = false }
            AppManager.shared.saveManagedApps()
            return true
        } catch {
            print("Disable failed: \(error)")
            return false
        }
    }
    
    func updateDockSetting() {
        if isProtected {
            _ = disableProtection()
            _ = enableProtection()
        }
        AppManager.shared.saveManagedApps()
    }
    
    func restart() {
        let workspace = NSWorkspace.shared
        if let running = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) {
            running.terminate()
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                let url = URL(fileURLWithPath: self.appPath)
                DispatchQueue.main.async {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
                        DispatchQueue.main.async { self.isRunning = true }
                    }
                }
            }
        }
    }
    
    func refreshRunningState() {
        isRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleId }
    }
}

// MARK: - Visual Effect View
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = 12
        return v
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - App Card View
struct AppCardView: View {
    @ObservedObject var app: ManagedApp
    @State private var isHovering = false
    @State private var showRestartAlert = false
    @State private var showOptions = false
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 36, height: 36)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(app.isProtected ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(app.isProtected ? "Protected" : "Visible")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if app.isRunning {
                        Text("• Running")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Options button
            Button(action: { showOptions.toggle() }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showOptions, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Hide from Dock", isOn: $app.hideDock)
                        .onChange(of: app.hideDock) { _ in app.updateDockSetting() }
                    
                    Divider()
                    
                    Button(action: { app.restart() }) {
                        Label("Restart App", systemImage: "arrow.clockwise")
                    }
                    
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                .padding(12)
                .frame(width: 160)
            }
            
            // Toggle
            Button(action: { toggleProtection() }) {
                ZStack {
                    Capsule()
                        .fill(app.isProtected ?
                              LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing) :
                              LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 44, height: 26)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .shadow(radius: 1)
                        .offset(x: app.isProtected ? 9 : -9)
                        .animation(.spring(response: 0.3), value: app.isProtected)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 0.8 : 0.5))
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .alert("Restart \(app.name)?", isPresented: $showRestartAlert) {
            Button("Restart Now") { app.restart() }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Restart for changes to take effect.")
        }
    }
    
    private func toggleProtection() {
        _ = app.toggleProtection()
        showRestartAlert = true
    }
}

// MARK: - Add App View
struct AddAppView: View {
    @ObservedObject var appManager = AppManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var filteredApps: [AvailableApp] {
        if searchText.isEmpty {
            return appManager.availableApps
        }
        return appManager.availableApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Application")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.cyan)
            }
            .padding(16)
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search Electron apps...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
            .padding(.horizontal, 16)
            
            Divider().padding(.top, 12)
            
            // App List
            if filteredApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No Electron apps found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredApps) { app in
                            HStack(spacing: 12) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .cornerRadius(6)
                                
                                Text(app.name)
                                    .font(.system(size: 13, weight: .medium))
                                
                                Spacer()
                                
                                Button(action: {
                                    appManager.addApp(from: app)
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.cyan)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 360, height: 450)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.cyan)
            }
            .padding(16)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // General
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GENERAL")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
                        Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    }
                    
                    Divider()
                    
                    // Shortcuts
                    VStack(alignment: .leading, spacing: 12) {
                        Text("KEYBOARD SHORTCUTS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        ShortcutRow(label: "Toggle GhostFrame", shortcut: $settings.shortcuts.toggleApp)
                        ShortcutRow(label: "Toggle Stealth Mode", shortcut: $settings.shortcuts.toggleStealth)
                        ShortcutRow(label: "Minimize Window", shortcut: $settings.shortcuts.minimizeApp)
                        ShortcutRow(label: "Maximize Window", shortcut: $settings.shortcuts.maximizeApp)
                    }
                    
                    Divider()
                    
                    // About
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ABOUT")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 320, height: 400)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}

struct ShortcutRow: View {
    let label: String
    @Binding var shortcut: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))
        }
    }
}

// MARK: - Main Menu Bar View
struct MenuBarView: View {
    @ObservedObject var appManager = AppManager.shared
    @State private var showAddApp = false
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "eye.slash.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("GhostFrame")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("\(appManager.managedApps.count) apps managed")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.secondary.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            
            Divider().opacity(0.5)
            
            // App List
            if appManager.managedApps.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "plus.app")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No apps added yet")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Button(action: { showAddApp = true }) {
                        Label("Add Application", systemImage: "plus")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appManager.managedApps) { app in
                            AppCardView(app: app) {
                                appManager.removeApp(app)
                            }
                        }
                    }
                    .padding(12)
                }
            }
            
            Divider().opacity(0.5)
            
            // Footer
            HStack {
                Button(action: { showAddApp = true }) {
                    Label("Add App", systemImage: "plus.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
        .frame(width: 320, height: 420)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .sheet(isPresented: $showAddApp) {
            AddAppView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var settingsObserver: AnyCancellable?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusItem()
        setupPopover()
        observeSettings()
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Try to load custom icon
            let iconPath = Bundle.main.path(forResource: "menubar_icon", ofType: "png")
            if let path = iconPath, let image = NSImage(contentsOfFile: path) {
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "eye.slash.circle.fill", accessibilityDescription: "GhostFrame")
                button.image?.isTemplate = true
            }
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }
    
    func observeSettings() {
        settingsObserver = SettingsManager.shared.$showMenuBarIcon.sink { [weak self] show in
            self?.statusItem.isVisible = show
        }
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                // Refresh running states
                AppManager.shared.managedApps.forEach { $0.refreshRunningState() }
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}

// MARK: - Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
