#!/usr/bin/env swift

import SwiftUI
import AppKit
import Combine

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var isDarkMode: Bool = true {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
            applyTheme()
        }
    }
    
    private init() {
        isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? true
    }
    
    func applyTheme() {
        if isDarkMode {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        } else {
            NSApp.appearance = NSAppearance(named: .aqua)
        }
    }
    
    var backgroundColor: Color {
        isDarkMode ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.95, green: 0.95, blue: 0.97)
    }
    
    var surfaceColor: Color {
        isDarkMode ? Color(white: 0.15) : Color.white
    }
    
    var textColor: Color {
        isDarkMode ? .white : .black
    }
    
    var secondaryTextColor: Color {
        isDarkMode ? Color(white: 0.6) : Color(white: 0.5)
    }
    
    var dividerColor: Color {
        isDarkMode ? Color(white: 0.25) : Color(white: 0.85)
    }
    
    var rowHoverColor: Color {
        isDarkMode ? Color(white: 1.0, opacity: 0.05) : Color(white: 0.0, opacity: 0.03)
    }
}

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
    
    struct SavedApp: Codable {
        let path: String
        let isEnabled: Bool
        let invisibility: Bool
        let hideDock: Bool
        let hideBackground: Bool
    }
    
    struct AppSettings: Codable {
        let showMenuBarIcon: Bool
        let launchAtLogin: Bool
    }
    
    private init() {
        loadSettings()
    }
    
    func loadSettings() {
        if let data = defaults.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            showMenuBarIcon = settings.showMenuBarIcon
            launchAtLogin = settings.launchAtLogin
        }
    }
    
    func saveSettings() {
        let settings = AppSettings(
            showMenuBarIcon: showMenuBarIcon,
            launchAtLogin: launchAtLogin
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
        let savedApps = apps.map { 
            SavedApp(
                path: $0.appPath, 
                isEnabled: $0.isEnabled, 
                invisibility: $0.invisibility,
                hideDock: $0.hideDock, 
                hideBackground: $0.hideBackground
            ) 
        }
        if let data = try? JSONEncoder().encode(savedApps) {
            defaults.set(data, forKey: managedAppsKey)
        }
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
                app.isEnabled = saved.isEnabled
                app.invisibility = saved.invisibility
                app.hideDock = saved.hideDock
                app.hideBackground = saved.hideBackground
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
                        icon.size = NSSize(width: 64, height: 64)
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                managedApps.append(app)
                availableApps.removeAll { $0.path == available.path }
            }
            saveManagedApps()
        }
    }
    
    func removeApp(_ app: ManagedApp) {
        if app.isEnabled {
            _ = app.disableAll()
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            managedApps.removeAll { $0.id == app.id }
        }
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
        icon.size = NSSize(width: 64, height: 64)
        
        let isProtected = checkIfProtected(mainJsPath: jsPath)
        let isRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleId }
        
        return ManagedApp(
            name: name,
            bundleId: bundleId,
            appPath: path,
            mainJsPath: jsPath,
            icon: icon,
            isEnabled: isProtected,
            invisibility: true,
            hideDock: false,
            hideBackground: false,
            isRunning: isRunning
        )
    }
    
    private func checkIfProtected(mainJsPath: String) -> Bool {
        guard let content = try? String(contentsOfFile: mainJsPath, encoding: .utf8) else { return false }
        return content.contains("GHOSTFRAME CONTENT PROTECTION")
    }
    
    var protectedCount: Int {
        managedApps.filter { $0.isEnabled }.count
    }
}

struct AvailableApp: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: NSImage
}

