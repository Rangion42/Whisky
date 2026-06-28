//
//  BottleSettings.swift
//  WhiskyKit
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

import Foundation
import SemanticVersion
import os.log

public struct PinnedProgram: Codable, Hashable, Equatable {
    public var name: String
    public var url: URL?
    public var removable: Bool

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
        do {
            let volume = try url.resourceValues(forKeys: [.volumeURLKey]).volume
            self.removable = try !(volume?.resourceValues(forKeys: [.volumeIsInternalKey]).volumeIsInternal ?? false)
        } catch {
            self.removable = false
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.url = try container.decodeIfPresent(URL.self, forKey: .url)
        self.removable = try container.decodeIfPresent(Bool.self, forKey: .removable) ?? false
    }
}

public struct BottleInfo: Codable, Equatable {
    var name: String = "Bottle"
    var pins: [PinnedProgram] = []
    var blocklist: [URL] = []

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Bottle"
        self.pins = try container.decodeIfPresent([PinnedProgram].self, forKey: .pins) ?? []
        self.blocklist = try container.decodeIfPresent([URL].self, forKey: .blocklist) ?? []
    }
}

public enum WinVersion: String, CaseIterable, Codable, Sendable {
    case winXP = "winxp64"
    case win7 = "win7"
    case win8 = "win8"
    case win81 = "win81"
    case win10 = "win10"
    case win11 = "win11"

    public func pretty() -> String {
        switch self {
        case .winXP:
            return "Windows XP"
        case .win7:
            return "Windows 7"
        case .win8:
            return "Windows 8"
        case .win81:
            return "Windows 8.1"
        case .win10:
            return "Windows 10"
        case .win11:
            return "Windows 11"
        }
    }
}

public enum EnhancedSync: Codable, Equatable {
    case none, esync, msync
}

public struct BottleWineConfig: Codable, Equatable {
    static let defaultWineVersion = SemanticVersion(7, 7, 0)
    var wineVersion: SemanticVersion = Self.defaultWineVersion
    var windowsVersion: WinVersion = .win10
    var enhancedSync: EnhancedSync = .msync
    var avxEnabled: Bool = false

    public init() {}

    // swiftlint:disable line_length
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.wineVersion = try container.decodeIfPresent(SemanticVersion.self, forKey: .wineVersion) ?? Self.defaultWineVersion
        self.windowsVersion = try container.decodeIfPresent(WinVersion.self, forKey: .windowsVersion) ?? .win10
        self.enhancedSync = try container.decodeIfPresent(EnhancedSync.self, forKey: .enhancedSync) ?? .msync
        self.avxEnabled = try container.decodeIfPresent(Bool.self, forKey: .avxEnabled) ?? false
    }
    // swiftlint:enable line_length
}

public struct BottleMetalConfig: Codable, Equatable {
    var metalHud: Bool = false
    var metalTrace: Bool = false
    var dxrEnabled: Bool = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.metalHud = try container.decodeIfPresent(Bool.self, forKey: .metalHud) ?? false
        self.metalTrace = try container.decodeIfPresent(Bool.self, forKey: .metalTrace) ?? false
        self.dxrEnabled = try container.decodeIfPresent(Bool.self, forKey: .dxrEnabled) ?? false
    }
}

public enum GPTKPerformanceMode: String, Codable, Equatable {
    case balanced = "balanced"
    case performance = "performance"
    case quality = "quality"

    public var description: String {
        switch self {
        case .balanced: return "config.gptk.perf.balanced"
        case .performance: return "config.gptk.perf.performance"
        case .quality: return "config.gptk.perf.quality"
        }
    }
}

public enum GPTKShaderCacheMode: String, Codable, Equatable {
    case disabled = "disabled"
    case compileOnLaunch = "compileOnLaunch"
    case prewarm = "prewarm"

    public var description: String {
        switch self {
        case .disabled: return "config.gptk.shader.disabled"
        case .compileOnLaunch: return "config.gptk.shader.compileOnLaunch"
        case .prewarm: return "config.gptk.shader.prewarm"
        }
    }
}

