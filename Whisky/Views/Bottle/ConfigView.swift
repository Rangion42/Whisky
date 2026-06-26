//
//  ConfigView.swift
//  Whisky
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import SwiftUI
import WhiskyKit

enum LoadingState {
    case loading
    case modifying
    case success
    case failed
}

struct ConfigView: View {
    @ObservedObject var bottle: Bottle
    @State private var buildVersion: Int = 0
    @State private var retinaMode: Bool = false
    @State private var dpiConfig: Int = 96
    @State private var winVersionLoadingState: LoadingState = .loading
    @State private var buildVersionLoadingState: LoadingState = .loading
    @State private var retinaModeLoadingState: LoadingState = .loading
    @State private var dpiConfigLoadingState: LoadingState = .loading
    @State private var dpiSheetPresented: Bool = false
    @AppStorage("wineSectionExpanded") private var wineSectionExpanded: Bool = true
    @AppStorage("dxvkSectionExpanded") private var dxvkSectionExpanded: Bool = true
    @AppStorage("metalSectionExpanded") private var metalSectionExpanded: Bool = true
    @AppStorage("gptkSectionExpanded") private var gptkSectionExpanded: Bool = true

    // GPTK state
    @State private var gptkVersion: String? = nil
    @State private var updateInfo: GPTKUpdateInfo? = nil
    @State private var performanceMetrics: Wine.PerformanceMetrics? = nil
    @State private var shaderStatus: Wine.ShaderCompilationStatus = .init()
    @State private var metricsTimer: Timer? = nil