class ManagedApp: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    let bundleId: String
    let appPath: String
    let mainJsPath: String
    let icon: NSImage?
    
    @Published var invisibility: Bool = true
    @Published var hideDock: Bool = false
    @Published var hideBackground: Bool = false
    @Published var isEnabled: Bool = false
    @Published var isRunning: Bool = false
    @Published var lastError: String? = nil
    @Published var needsRepair: Bool = false
    
    private var backupPath: String { mainJsPath + ".ghostframe.backup" }
    private var plistPath: String { appPath + "/Contents/Info.plist" }
    private var plistBackupPath: String { appPath + "/Contents/Info.plist.ghostframe.backup" }
    
    init(name: String, bundleId: String, appPath: String, mainJsPath: String, icon: NSImage?, 
         isEnabled: Bool, invisibility: Bool, hideDock: Bool, hideBackground: Bool, isRunning: Bool) {
        self.name = name
        self.bundleId = bundleId
        self.appPath = appPath
        self.mainJsPath = mainJsPath
        self.icon = icon
        self.isEnabled = isEnabled
        self.invisibility = invisibility
        self.hideDock = hideDock
        self.hideBackground = hideBackground
        self.isRunning = isRunning
    }
    
    // Check if we have write permission to the app
    func hasWritePermission() -> Bool {
        return FileManager.default.isWritableFile(atPath: mainJsPath)
    }
    
    // Check if backup exists (can be repaired)
    func hasBackup() -> Bool {
        return FileManager.default.fileExists(atPath: backupPath)
    }
    
    // Repair app by restoring from backup
    func repair() -> Bool {
        var success = true
        
        // Restore main.js from backup
        if FileManager.default.fileExists(atPath: backupPath) {
            do {
                let backup = try String(contentsOfFile: backupPath, encoding: .utf8)
                try backup.write(toFile: mainJsPath, atomically: true, encoding: .utf8)
            } catch {
                success = false
                lastError = "Failed to restore main.js: \(error.localizedDescription)"
            }
        }
        
        // Restore Info.plist from backup - just overwrite, don't remove first
        if FileManager.default.fileExists(atPath: plistBackupPath) {
            do {
                let backupData = try Data(contentsOf: URL(fileURLWithPath: plistBackupPath))
                try backupData.write(to: URL(fileURLWithPath: plistPath))
            } catch {
                success = false
                lastError = "Failed to restore Info.plist: \(error.localizedDescription)"
            }
        }
        
        if success {
            isEnabled = false
            hideDock = false
            hideBackground = false
            invisibility = true
            needsRepair = false
            lastError = nil
            AppManager.shared.saveManagedApps()
        }
        
        return success
    }
    
    private func getPatchCode() -> String {
        var features: [String] = []
        if invisibility { features.append("invisibility") }
        if hideDock { features.append("dockHide") }
        if hideBackground { features.append("backgroundHide") }
        
        let featuresStr = features.map { "\"\($0)\"" }.joined(separator: ", ")
        
        // ESM-safe hybrid loader that works with both CommonJS and ES modules
        let code = """
// ==== GHOSTFRAME CONTENT PROTECTION START ====
(async () => {
    const features = [\(featuresStr)];
    let electron;
    try {
        // Try dynamic import first (ESM)
        electron = await import('electron');
    } catch (e) {
        // Fall back to require (CommonJS)
        electron = require('electron');
    }
    
    const app = electron.app || electron.default?.app;
    const BrowserWindow = electron.BrowserWindow || electron.default?.BrowserWindow;
    
    if (!app) {
        console.error('[GhostFrame] Could not load electron app');
        return;
    }
    
    // Background process disguise
    if (features.includes('backgroundHide')) {
        try { process.title = 'com.apple.WebKit.Helper'; } catch(e) {}
    }
    
    // Hide from dock on macOS (reapply and prevent re-show)
    if (features.includes('dockHide') && process.platform === 'darwin') {
        const hideDock = () => {
            try {
                if (app.dock && app.dock.hide) {
                    app.dock.hide();
                }
            } catch (e) {}
        };
        
        app.whenReady().then(() => {
            hideDock();
            
            // Override dock.show to prevent app from re-showing itself
            try {
                if (app.dock && app.dock.show) {
                    app.dock.show = () => {};
                }
            } catch (e) {}
            
            // Reapply a few times after launch
            let attempts = 0;
            const timer = setInterval(() => {
                hideDock();
                attempts += 1;
                if (attempts >= 8) {
                    clearInterval(timer);
                }
            }, 750);
        });
        
        // Also hide when new windows are created
        app.on('browser-window-created', () => {
            hideDock();
        });
    }
    
    // Content protection for invisibility
    if (features.includes('invisibility')) {
        const applyProtection = (win) => {
            try {
                win.setContentProtection(true);
                if (process.platform === 'darwin') {
                    if (win.setHiddenInMissionControl) win.setHiddenInMissionControl(true);
                }
                if (process.platform === 'win32') {
                    if (win.setSkipTaskbar) win.setSkipTaskbar(true);
                }
            } catch (e) {}
        };
        
        // Apply to future windows
        app.on('browser-window-created', (event, window) => {
            applyProtection(window);
        });
        
        // Apply to existing windows
        app.whenReady().then(() => {
            if (BrowserWindow && BrowserWindow.getAllWindows) {
                BrowserWindow.getAllWindows().forEach(applyProtection);
            }
        });
    }
    
    console.log('[GhostFrame] Stealth mode activated:', features.join(', '));
})();
// ==== GHOSTFRAME CONTENT PROTECTION END ====

"""
        return code
    }
    
    func applyProtection() -> Bool {
        // Check write permission first
        guard hasWritePermission() else {
            lastError = "No write permission. Grant Full Disk Access in System Settings > Privacy & Security."
            isEnabled = false
            return false
        }
        
        lastError = nil
        guard isEnabled else { return disableAll() }
        
        var success = true
        
        // Always apply JS protection if any feature is enabled
        if invisibility || hideBackground || hideDock {
            success = enableJSProtection() && success
        }
        
        if !success {
            needsRepair = true
        }
        
        AppManager.shared.saveManagedApps()
        return success
    }
    
    func disableAll() -> Bool {
        // Check write permission first
        guard hasWritePermission() else {
            lastError = "No write permission. Grant Full Disk Access in System Settings > Privacy & Security."
            return false
        }
        
        lastError = nil
        let success = disableJSProtection()
        AppManager.shared.saveManagedApps()
        return success
    }
    
    private func enableJSProtection() -> Bool {
        do {
            if !FileManager.default.fileExists(atPath: backupPath) {
                let original = try String(contentsOfFile: mainJsPath, encoding: .utf8)
                try original.write(toFile: backupPath, atomically: true, encoding: .utf8)
            }
            let backup = try String(contentsOfFile: backupPath, encoding: .utf8)
            let patched = getPatchCode() + backup
            try patched.write(toFile: mainJsPath, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
    
    private func disableJSProtection() -> Bool {
        do {
            if FileManager.default.fileExists(atPath: backupPath) {
                let backup = try String(contentsOfFile: backupPath, encoding: .utf8)
                try backup.write(toFile: mainJsPath, atomically: true, encoding: .utf8)
            }
            return true
        } catch {
            return false
        }
    }
    
    func restart() {
        let appURL = URL(fileURLWithPath: self.appPath)
        
        // Get the PID and force kill by PID
        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) {
            let pid = running.processIdentifier
            
            // Force terminate using the API
            running.forceTerminate()
            
            // Also use kill -9 on the PID for certainty
            let killProcess = Process()
            killProcess.launchPath = "/bin/kill"
            killProcess.arguments = ["-9", String(pid)]
            try? killProcess.run()
            killProcess.waitUntilExit()
            
            // Poll until process is gone, then relaunch
            pollUntilTerminated(pid: pid) {
                self.launchApp(at: appURL)
            }
        } else {
            // App not running, just launch
            launchApp(at: appURL)
        }
    }
    
    private func pollUntilTerminated(pid: pid_t, attempts: Int = 0, completion: @escaping () -> Void) {
        // Check if process still exists
        let result = kill(pid, 0)
        
        if result != 0 || attempts >= 10 {
            // Process is gone or we've waited long enough (5 seconds)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion()
            }
        } else {
            // Still running, check again in 500ms
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.pollUntilTerminated(pid: pid, attempts: attempts + 1, completion: completion)
            }
        }
    }
    
    private func launchApp(at url: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
            DispatchQueue.main.async {
                self.isRunning = (app != nil)
                // Refresh after a short delay to ensure state is updated
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.refreshRunningState()
                }
            }
        }
    }
    
    func launch() {
        let appURL = URL(fileURLWithPath: self.appPath)
        launchApp(at: appURL)
    }
    
    func revealInFinder() {
        NSWorkspace.shared.selectFile(appPath, inFileViewerRootedAtPath: "")
    }
    
    func refreshRunningState() {
        isRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleId }
    }
}

