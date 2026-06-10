//
//  TakeCtrlApp.swift
//  TakeCtrl
//
//  Created by Zack on 11/24/25.
//

import Combine
import ServiceManagement
import SwiftUI

enum TakeCtrlError: Error {
    case failedLaunchAtLoginToggle
}

private enum Prefs {
    static let takeCtrlEnabled = "takeCtrlEnabled"
    static let controlFixEnabled = "controlFixEnabled"
    static let shiftFixEnabled = "shiftFixEnabled"
}

@main
struct TakeCtrlApp: App {
    @State private var takeCtrlToggle: Bool
    @State private var controlToggle: Bool
    @State private var shiftToggle: Bool
    @State private var openAtLoginPreference: Bool = LaunchAtLogin.isEnabled
    @StateObject private var interceptor: ClickInterceptor

    @State private var permissionTimer = Timer.publish(
        every: 1.0,
        on: .main,
        in: .common
    ).autoconnect()

    init() {
        let defaults = UserDefaults.standard
        let savedControl = defaults.object(forKey: Prefs.controlFixEnabled) == nil
            ? true
            : defaults.bool(forKey: Prefs.controlFixEnabled)
        let savedShift = defaults.bool(forKey: Prefs.shiftFixEnabled)
        let savedEnabled = defaults.object(forKey: Prefs.takeCtrlEnabled) == nil
            ? true
            : defaults.bool(forKey: Prefs.takeCtrlEnabled)

        let newInterceptor = ClickInterceptor()
        newInterceptor.enableControlFix = savedControl
        newInterceptor.enableShiftFix = savedShift

        var startSuccess = false
        if savedEnabled {
            do {
                try newInterceptor.start()
                startSuccess = true
                print("ClickInterceptor started successfully on launch.")
            } catch {
                print("Failed to start ClickInterceptor on launch: \(error)")
            }
        }

        _interceptor = StateObject(wrappedValue: newInterceptor)
        _takeCtrlToggle = State(initialValue: startSuccess)
        _controlToggle = State(initialValue: savedControl)
        _shiftToggle = State(initialValue: savedShift)
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 8) {
                if !interceptor.getPermission() {
                    Button(action: openAccessibilitySettings) {
                        Label(
                            "Open System Settings",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        Spacer()
                    }
                    .buttonStyle(.accessoryBar)
                } else {
                    HStack {
                        Text("Enable TakeCtrl")
                        Spacer()
                        Toggle("", isOn: $takeCtrlToggle)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    .padding([.leading, .trailing], 10)

                    if takeCtrlToggle {
                        Divider()

                        HStack {
                            Text("Control-Click Override")
                            Spacer()
                            Toggle("", isOn: $controlToggle)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        .padding([.leading, .trailing], 10)

                        HStack {
                            Text("Shift-Scroll Override")
                            Spacer()
                            Toggle("", isOn: $shiftToggle)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        .padding([.leading, .trailing], 10)
                    }

                    Divider()

                    HStack {
                        Text("Open at Login")
                        Spacer()
                        Toggle("", isOn: $openAtLoginPreference)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    .padding([.leading, .trailing], 10)
                }

                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)

                    let credits = NSMutableAttributedString(
                        string: "Created by Zack Dupree\nFork of "
                    )
                    let linkText = NSAttributedString(
                        string: "zacheri04/TakeCtrl",
                        attributes: [
                            .link: URL(string: "https://github.com/zacheri04/takectrl")!,
                            .foregroundColor: NSColor.linkColor,
                            .underlineStyle: NSUnderlineStyle.single.rawValue,
                        ]
                    )
                    credits.append(linkText)

                    NSApp.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "TakeCtrl",
                            .credits: credits,
                            .applicationVersion: Bundle.main.object(
                                forInfoDictionaryKey: "CFBundleShortVersionString"
                            ) as? String ?? "Unknown",
                        ]
                    )
                }) {
                    Text("About")
                    Spacer()
                }
                .buttonStyle(.accessoryBar)

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit")
                    Spacer()
                }
                .buttonStyle(.accessoryBar)
            }
            .onReceive(permissionTimer) { _ in
                guard !interceptor.hasStartedOnce else {
                    permissionTimer.upstream.connect().cancel()
                    return
                }

                if interceptor.getPermission() {
                    do {
                        try interceptor.start()
                        takeCtrlToggle = true
                    } catch {
                        print(error)
                    }
                }

                openAtLoginPreference = LaunchAtLogin.isEnabled
            }
            .padding(8)
        } label: {
            if let nsImage = NSImage(named: "AppIcon") {
                let image: NSImage = {
                    let ratio = $0.size.height / $0.size.width
                    $0.size.height = 18
                    $0.size.width = 18 / ratio
                    return $0
                }(nsImage)
                Image(nsImage: image)
            } else {
                Image(systemName: "computermouse")
            }
        }
        .onChange(of: takeCtrlToggle) {
            UserDefaults.standard.set(takeCtrlToggle, forKey: Prefs.takeCtrlEnabled)
            if takeCtrlToggle {
                do {
                    try interceptor.start()
                } catch {
                    takeCtrlToggle = false
                }
            } else {
                interceptor.stop()
            }
        }
        .onChange(of: controlToggle) {
            UserDefaults.standard.set(controlToggle, forKey: Prefs.controlFixEnabled)
            interceptor.setEnableControlFix(controlToggle)
        }
        .onChange(of: shiftToggle) {
            UserDefaults.standard.set(shiftToggle, forKey: Prefs.shiftFixEnabled)
            interceptor.setEnableShiftFix(shiftToggle)
        }
        .onChange(of: openAtLoginPreference) {
            do {
                try LaunchAtLogin.set(enabled: openAtLoginPreference)
            } catch {
                print(error)
            }
        }
        .menuBarExtraStyle(.window)
    }
}

func openAccessibilitySettings() {
    if let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    ) {
        NSWorkspace.shared.open(url)
    }
}

final class LaunchAtLogin {
    static var isEnabled: Bool {
        return SMAppService.mainApp.status == .enabled
    }

    static func set(enabled: Bool) throws {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status == .notFound { return }
                try SMAppService.mainApp.unregister()
            }
        } catch {
            throw TakeCtrlError.failedLaunchAtLoginToggle
        }
    }
}