    var body: some View {
        Form {
            Section("config.title.wine", isExpanded: $wineSectionExpanded) {
                SettingItemView(title: "config.winVersion", loadingState: winVersionLoadingState) {
                    Picker("config.winVersion", selection: $bottle.settings.windowsVersion) {
                        ForEach(WinVersion.allCases.reversed(), id: \.self) {
                            Text($0.pretty())
                        }
                    }
                }
                SettingItemView(title: "config.buildVersion", loadingState: buildVersionLoadingState) {
                    TextField("config.buildVersion", value: $buildVersion, formatter: NumberFormatter())
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            buildVersionLoadingState = .modifying
                            Task(priority: .userInitiated) {
                                do {
                                    try await Wine.changeBuildVersion(bottle: bottle, version: buildVersion)
                                    buildVersionLoadingState = .success
                                } catch {
                                    print("Failed to change build version")
                                    buildVersionLoadingState = .failed
                                }
                            }
                        }
                }
                SettingItemView(title: "config.retinaMode", loadingState: retinaModeLoadingState) {
                    Toggle("config.retinaMode", isOn: $retinaMode)
                        .onChange(of: retinaMode, { _, newValue in
                            Task(priority: .userInitiated) {
                                retinaModeLoadingState = .modifying
                                do {
                                    try await Wine.changeRetinaMode(bottle: bottle, retinaMode: newValue)
                                    retinaModeLoadingState = .success
                                } catch {
                                    print("Failed to change build version")
                                    retinaModeLoadingState = .failed
                                }
                            }
                        })
                }
                Picker("config.enhancedSync", selection: $bottle.settings.enhancedSync) {
                    Text("config.enhancedSync.none").tag(EnhancedSync.none)
                    Text("config.enhacnedSync.esync").tag(EnhancedSync.esync)
                    Text("config.enhacnedSync.msync").tag(EnhancedSync.msync)
                }
                SettingItemView(title: "config.dpi", loadingState: dpiConfigLoadingState) {
                    Button("config.inspect") {
                        dpiSheetPresented = true
                    }
                    .sheet(isPresented: $dpiSheetPresented) {
                        DPIConfigSheetView(
                            dpiConfig: $dpiConfig,
                            isRetinaMode: $retinaMode,
                            presented: $dpiSheetPresented
                        )
                    }
                }
                if #available(macOS 15, *) {
                    Toggle(isOn: $bottle.settings.avxEnabled) {
                        VStack(alignment: .leading) {
                            Text("config.avx")
                            if bottle.settings.avxEnabled {
                                HStack(alignment: .firstTextBaseline) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .symbolRenderingMode(.multicolor)
                                        .font(.subheadline)
                                    Text("config.avx.warning")
                                        .fontWeight(.light)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
            }
            Section("config.title.dxvk", isExpanded: $dxvkSectionExpanded) {
                Toggle(isOn: $bottle.settings.dxvk) {
                    Text("config.dxvk")
                    if bottle.settings.gptkEnabled {
                        Text("config.dxvk.gptkDisabled")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .disabled(bottle.settings.gptkEnabled)
                Toggle(isOn: $bottle.settings.dxvkAsync) {
                    Text("config.dxvk.async")
                }
                .disabled(!bottle.settings.dxvk || bottle.settings.gptkEnabled)
                Picker("config.dxvkHud", selection: $bottle.settings.dxvkHud) {
                    Text("config.dxvkHud.full").tag(DXVKHUD.full)
                    Text("config.dxvkHud.partial").tag(DXVKHUD.partial)
                    Text("config.dxvkHud.fps").tag(DXVKHUD.fps)
                    Text("config.dxvkHud.off").tag(DXVKHUD.off)
                }
                .disabled(!bottle.settings.dxvk || bottle.settings.gptkEnabled)
            }
            Section("config.title.metal", isExpanded: $metalSectionExpanded) {
                Toggle(isOn: $bottle.settings.gptkEnabled) {
                    Text("config.gptk")
                    if !Wine.gptkWineBinaryExists() {
                        Text("config.gptk.notFound")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("config.gptk.found")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                Toggle(isOn: $bottle.settings.metalHud) {
                    Text("config.metalHud")
                }
                Toggle(isOn: $bottle.settings.metalTrace) {
                    Text("config.metalTrace")
                    Text("config.metalTrace.info")
                }
                if let device = MTLCreateSystemDefaultDevice() {
                    // Represents the Apple family 9 GPU features that correspond to the Apple A17, M3, and M4 GPUs.
                    if device.supportsFamily(.apple9) {
                        Toggle(isOn: $bottle.settings.dxrEnabled) {
                            Text("config.dxr")
                            Text("config.dxr.info")
                        }
                    }
                }
            }

            // MARK: - GPTK Section
            Section("config.title.gptk", isExpanded: $gptkSectionExpanded) {
                // Version info
                if let version = gptkVersion {
                    HStack {
                        Text("config.gptk.version")
                        Spacer()
                        Text(version)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Text("config.gptk.version")
                        Spacer()
                        ProgressView().controlSize(.small)
                    }
                }

                // Update check
                if let update = updateInfo {
                    HStack {
                        Text("config.gptk.update")
                        Spacer()
                        if update.needsUpdate {
                            Label("config.gptk.update.available", systemImage: "arrow.down.circle")
                                .foregroundStyle(.orange)
                        } else {
                            Label("config.gptk.update.current", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }

                // VKD3D Settings
                Toggle(isOn: $bottle.settings.vkd3dEnabled) {
                    Text("config.gptk.vkd3d")
                    if !bottle.settings.gptkEnabled {
                        Text("config.gptk.vkd3d.info")
                            .font(.caption)
                    }
                }
                .disabled(!bottle.settings.gptkEnabled)

                if bottle.settings.vkd3dEnabled {
                    TextField("config.gptk.vkd3d.debug.placeholder", text: $bottle.settings.vkd3dDebug)
                        .disabled(!bottle.settings.gptkEnabled)

                    Picker("config.gptk.vkd3d.profile", selection: $bottle.settings.vkd3dProfile) {
                        Text("config.gptk.vkd3d.profile.auto").tag("auto")
                        Text("config.gptk.vkd3d.profile.zink").tag("zink")
                        Text("config.gptk.vkd3d.profile.radv").tag("radv")
                        Text("config.gptk.vkd3d.profile.custom").tag("custom")
                    }
                    .disabled(!bottle.settings.gptkEnabled)
                }

                // Shader Cache Settings
                Toggle(isOn: $bottle.settings.shaderCacheEnabled) {
                    Text("config.gptk.shader.cache")
                }
                .disabled(!bottle.settings.gptkEnabled)

                if bottle.settings.shaderCacheEnabled {
                    Picker("config.gptk.shader.mode", selection: $bottle.settings.shaderCacheMode) {
                        Text("config.gptk.shader.mode.disabled").tag(GPTKShaderCacheMode.disabled)
                        Text("config.gptk.shader.mode.compileOnLaunch").tag(GPTKShaderCacheMode.compileOnLaunch)
                        Text("config.gptk.shader.mode.prewarm").tag(GPTKShaderCacheMode.prewarm)
                    }
                    .disabled(!bottle.settings.gptkEnabled)

                    // Shader compilation progress indicator
                    if shaderStatus.isCompiling {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: shaderStatus.progressPercent)
                            Text(String(format: "config.gptk.shader.progress", Int(shaderStatus.progressPercent)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if shaderStatus.state == .error {
                        Text(shaderStatus.errorMessage ?? "config.gptk.shader.error.unknown")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if shaderStatus.state == .complete {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(String(format: "config.gptk.shader.complete", shaderStatus.compiledShaders))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Performance Mode
                Picker("config.gptk.perf.mode", selection: $bottle.settings.performanceMode) {
                    Text("config.gptk.perf.mode.balanced").tag(GPTKPerformanceMode.balanced)
                    Text("config.gptk.perf.mode.performance").tag(GPTKPerformanceMode.performance)
                    Text("config.gptk.perf.mode.quality").tag(GPTKPerformanceMode.quality)
                }
                .disabled(!bottle.settings.gptkEnabled)

                // Memory Management
                Picker("config.gptk.memory.mode", selection: $bottle.settings.memoryMode) {
                    Text("config.gptk.memory.mode.auto").tag(GPTKMemoryMode.auto)
                    Text("config.gptk.memory.mode.limited").tag(GPTKMemoryMode.limited)
                }
                .disabled(!bottle.settings.gptkEnabled)

                if bottle.settings.memoryMode == .limited {
                    HStack {
                        Text("config.gptk.memory.limit")
                        TextField("", value: $bottle.settings.memoryLimitMB!, format: .number)
                            .frame(width: 80)
                    }
                    .disabled(!bottle.settings.gptkEnabled)
                }

                // Performance Metrics (live)
                if bottle.settings.gptkEnabled {
                    Button("config.gptk.metrics.refresh") {
                        Task(priority: .userInitiated) {
                            performanceMetrics = await Wine.capturePerformanceMetrics(for: bottle)
                        }
                    }

                    if let metrics = performanceMetrics {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("config.gptk.metrics.gpu")
                                Spacer()
                                Text(String(format: "%.1f%%", metrics.gpuUsage))
                                    .font(.system(.body, design: .monospaced))
                            }
                            HStack {
                                Text("config.gptk.metrics.cpu")
                                Spacer()
                                Text(String(format: "%.1f%%", metrics.cpuUsage))
                                    .font(.system(.body, design: .monospaced))
                            }
                            HStack {
                                Text("config.gptk.metrics.memory")
                                Spacer()
                                Text(String(format: "%.0f MB", metrics.memoryUsageMB))
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                }

                // Game Compatibility Notes (placeholder - full implementation in game list)
                if !bottle.settings.gptkConfig.gameCompatibilityNotes.isEmpty {
                    Text(String(format: "config.gptk.compat.notes.count", bottle.settings.gptkConfig.gameCompatibilityNotes.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Game Presets (placeholder - full implementation in game list)
                if !bottle.settings.gptkConfig.gamePresets.isEmpty {
                    Text(String(format: "config.gptk.presets.count", bottle.settings.gptkConfig.gamePresets.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Check for updates button
                Button("config.gptk.checkUpdates") {
                    Task(priority: .userInitiated) {
                        do {
                            updateInfo = try await Wine.checkGptkUpdate()
                        } catch {
                            print("Failed to check for GPTK updates: \(error)")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .animation(.whiskyDefault, value: wineSectionExpanded)
        .animation(.whiskyDefault, value: dxvkSectionExpanded)
        .animation(.whiskyDefault, value: metalSectionExpanded)
        .animation(.whiskyDefault, value: gptkSectionExpanded)
        .bottomBar {
            HStack {
                Spacer()
                Button("config.controlPanel") {
                    Task(priority: .userInitiated) {
                        do {
                            try await Wine.control(bottle: bottle)
                        } catch {
                            print("Failed to launch control")
                        }
                    }
                }
                Button("config.regedit") {
                    Task(priority: .userInitiated) {
                        do {
                            try await Wine.regedit(bottle: bottle)
                        } catch {
                            print("Failed to launch regedit")
                        }
                    }
                }
                Button("config.winecfg") {
                    Task(priority: .userInitiated) {
                        do {
                            try await Wine.cfg(bottle: bottle)
                        } catch {
                            print("Failed to launch winecfg")
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("tab.config")
        .onAppear {
            winVersionLoadingState = .success

            loadBuildName()

            Task(priority: .userInitiated) {
                do {
                    retinaMode = try await Wine.retinaMode(bottle: bottle)
                    retinaModeLoadingState = .success
                } catch {
                    print(error)
                    retinaModeLoadingState = .failed
                }
            }
            Task(priority: .userInitiated) {
                do {
                    dpiConfig = try await Wine.dpiResolution(bottle: bottle) ?? 0
                    dpiConfigLoadingState = .success
                } catch {
                    print(error)
                    // If DPI has not yet been edited, there will be no registry entry
                    dpiConfigLoadingState = .success
                }
            }

            // Load GPTK version and set up periodic metrics if enabled
            if bottle.settings.gptkEnabled {
                gptkVersion = Wine.gptkVersion()

                // Set up periodic performance metrics refresh (every 2 seconds)
                metricsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                    Task(priority: .userInitiated) {
                        performanceMetrics = await Wine.capturePerformanceMetrics(for: bottle)

                        // Update shader status from tracker
                        if let activeGame = Wine.shaderTracker.activeGames.first {
                            shaderStatus = Wine.shaderTracker.getStatus(forGame: activeGame)
                        } else {
                            // No active games, check if we should reset
                            if shaderStatus.isCompiling {
                                // Shader compilation may have completed when game exited
                                shaderStatus = Wine.shaderTracker.getStatus(forGame: "current")
                            }
                        }
                    }
                }
            }
        }
        .onDisappear {
            // Clean up timer
            metricsTimer?.invalidate()
            metricsTimer = nil
        }
        .onChange(of: bottle.settings.windowsVersion) { _, newValue in
            if winVersionLoadingState == .success {
                winVersionLoadingState = .loading
                buildVersionLoadingState = .loading
                Task(priority: .userInitiated) {
                    do {
                        try await Wine.changeWinVersion(bottle: bottle, win: newValue)
                        winVersionLoadingState = .success
                        bottle.settings.windowsVersion = newValue
                        loadBuildName()
                    } catch {
                        print(error)
                        winVersionLoadingState = .failed
                    }
                }
            }
        }
        .onChange(of: dpiConfig) {
            if dpiConfigLoadingState == .success {
                Task(priority: .userInitiated) {
                    dpiConfigLoadingState = .modifying
                    do {
                        try await Wine.changeDpiResolution(bottle: bottle, dpi: dpiConfig)
                        dpiConfigLoadingState = .success
                    } catch {
                        print(error)
                        dpiConfigLoadingState = .failed
                    }
                }
            }
        }
    }

    func loadBuildName() {
        Task(priority: .userInitiated) {
            do {
                if let buildVersionString = try await Wine.buildVersion(bottle: bottle) {
                    buildVersion = Int(buildVersionString) ?? 0
                } else {
                    buildVersion = 0
                }

                buildVersionLoadingState = .success
            } catch {
                print(error)
                buildVersionLoadingState = .failed
            }
        }
    }
}

struct DPIConfigSheetView: View {
    @Binding var dpiConfig: Int
    @Binding var isRetinaMode: Bool
    @Binding var presented: Bool
    @State var stagedChanges: Float
    @FocusState var textFocused: Bool

    init(dpiConfig: Binding<Int>, isRetinaMode: Binding<Bool>, presented: Binding<Bool>) {
        self._dpiConfig = dpiConfig
        self._isRetinaMode = isRetinaMode
        self._presented = presented
        self.stagedChanges = Float(dpiConfig.wrappedValue)
    }

    var body: some View {
        VStack {
            HStack {
                Text("configDpi.title")
                    .fontWeight(.bold)
                Spacer()
            }
            Divider()
            GroupBox(label: Label("configDpi.preview", systemImage: "text.magnifyingglass")) {
                VStack {
                    HStack {
                        Text("configDpi.previewText")
                            .padding(16)
                            .font(.system(size:
                                (10 * CGFloat(stagedChanges)) / 72 *
                                          (isRetinaMode ? 0.5 : 1)
                            ))
                        Spacer()
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: 80)
            }
            HStack {
                Slider(value: $stagedChanges, in: 96...480, step: 24, onEditingChanged: { _ in
                    textFocused = false
                })
                TextField(String(), value: $stagedChanges, format: .number)
                    .frame(width: 40)
                    .focused($textFocused)
                Text("configDpi.dpi")
            }
            Spacer()
            HStack {
                Spacer()
                Button("create.cancel") {
                    presented = false
                }
                .keyboardShortcut(.cancelAction)
                Button("button.ok") {
                    dpiConfig = Int(stagedChanges)
                    presented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: ViewWidth.medium, height: 240)
    }
}

struct SettingItemView<Content: View>: View {
    let title: String.LocalizationValue
    let loadingState: LoadingState
    @ViewBuilder var content: () -> Content

    @Namespace private var viewId
    @Namespace private var progressViewId

    var body: some View {
        HStack {
            Text(String(localized: title))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                switch loadingState {
                case .loading, .modifying:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .matchedGeometryEffect(id: progressViewId, in: viewId)
                case .success:
                    content()
                        .labelsHidden()
                        .disabled(loadingState != .success)
                case .failed:
                    Text("config.notAvailable")
                        .font(.caption).foregroundStyle(.red)
                        .multilineTextAlignment(.trailing)
                }
            }.animation(.default, value: loadingState)
        }
    }
}