// MARK: - Premium UI Components

struct LiquidGlassToggle: View {
    @Binding var isOn: Bool
    
    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { isOn.toggle() } }) {
            ZStack {
                // Background
                Capsule()
                    .fill(isOn ? Color.accentColor.opacity(0.8) : Color.clear)
                    .background(Material.ultraThin, in: Capsule())
                    .frame(width: 44, height: 24)
                    .overlay(
                        Capsule()
                            .strokeBorder(isOn ? Color.white.opacity(0.2) : Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: isOn ? Color.accentColor.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                
                // Knob
                Circle()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .offset(x: isOn ? 10 : -10)
            }
        }
        .buttonStyle(.plain)
    }
}

struct LiquidGlassCheckbox: View {
    @Binding var isOn: Bool
    var disabled: Bool = false
    @ObservedObject var theme = ThemeManager.shared
    
    var body: some View {
        Button(action: { if !disabled { withAnimation(.spring(response: 0.3)) { isOn.toggle() } } }) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isOn ? Color.accentColor : (theme.isDarkMode ? Color.clear : Color.white))
                    .background(Material.ultraThin, in: RoundedRectangle(cornerRadius: 6))
                    .frame(width: 22, height: 22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isOn ? Color.accentColor : (theme.isDarkMode ? Color.white.opacity(0.2) : Color.gray.opacity(0.4)), lineWidth: 1.5)
                    )
                    .shadow(color: isOn ? Color.accentColor.opacity(0.3) : .clear, radius: 3)
                
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.3 : 1.0)
    }
}