public enum GPTKMemoryMode: String, Codable, Equatable {
    case auto = "auto"
    case limited = "limited"

    public var description: String {
        switch self {
        case .auto: return "config.gptk.memory.auto"
        case .limited: return "config.gptk.memory.limited"
        }
    }
}

public struct BottleGptkConfig: Codable, Equatable {
    var enabled: Bool = false

    // VKD3D support for D3D12 → Vulkan translation
    var vkd3dEnabled: Bool = true
    var vkd3dDebug: String = ""
    var vkd3dProfile: String = "auto"

    // Shader compilation management
    var shaderCacheEnabled: Bool = true
    var shaderCacheMode: GPTKShaderCacheMode = .compileOnLaunch

    // Performance presets
    var performanceMode: GPTKPerformanceMode = .balanced

    // Memory management
    var memoryMode: GPTKMemoryMode = .auto
    var memoryLimitMB: Int?

    // Game compatibility notes (game name → note)
    var gameCompatibilityNotes: [String: String] = [:]

    // Game type presets (game name → preset)
    var gamePresets: [String: GPTKPerformanceMode] = [:]

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        self.vkd3dEnabled = try container.decodeIfPresent(Bool.self, forKey: .vkd3dEnabled) ?? true
        self.vkd3dDebug = try container.decodeIfPresent(String.self, forKey: .vkd3dDebug) ?? ""
        self.vkd3dProfile = try container.decodeIfPresent(String.self, forKey: .vkd3dProfile) ?? "auto"
        self.shaderCacheEnabled = try container.decodeIfPresent(Bool.self, forKey: .shaderCacheEnabled) ?? true
        self.shaderCacheMode = try container.decodeIfPresent(GPTKShaderCacheMode.self, forKey: .shaderCacheMode) ?? .compileOnLaunch
        self.performanceMode = try container.decodeIfPresent(GPTKPerformanceMode.self, forKey: .performanceMode) ?? .balanced
        self.memoryMode = try container.decodeIfPresent(GPTKMemoryMode.self, forKey: .memoryMode) ?? .auto
        self.memoryLimitMB = try container.decodeIfPresent(Int.self, forKey: .memoryLimitMB)
        self.gameCompatibilityNotes = try container.decodeIfPresent([String: String].self, forKey: .gameCompatibilityNotes) ?? [:]
        self.gamePresets = try container.decodeIfPresent([String: GPTKPerformanceMode].self, forKey: .gamePresets) ?? [:]
    }

    /// Get the performance mode for a specific game by name
    public func performanceMode(forGame gameName: String) -> GPTKPerformanceMode {
        return gamePresets[gameName] ?? performanceMode
    }

    /// Get the compatibility note for a specific game by name
    public func compatibilityNote(forGame gameName: String) -> String? {
        return gameCompatibilityNotes[gameName]
    }

    /// Add or update a compatibility note for a game
    public mutating func setCompatibilityNote(_ note: String, forGame gameName: String) {
        gameCompatibilityNotes[gameName] = note
    }

    /// Remove a compatibility note for a game
    public mutating func removeCompatibilityNote(forGame gameName: String) {
        gameCompatibilityNotes.removeValue(forKey: gameName)
    }

    /// Set the performance preset for a specific game
    public mutating func setGamePreset(_ mode: GPTKPerformanceMode, forGame gameName: String) {
        gamePresets[gameName] = mode
    }

    /// Remove the preset for a specific game (falls back to bottle default)
    public mutating func removeGamePreset(forGame gameName: String) {
        gamePresets.removeValue(forKey: gameName)
    }
}

public enum DXVKHUD: Codable, Equatable {
    case full, partial, fps, off
}

public struct BottleDXVKConfig: Codable, Equatable {
    var dxvk: Bool = false
    var dxvkAsync: Bool = true
    var dxvkHud: DXVKHUD = .off

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dxvk = try container.decodeIfPresent(Bool.self, forKey: .dxvk) ?? false
        self.dxvkAsync = try container.decodeIfPresent(Bool.self, forKey: .dxvkAsync) ?? true
        self.dxvkHud = try container.decodeIfPresent(DXVKHUD.self, forKey: .dxvkHud) ?? .off
    }
}