struct PremiumHeaderView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var appManager = AppManager.shared
    @Binding var showSettings: Bool
    @State private var isRefreshing = false
    
    var body: some View {
        HStack(spacing: 16) {
            if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
               let icon = NSImage(contentsOfFile: iconPath) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text("GhostFrame")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.textColor)
                Text("Stealth Mode Manager")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryTextColor)
            }
            
            Spacer()
            
            // Refresh Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.5)) { isRefreshing = true }
                appManager.managedApps.forEach { $0.refreshRunningState() }
                appManager.scanAllApplications()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation { isRefreshing = false }
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Material.ultraThin)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.textColor)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                }
            }
            .buttonStyle(.plain)
            
            // Theme Toggle
            Button(action: { withAnimation { theme.isDarkMode.toggle() } }) {
                ZStack {
                    Circle()
                        .fill(Material.ultraThin)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    
                    Image(systemName: theme.isDarkMode ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textColor)
                }
            }
            .buttonStyle(.plain)
            
            // Settings
            Button(action: { showSettings = true }) {
                ZStack {
                    Circle()
                        .fill(Material.ultraThin)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textColor)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(theme.backgroundColor)
    }
}

struct AppTableRow: View {
    @ObservedObject var app: ManagedApp
    @ObservedObject var theme = ThemeManager.shared
    @State private var isHovering = false
    @State private var showRestartAlert = false
    @State private var showPermissionAlert = false
    @State private var showRepairAlert = false
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // App Info
                HStack(spacing: 14) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 38, height: 38)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.1), radius: 2)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(app.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.textColor)
                                .lineLimit(1)
                            
                            if app.needsRepair || app.lastError != nil {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(app.isRunning ? Color.green : Color.gray)
                                .frame(width: 6, height: 6)
                            Text(app.isRunning ? "Running" : "Offline")
                                .font(.system(size: 11))
                                .foregroundColor(app.isRunning ? .green : theme.secondaryTextColor)
                        }
                    }
                }
                .frame(width: 180, alignment: .leading)
                
                // Toggles - centered
                HStack(spacing: 0) {
                    LiquidGlassCheckbox(isOn: Binding(
                        get: { app.invisibility },
                        set: { v in 
                            if app.hasWritePermission() {
                                app.invisibility = v
                                if app.isEnabled { _ = app.applyProtection() }
                            } else {
                                showPermissionAlert = true
                            }
                        }
                    ), disabled: !app.isEnabled)
                    .frame(width: 100)
                    
                    LiquidGlassCheckbox(isOn: Binding(
                        get: { app.hideDock },
                        set: { v in 
                            if app.hasWritePermission() {
                                app.hideDock = v
                                if app.isEnabled { _ = app.applyProtection(); showRestartAlert = true }
                            } else {
                                showPermissionAlert = true
                            }
                        }
                    ), disabled: !app.isEnabled)
                    .frame(width: 70)
                    
                    LiquidGlassCheckbox(isOn: Binding(
                        get: { app.hideBackground },
                        set: { v in 
                            if app.hasWritePermission() {
                                app.hideBackground = v
                                if app.isEnabled { _ = app.applyProtection() }
                            } else {
                                showPermissionAlert = true
                            }
                        }
                    ), disabled: !app.isEnabled)
                    .frame(width: 100)
                }
                
                Spacer()
                
                // Status & Actions
                HStack(spacing: 12) {
                    LiquidGlassToggle(isOn: Binding(
                        get: { app.isEnabled },
                        set: { v in 
                            if app.hasWritePermission() {
                                app.isEnabled = v
                                let success = app.applyProtection()
                                if v && success { showRestartAlert = true }
                                if !success { showPermissionAlert = true }
                            } else {
                                showPermissionAlert = true
                            }
                        }
                    ))
                    .frame(width: 70)
                    
                    Menu {
                        if app.isRunning {
                            Button(action: { app.restart() }) {
                                Label("Restart App", systemImage: "arrow.clockwise")
                            }
                        } else {
                            Button(action: { app.launch() }) {
                                Label("Launch App", systemImage: "play.fill")
                            }
                        }
                        Button(action: { app.revealInFinder() }) {
                            Label("Reveal in Finder", systemImage: "folder")
                        }
                        
                        if app.hasBackup() {
                            Divider()
                            Button(action: { showRepairAlert = true }) {
                                Label("Repair App", systemImage: "wrench.and.screwdriver")
                            }
                        }
                        
                        Divider()
                        Button(role: .destructive, action: onRemove) {
                            Label("Remove", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(isHovering ? theme.textColor : theme.secondaryTextColor)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 60)
                }
            }
            .padding(.horizontal, 24)
            
            // Error message row
            if let error = app.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                    Spacer()
                    if app.hasBackup() {
                        Button("Repair") { showRepairAlert = true }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentColor)
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovering ? theme.surfaceColor : Color.clear)
                .animation(.easeInOut(duration: 0.15), value: isHovering)
        )
        .onHover { isHovering = $0 }
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("Restart Now") { app.restart() }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Please restart \(app.name) for changes to take effect.")
        }
        .alert("Permission Required", isPresented: $showPermissionAlert) {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("GhostFrame needs Full Disk Access to modify app files.\n\nGo to System Settings > Privacy & Security > Full Disk Access and enable GhostFrame.")
        }
        .alert("Repair App?", isPresented: $showRepairAlert) {
            Button("Repair", role: .destructive) {
                if app.repair() {
                    app.launch()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore \(app.name) to its original state, removing all GhostFrame modifications. The app should work normally after repair.")
        }
    }
}

struct AvailableAppRow: View {
    let app: AvailableApp
    let onAdd: () -> Void
    @State private var isHovering = false
    @State private var isButtonHovering = false
    @ObservedObject var theme = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            
            Text(app.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.textColor)
            
            Spacer()
            
            Button(action: onAdd) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Add")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isButtonHovering ? Color.accentColor : Color.accentColor.opacity(0.15))
                )
                .foregroundColor(isButtonHovering ? .white : .accentColor)
            }
            .buttonStyle(.plain)
            .onHover { isButtonHovering = $0 }
            .animation(.easeInOut(duration: 0.15), value: isButtonHovering)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovering ? theme.surfaceColor : Color.clear)
                .animation(.easeInOut(duration: 0.15), value: isHovering)
        )
        .onHover { isHovering = $0 }
    }
}

struct MainWindowView: View {
    @ObservedObject var appManager = AppManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var dismissedWarning = false
    
    var filteredAvailableApps: [AvailableApp] {
        if searchText.isEmpty { return appManager.availableApps }
        return appManager.availableApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            PremiumHeaderView(showSettings: $showSettings)
            
            Divider().opacity(0.1)
            
            // Warning Banner
            if !dismissedWarning {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                    
                    Text("App may crash after modification. Try at your own risk.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.isDarkMode ? .white : .black)
                    
                    Spacer()
                    
                    Button(action: { withAnimation { dismissedWarning = true } }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.secondaryTextColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(theme.isDarkMode ? 0.15 : 0.1))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.orange.opacity(0.3)),
                    alignment: .bottom
                )
            }
            