public struct BottleSettings: Codable, Equatable {
    static let defaultFileVersion = SemanticVersion(1, 0, 0)

    var fileVersion: SemanticVersion = Self.defaultFileVersion
    private var info: BottleInfo
    private var wineConfig: BottleWineConfig
    private var metalConfig: BottleMetalConfig
    private var dxvkConfig: BottleDXVKConfig
    private var _gptkConfig: BottleGptkConfig

    enum CodingKeys: String, CodingKey {
        case fileVersion
        case info
        case wineConfig
        case metalConfig
        case dxvkConfig
        // Map the plist key "gptkConfig" to the stored property _gptkConfig
        case _gptkConfig = "gptkConfig"
    }

    public init() {
        self.info = BottleInfo()
        self.wineConfig = BottleWineConfig()
        self.metalConfig = BottleMetalConfig()
        self.dxvkConfig = BottleDXVKConfig()
        self._gptkConfig = BottleGptkConfig()
    }

    // swiftlint:disable line_length
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fileVersion = try container.decodeIfPresent(SemanticVersion.self, forKey: .fileVersion) ?? Self.defaultFileVersion
        self.info = try container.decodeIfPresent(BottleInfo.self, forKey: .info) ?? BottleInfo()
        self.wineConfig = try container.decodeIfPresent(BottleWineConfig.self, forKey: .wineConfig) ?? BottleWineConfig()
        self.metalConfig = try container.decodeIfPresent(BottleMetalConfig.self, forKey: .metalConfig) ?? BottleMetalConfig()
        self.dxvkConfig = try container.decodeIfPresent(BottleDXVKConfig.self, forKey: .dxvkConfig) ?? BottleDXVKConfig()
        self._gptkConfig = try container.decodeIfPresent(BottleGptkConfig.self, forKey: ._gptkConfig) ?? BottleGptkConfig()
    }
    // swiftlint:enable line_length

    /// The name of this bottle
    public var name: String {
        get { return info.name }
        set { info.name = newValue }
    }

    /// The version of wine used by this bottle
    public var wineVersion: SemanticVersion {
        get { return wineConfig.wineVersion }
        set { wineConfig.wineVersion = newValue }
    }

    /// The version of windows used by this bottle
    public var windowsVersion: WinVersion {
        get { return wineConfig.windowsVersion }
        set { wineConfig.windowsVersion = newValue }
    }

    public var avxEnabled: Bool {
        get { return wineConfig.avxEnabled }
        set { wineConfig.avxEnabled = newValue }
    }

    /// The pinned programs on this bottle
    public var pins: [PinnedProgram] {
        get { return info.pins }
        set { info.pins = newValue }
    }

    /// The blocked applicaitons on this bottle
    public var blocklist: [URL] {
        get { return info.blocklist }
        set { info.blocklist = newValue }
    }

    public var enhancedSync: EnhancedSync {
        get { return wineConfig.enhancedSync }
        set { wineConfig.enhancedSync = newValue }
    }

    public var metalHud: Bool {
        get { return metalConfig.metalHud }
        set { metalConfig.metalHud = newValue }
    }

    public var metalTrace: Bool {
        get { return metalConfig.metalTrace }
        set { metalConfig.metalTrace = newValue }
    }

    public var dxrEnabled: Bool {
        get { return metalConfig.dxrEnabled }
        set { metalConfig.dxrEnabled = newValue }
    }

    public var dxvk: Bool {
        get { return dxvkConfig.dxvk }
        set { dxvkConfig.dxvk = newValue }
    }

    public var dxvkAsync: Bool {
        get { return dxvkConfig.dxvkAsync }
        set { dxvkConfig.dxvkAsync = newValue }
    }

    public var dxvkHud: DXVKHUD {
        get {  return dxvkConfig.dxvkHud }
        set { dxvkConfig.dxvkHud = newValue }
    }

    public var gptkEnabled: Bool {
        get { return gptkConfig.enabled }
        set { _gptkConfig.enabled = newValue }
    }

    // MARK: - GPTK Configuration Properties

    public var vkd3dEnabled: Bool {
        get { return _gptkConfig.vkd3dEnabled }
        set { _gptkConfig.vkd3dEnabled = newValue }
    }

    public var vkd3dDebug: String {
        get { return _gptkConfig.vkd3dDebug }
        set { _gptkConfig.vkd3dDebug = newValue }
    }

    public var vkd3dProfile: String {
        get { return _gptkConfig.vkd3dProfile }
        set { _gptkConfig.vkd3dProfile = newValue }
    }

    public var shaderCacheEnabled: Bool {
        get { return _gptkConfig.shaderCacheEnabled }
        set { _gptkConfig.shaderCacheEnabled = newValue }
    }

    public var shaderCacheMode: GPTKShaderCacheMode {
        get { return _gptkConfig.shaderCacheMode }
        set { _gptkConfig.shaderCacheMode = newValue }
    }

    public var performanceMode: GPTKPerformanceMode {
        get { return _gptkConfig.performanceMode }
        set { _gptkConfig.performanceMode = newValue }
    }

    public var memoryMode: GPTKMemoryMode {
        get { return _gptkConfig.memoryMode }
        set { _gptkConfig.memoryMode = newValue }
    }

    public var memoryLimitMB: Int? {
        get { return _gptkConfig.memoryLimitMB }
        set { _gptkConfig.memoryLimitMB = newValue }
    }

    /// Expose the GPTK config for read-only access (e.g., game presets, compatibility notes)
    public var gptkConfig: BottleGptkConfig {
        get { return _gptkConfig }
    }

    /// Get the performance mode for a specific game by name
    public func performanceMode(forGame gameName: String) -> GPTKPerformanceMode {
        return _gptkConfig.performanceMode(forGame: gameName)
    }

    /// Get the compatibility note for a specific game by name
    public func compatibilityNote(forGame gameName: String) -> String? {
        return _gptkConfig.compatibilityNote(forGame: gameName)
    }

    /// Add or update a compatibility note for a game
    public mutating func setCompatibilityNote(_ note: String, forGame gameName: String) {
        _gptkConfig.setCompatibilityNote(note, forGame: gameName)
    }

    /// Remove a compatibility note for a game
    public mutating func removeCompatibilityNote(forGame gameName: String) {
        _gptkConfig.removeCompatibilityNote(forGame: gameName)
    }

    /// Set the performance preset for a specific game
    public mutating func setGamePreset(_ mode: GPTKPerformanceMode, forGame gameName: String) {
        _gptkConfig.setGamePreset(mode, forGame: gameName)
    }

    /// Remove the preset for a specific game (falls back to bottle default)
    public mutating func removeGamePreset(forGame gameName: String) {
        _gptkConfig.removeGamePreset(forGame: gameName)
    }

    @discardableResult
    public static func decode(from metadataURL: URL) throws -> BottleSettings {
        guard FileManager.default.fileExists(atPath: metadataURL.path(percentEncoded: false)) else {
            let decoder = PropertyListDecoder()
            let settings = try decoder.decode(BottleSettings.self, from: Data(contentsOf: metadataURL))
            try settings.encode(to: metadataURL)
            return settings
        }

        let decoder = PropertyListDecoder()
        let data = try Data(contentsOf: metadataURL)
        var settings = try decoder.decode(BottleSettings.self, from: data)

        guard settings.fileVersion == BottleSettings.defaultFileVersion else {
            Logger.wineKit.warning("Invalid file version `\(settings.fileVersion)`")
            settings = BottleSettings()
            try settings.encode(to: metadataURL)
            return settings
        }

        if settings.wineConfig.wineVersion != BottleWineConfig().wineVersion {
            Logger.wineKit.warning("Bottle has a different wine version `\(settings.wineConfig.wineVersion)`")
            settings.wineConfig.wineVersion = BottleWineConfig().wineVersion
            try settings.encode(to: metadataURL)
            return settings
        }

        return settings
    }

    func encode(to metadataUrl: URL) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(self)
        try data.write(to: metadataUrl)
    }

    // swiftlint:disable:next cyclomatic_complexity
    public func environmentVariables(wineEnv: inout [String: String]) {
        if dxvk {
            wineEnv.updateValue("dxgi,d3d9,d3d10core,d3d11=n,b", forKey: "WINEDLLOVERRIDES")
            switch dxvkHud {
            case .full:
                wineEnv.updateValue("full", forKey: "DXVK_HUD")
            case .partial:
                wineEnv.updateValue("devinfo,fps,frametimes", forKey: "DXVK_HUD")
            case .fps:
                wineEnv.updateValue("fps", forKey: "DXVK_HUD")
            case .off:
                break
            }
        }

        if dxvkAsync {
            wineEnv.updateValue("1", forKey: "DXVK_ASYNC")
        }

        switch enhancedSync {
        case .none:
            break
        case .esync:
            wineEnv.updateValue("1", forKey: "WINEESYNC")
        case .msync:
            wineEnv.updateValue("1", forKey: "WINEMSYNC")
            // D3DM detects ESYNC and changes behaviour accordingly
            // so we have to lie to it so that it doesn't break
            // under MSYNC. Values hardcoded in lid3dshared.dylib
            wineEnv.updateValue("1", forKey: "WINEESYNC")
        }

        if metalHud {
            wineEnv.updateValue("1", forKey: "MTL_HUD_ENABLED")
        }

        if metalTrace {
            wineEnv.updateValue("1", forKey: "METAL_CAPTURE_ENABLED")
        }

        if avxEnabled {
            wineEnv.updateValue("1", forKey: "ROSETTA_ADVERTISE_AVX")
        }

        if dxrEnabled {
            wineEnv.updateValue("1", forKey: "D3DM_SUPPORT_DXR")
        }

        // MARK: - GPTK Environment Variables (only when GPTK is enabled)
        if gptkEnabled {
            // VKD3D for D3D12 → Vulkan translation
            if vkd3dEnabled {
                // Merge with existing WINEDLLOVERRIDES instead of overwriting (fixes DXVK collision)
                let existingOverrides = wineEnv["WINEDLLOVERRIDES"] ?? ""
                let vkd3dOverride = "d3d12=n,b"
                if !existingOverrides.contains(vkd3dOverride) {
                    let merged = existingOverrides.isEmpty ? vkd3dOverride : "\(existingOverrides),\(vkd3dOverride)"
                    wineEnv.updateValue(merged, forKey: "WINEDLLOVERRIDES")
                }
                if !vkd3dDebug.isEmpty {
                    wineEnv.updateValue(vkd3dDebug, forKey: "VKD3D_DEBUG")
                }
                if vkd3dProfile != "auto" {
                    wineEnv.updateValue(vkd3dProfile, forKey: "VKD3D_CONFIG")
                }
            }

            // Shader cache mode controls how GPTK handles shader compilation
            switch shaderCacheMode {
            case .disabled:
                wineEnv.updateValue("0", forKey: "GPTK_SHADER_CACHE")
            case .prewarm:
                wineEnv.updateValue("2", forKey: "GPTK_SHADER_CACHE")
            case .compileOnLaunch:
                wineEnv.updateValue("1", forKey: "GPTK_SHADER_CACHE")
            }

            // Performance mode presets GPU/CPU resource allocation
            switch performanceMode {
            case .balanced:
                // Default behavior - no special env vars needed
                break
            case .performance:
                wineEnv.updateValue("1", forKey: "GPTK_PERF_MODE")
                // Prioritize GPU over CPU for frame generation
                wineEnv.updateValue("gpu", forKey: "GPTK_PRIORITY")
            case .quality:
                wineEnv.updateValue("2", forKey: "GPTK_PERF_MODE")
                // Prioritize visual quality over raw speed
                wineEnv.updateValue("quality", forKey: "GPTK_PRIORITY")
            }

            // Memory management for GPTK wine processes
            switch memoryMode {
            case .auto:
                // Let GPTK manage memory automatically
                break
            case .limited:
                if let limitMB = memoryLimitMB, limitMB > 0 {
                    wineEnv.updateValue(String(limitMB), forKey: "GPTK_MEMORY_LIMIT_MB")
                }
            }
        }
    }
}