            ScrollView {
                VStack(spacing: 32) {
                    // Managed Apps Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("MANAGED APPLICATIONS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.0)
                            .foregroundColor(theme.secondaryTextColor)
                            .padding(.horizontal, 32)
                        
                        // Header
                        HStack(spacing: 0) {
                            Text("APPLICATION").font(.system(size: 10, weight: .bold)).foregroundColor(theme.secondaryTextColor)
                                .frame(width: 180, alignment: .leading)
                            HStack(spacing: 0) {
                                Text("INVISIBILITY").frame(width: 100)
                                Text("DOCK").frame(width: 70)
                                Text("BACKGROUND").frame(width: 100)
                            }
                            .font(.system(size: 10, weight: .bold)).foregroundColor(theme.secondaryTextColor)
                            Spacer()
                            HStack(spacing: 12) {
                                Text("STATUS").frame(width: 70)
                                Text("ACTIONS").frame(width: 60)
                            }
                            .font(.system(size: 10, weight: .bold)).foregroundColor(theme.secondaryTextColor)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                        
                        if appManager.managedApps.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "app.dashed")
                                    .font(.system(size: 32))
                                    .foregroundColor(theme.secondaryTextColor.opacity(0.5))
                                Text("No apps managed")
                                    .foregroundColor(theme.secondaryTextColor)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .background(theme.surfaceColor.opacity(0.3))
                            .cornerRadius(12)
                            .padding(.horizontal, 32)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(appManager.managedApps) { app in
                                    AppTableRow(app: app) {
                                        appManager.removeApp(app)
                                    }
                                    if app.id != appManager.managedApps.last?.id {
                                        Divider().background(theme.dividerColor).padding(.horizontal, 32)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Available Apps Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("AVAILABLE APPLICATIONS")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(theme.secondaryTextColor)
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.secondaryTextColor)
                                TextField("Search apps...", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13))
                            }
                            .padding(10)
                            .frame(width: 240)
                            .background(theme.surfaceColor)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }
                        .padding(.horizontal, 32)
                        
                        LazyVStack(spacing: 4) {
                            ForEach(filteredAvailableApps) { app in
                                AvailableAppRow(app: app) {
                                    appManager.addApp(from: app)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 24)
            }
        }
        .background(theme.backgroundColor)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.plain).foregroundColor(.accentColor)
            }
            .padding(20)
            .background(theme.surfaceColor)
            
            Form {
                Section {
                    Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
                    Toggle("Launch at login", isOn: $settings.launchAtLogin)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(theme.backgroundColor)
        }
        .frame(width: 350, height: 250)
    }
}

// MARK: - Menu Bar Popover
struct MenuBarView: View {
    @ObservedObject var appManager = AppManager.shared
    @ObservedObject var theme = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("GhostFrame").font(.system(size: 14, weight: .bold))
                Spacer()
                
                // Settings button that opens Main Window and shows settings
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    // We need to notify the main window to open settings
                    // For simplicity, we just open the main window now
                    if let window = NSApp.windows.first(where: { $0.title == "GhostFrame" }) {
                        window.makeKeyAndOrderFront(nil)
                        // Trigger a notification or state change if we really want the sheet to open
                        // But opening the app is usually what users want
                    }
                }) {
                    Image(systemName: "gearshape.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Material.ultraThin)
            
            Divider()
            
            if appManager.managedApps.isEmpty {
                Text("No apps managed").padding(20).foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(appManager.managedApps) { app in
                            HStack {
                                if let icon = app.icon {
                                    Image(nsImage: icon).resizable().frame(width: 24, height: 24)
                                }
                                Text(app.name).font(.system(size: 13))
                                Spacer()
                                LiquidGlassToggle(isOn: Binding(
                                    get: { app.isEnabled },
                                    set: { v in app.isEnabled = v; _ = app.applyProtection() }
                                ))
                            }
                            .padding(12)
                            Divider()
                        }
                    }
                }
            }
            
            Divider()
            
            HStack {
                Button("Open GhostFrame") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first { $0.title == "GhostFrame" }?.makeKeyAndOrderFront(nil)
                }
                .buttonStyle(.plain).foregroundColor(.accentColor)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain).foregroundColor(.secondary)
            }
            .padding(12)
            .background(Material.ultraThin)
        }
        .frame(width: 280, height: 320)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow!
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var settingsObserver: AnyCancellable?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        ThemeManager.shared.applyTheme()
        NSApp.setActivationPolicy(.regular)
        
        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 950, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        mainWindow.title = "GhostFrame"
        mainWindow.titlebarAppearsTransparent = true
        mainWindow.titleVisibility = .hidden
        mainWindow.center()
        mainWindow.contentView = NSHostingView(rootView: MainWindowView())
        mainWindow.isReleasedWhenClosed = false
        mainWindow.minSize = NSSize(width: 800, height: 500)
        
        setupStatusItem()
        setupPopover()
        observeSettings()
        
        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let iconPath = Bundle.main.path(forResource: "menubar_icon", ofType: "png")
            if let path = iconPath, let image = NSImage(contentsOfFile: path) {
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "eye.slash.circle.fill", accessibilityDescription: "GhostFrame")
            }
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 320)
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
                AppManager.shared.managedApps.forEach { $0.refreshRunningState() }
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { mainWindow.makeKeyAndOrderFront(nil) }
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
