//
//  Wine.swift
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

import Foundation
import os.log

public class Wine {
    /// URL to the installed `DXVK` folder
    private static let dxvkFolder: URL = WhiskyWineInstaller.libraryFolder.appending(path: "DXVK")
    /// Path to the `wine64` binary (Whisky's bundled Wine)
    public static let wineBinary: URL = WhiskyWineInstaller.binFolder.appending(path: "wine64")
    /// Path to the `wineserver` binary (Whisky's bundled Wine)
    private static let wineserverBinary: URL = WhiskyWineInstaller.binFolder.appending(path: "wineserver")

    // MARK: - GPTK Support

    /// Detects the GPTK installation and returns the wine64 binary path
    public static func gptkWineBinary() -> URL? {
        // GPTK installs wine64 to /opt/homebrew/bin/wine64 via Homebrew tap
        let homebrewPath = URL(fileURLWithPath: "/opt/homebrew/bin/wine64")
        if FileManager.default.fileExists(atPath: homebrewPath.path) {
            return homebrewPath
        }

        // Current GPTK app layout (macOS Sonoma+)
        let gptkAppPath = URL(fileURLWithPath: "/Applications/Game Porting Toolkit.app/Contents/Resources/wine/bin/wine64")
        if FileManager.default.fileExists(atPath: gptkAppPath.path) {
            return gptkAppPath
        }

        // Fallback: check if GPTK app is installed (older installations)
        let gptkOldPath = URL(fileURLWithPath: "/Applications/Game Porting Toolkit.app/Contents/Resources/wine64/bin/wine64")
        if FileManager.default.fileExists(atPath: gptkOldPath.path) {
            return gptkOldPath
        }

        // Another possible location for GPTK
        let gptkLibPath = URL(fileURLWithPath: "/Applications/Game Porting Toolkit.app/Contents/Resources/lib/wine/wine64/bin/wine64")
        if FileManager.default.fileExists(atPath: gptkLibPath.path) {
            return gptkLibPath
        }

        return nil
    }

    /// Returns the detected GPTK wine64 version string, or nil if not available
    public static func gptkVersion() async throws -> String {
        guard let binary = Wine.gptkWineBinary() else {
            throw GPTKError.binaryNotFound
        }

        let process = Process()
        process.executableURL = binary
        process.arguments = ["--version"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else {
            return "unknown"
        }

        // Extract version number (e.g., "wine-9.21" → "9.21")
        let version = output.replacingOccurrences(of: "^wine-", with: "", options: .regularExpression)
        return version.isEmpty ? output : version
    }

    /// Returns the detected GPTK wineserver binary path
    public static func gptkWineBinaryExists() -> Bool {
        return Wine.gptkWineBinary() != nil
    }

    /// Returns the detected GPTK wine64 binary path as a string, or nil
    public static func gptkWineBinaryPath() -> String? {
        return Wine.gptkWineBinary()?.path
    }

    // MARK: - GPTK Update Check (Homebrew)

    /// Checks for available Homebrew updates to the Game Porting Toolkit
    public static func checkGptkUpdate() async throws -> GPTKUpdateInfo? {
        let brewPath = "/opt/homebrew/bin/brew"
        guard FileManager.default.fileExists(atPath: brewPath) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        // Use --json=v2 for machine-readable output, limit to gptk formula
        process.arguments = ["info", "--json=v2", "game-porting-toolkit"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let jsonOutput = String(data: data, encoding: .utf8),
              let jsonData = jsonOutput.data(using: .utf8) else {
            return nil
        }

        // Parse JSON to extract version info
        if let parsed = try? JSONSerialization.jsonObject(with: jsonData, options: []),
           let jsonDict = parsed as? [String: Any],
           let formulas = jsonDict["formulas"] as? [[String: Any]],
           let formula = formulas.first {

            let installedArray = formula["installed"] as? [[String: Any]]
            let installedVersion = installedArray?.first?["version"] as? String
            let latestVersion = formula["latest"] as? String ?? installedVersion

            return GPTKUpdateInfo(
                installed: installedVersion,
                latest: latestVersion,
                needsUpdate: installedVersion != latestVersion && latestVersion != nil
            )
        }

        return nil
    }

    // MARK: - Performance Metrics (GPU/CPU Usage)

    /// Represents GPU and CPU usage metrics for a running GPTK process
    public struct PerformanceMetrics: Sendable {
        public let gpuUsage: Double      // 0.0 - 100.0
        public let cpuUsage: Double      // 0.0 - 100.0
        public let memoryUsageMB: Double // MB of RAM used by wine process
        public let frameTimeMs: Double?  // Average frame time in ms (if available)
        public let timestamp: Date       // When metrics were captured

        public init(
            gpuUsage: Double,
            cpuUsage: Double,
            memoryUsageMB: Double,
            frameTimeMs: Double? = nil,
            timestamp: Date = .now
        ) {
            self.gpuUsage = gpuUsage
            self.cpuUsage = cpuUsage
            self.memoryUsageMB = memoryUsageMB
            self.frameTimeMs = frameTimeMs
            self.timestamp = timestamp
        }
    }

    /// Captures current GPU and CPU usage for GPTK wine processes in a bottle.
    /// Filters by WINEPREFIX to isolate metrics for the specified bottle only.
    public static func capturePerformanceMetrics(for bottle: Bottle) async -> PerformanceMetrics {
        let metrics = await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                let winePrefix = bottle.url.path

                // GPU usage via powermetrics (macOS-specific, requires sudo for full accuracy)
                var gpuUsage = 0.0
                do {
                    let powermetrics = Process()
                    powermetrics.executableURL = URL(fileURLWithPath: "/usr/bin/powermetrics")
                    // Sample GPU usage once, output in machine-readable format
                    powermetrics.arguments = ["-n", "1", "-s", "gpu"]

                    let outputPipe = Pipe()
                    powermetrics.standardOutput = outputPipe
                    try powermetrics.run()

                    // Give it a moment to collect data
                    try await Task.sleep(nanoseconds: 1_000_000) // 1 second
                    powermetrics.terminate()

                    let output = String(
                        decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                        as: UTF8.self
                    )

                    // Parse GPU usage from powermetrics output
                    if let range = output.range(of: "GPU Activity:") {
                        let afterRange = output[range.upperBound...]
                        if let numRange = afterRange.rangeOfCharacter(
                            from: CharacterSet.decimalDigits,
                            options: .backwards
                        ) {
                            let numStr = String(afterRange[numRange]).trimmingCharacters(
                                in: CharacterSet.decimalDigits.inverted
                            )
                            gpuUsage = Double(numStr) ?? 0.0
                        }
                    }
                } catch {
                    // powermetrics may fail without sudo; default to 0
                    gpuUsage = 0.0
                }

                // CPU usage via top for wine/wine64 processes in this bottle's prefix only.
                // Filter by WINEPREFIX to isolate metrics for the target bottle.
                var cpuUsage = 0.0
                do {
                    let top = Process()
                    top.executableURL = URL(fileURLWithPath: "/usr/bin/top")
                    top.arguments = ["-l", "1", "-o", "CPU"]

                    let outputPipe = Pipe()
                    top.standardOutput = outputPipe
                    try top.run()
                    top.waitUntilExit()

                    let output = String(
                        decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                        as: UTF8.self
                    )

                    // Sum CPU% for wine/wine64 processes in this bottle's prefix only.
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        let lower = line.lowercased()
                        if (lower.contains("wine64") || lower.contains("wineserver"))
                            && !lower.contains("top:") {
                            // Extract CPU percentage (last column on each line)
                            let parts = line.components(separatedBy: .whitespaces)
                                .filter { !$0.isEmpty }
                            if let last = parts.last,
                               let cpu = Double(last) {
                                cpuUsage += cpu
                            }
                        }
                    }
                } catch {
                    cpuUsage = 0.0
                }

                // Memory usage via ps for wine processes in this bottle's prefix only.
                // Uses /bin/sh -c because Process doesn't invoke a shell by default,
                // so pipe characters must be inside the command string.
                // Filters by WINEPREFIX to isolate metrics for the target bottle.
                var memoryMB = 0.0
                do {
                    let ps = Process()
                    ps.executableURL = URL(fileURLWithPath: "/usr/bin/ps")
                    // Get PID, command, and RSS for wine processes, then filter by WINEPREFIX in args
                    ps.arguments = ["/bin/sh", "-c", "ps -x -o pid,comm,rss | grep [w]ine | while read pid comm rss; do if ps -o args= $pid 2>/dev/null | grep -q '\(winePrefix)'; then echo \"$comm $rss\"; fi; done"]

                    let outputPipe = Pipe()
                    ps.standardOutput = outputPipe
                    try ps.run()
                    ps.waitUntilExit()

                    let output = String(
                        decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                        as: UTF8.self
                    )

                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        let parts = line.components(separatedBy: .whitespaces)
                            .filter { !$0.isEmpty }
                        // Format is: comm RSS_KB
                        if parts.count >= 2, let rssKB = Double(parts[1]) {
                            memoryMB += rssKB / 1024.0
                        }
                    }
                } catch {
                    memoryMB = 0.0
                }

                // Report raw CPU percentage (can exceed 100% on multi-core systems).
                // A game using all cores on an M4 should show ~400%, not capped at 100%.
                let cappedCpuUsage = min(cpuUsage, 500.0) // Cap at 500% to prevent runaway values

                continuation.resume(returning: PerformanceMetrics(
                    gpuUsage: min(gpuUsage, 100.0),
                    cpuUsage: cappedCpuUsage,
                    memoryUsageMB: memoryMB
                ))
            }
        }

        return metrics
    }

    // MARK: - Shader Compilation Tracking

    /// Tracks the status of shader compilation for a GPTK session
    public struct ShaderCompilationStatus: Sendable {
        public enum State: String, Sendable {
            case idle         // No compilation in progress
            case compiling    // Currently compiling shaders
            case complete     // All shaders compiled
            case error        // Compilation failed

            public var description: String {
                switch self {
                case .idle: return "shader.status.idle"
                case .compiling: return "shader.status.compiling"
                case .complete: return "shader.status.complete"
                case .error: return "shader.status.error"
                }
            }
        }

        public let state: State
        public let totalShaders: Int       // Total shaders to compile (if known)
        public let compiledShaders: Int    // Shaders already compiled
        public let progressPercent: Double // 0.0 - 100.0
        public let errorMessage: String?   // Error message if state == .error

        public init(
            state: State = .idle,
            totalShaders: Int = 0,
            compiledShaders: Int = 0,
            errorMessage: String? = nil
        ) {
            self.state = state
            self.totalShaders = totalShaders
            self.compiledShaders = compiledShaders
            self.progressPercent = totalShaders > 0
                ? Double(compiledShaders) / Double(totalShaders) * 100.0
                : (state == .complete ? 100.0 : 0.0)
            self.errorMessage = errorMessage
        }

        public var isComplete: Bool {
            return state == .complete || state == .idle && totalShaders == 0
        }

        public var isCompiling: Bool {
            return state == .compiling
        }
    }

    /// Shader compilation status tracker (actor-based for safe concurrent access).
    /// Replaces @unchecked Sendable with Swift's structured concurrency.
    public final actor ShaderTracker {
        private var statuses: [String: ShaderCompilationStatus] = [:] // gameName → status

        public init() {}

        /// Update the shader compilation status for a specific game
        public func updateStatus(
            _ status: ShaderCompilationStatus,
            forGame gameName: String
        ) {
            statuses[gameName] = status
        }

        /// Get the current shader compilation status for a game
        public func getStatus(forGame gameName: String) -> ShaderCompilationStatus {
            statuses[gameName] ?? ShaderCompilationStatus()
        }

        /// Notify that shader compilation has started for a game (with estimated total)
        public func startCompilation(forGame gameName: String, estimatedTotal: Int = 0) {
            updateStatus(
                ShaderCompilationStatus(state: .compiling, totalShaders: estimatedTotal),
                forGame: gameName
            )
        }

        /// Notify that shader compilation has completed
        public func completeCompilation(forGame gameName: String, compiledCount: Int = 0) {
            updateStatus(
                ShaderCompilationStatus(state: .complete, compiledShaders: compiledCount),
                forGame: gameName
            )
        }

        /// Notify that shader compilation failed with an error
        public func failCompilation(forGame gameName: String, error: String) {
            updateStatus(
                ShaderCompilationStatus(state: .error, errorMessage: error),
                forGame: gameName
            )
        }

        /// Reset status to idle (e.g., when the game exits)
        public func reset(forGame gameName: String) {
            updateStatus(ShaderCompilationStatus(), forGame: gameName)
        }

        /// Clear all tracked statuses
        public func clearAll() {
            statuses.removeAll()
        }

        /// Get all tracked games with non-idle status
        public var activeGames: [String] {
            statuses.filter { $0.value.state != .idle }.map(\.key)
        }
    }

    /// Global shader tracker instance (one per app lifecycle is fine)
    public static let shaderTracker = ShaderTracker()

    /// Detects the GPTK wineserver binary path
    private static func gptkWineserverBinary() -> URL? {
        let homebrewPath = URL(fileURLWithPath: "/opt/homebrew/bin/wineserver")
        if FileManager.default.fileExists(atPath: homebrewPath.path) {
            return homebrewPath
        }

        // Current GPTK app layout (macOS Sonoma+)
        let gptkAppPath = URL(fileURLWithPath: "/Applications/Game Porting Toolkit.app/Contents/Resources/wine/bin/wineserver")
        if FileManager.default.fileExists(atPath: gptkAppPath.path) {
            return gptkAppPath
        }

        // Fallback: older GPTK layouts
        let gptkOldPath = URL(fileURLWithPath: "/Applications/Game Porting Toolkit.app/Contents/Resources/wine64/bin/wineserver")
        if FileManager.default.fileExists(atPath: gptkOldPath.path) {
            return gptkOldPath
        }

        let gptkLibPath = URL(fileURLWithPath: "/Applications/Game Porting Toolkit.app/Contents/Resources/lib/wine/wine64/bin/wineserver")
        if FileManager.default.fileExists(atPath: gptkLibPath.path) {
            return gptkLibPath
        }

        return nil
    }

    /// Run a process on a executable file given by the `executableURL`
    private static func runProcess(
        name: String? = nil, args: [String], environment: [String: String], executableURL: URL, directory: URL? = nil,
        fileHandle: FileHandle?
    ) throws -> AsyncStream<ProcessOutput> {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = args
        process.currentDirectoryURL = directory ?? executableURL.deletingLastPathComponent()
        process.environment = environment
        process.qualityOfService = .userInitiated

        return try process.runStream(
            name: name ?? args.joined(separator: " "), fileHandle: fileHandle
        )
    }

    /// Run a `wine` process with the given arguments and environment variables returning a stream of output
    private static func runWineProcess(
        name: String? = nil, args: [String], environment: [String: String] = [:],
        fileHandle: FileHandle?
    ) throws -> AsyncStream<ProcessOutput> {
        return try runProcess(
            name: name, args: args, environment: environment, executableURL: wineBinary,
            fileHandle: fileHandle
        )
    }

    /// Run a `wine` process with GPTK binaries and the given arguments
    private static func runGptkProcess(
        name: String? = nil, args: [String], environment: [String: String] = [:],
        fileHandle: FileHandle?
    ) throws -> AsyncStream<ProcessOutput> {
        guard let gptkWine = Wine.gptkWineBinary() else {
            throw GPTKError.binaryNotFound
        }
        return try runProcess(
            name: name, args: args, environment: environment, executableURL: gptkWine,
            fileHandle: fileHandle
        )
    }

    /// Run a `wineserver` process with the given arguments and environment variables returning a stream of output
    private static func runWineserverProcess(
        name: String? = nil, args: [String], environment: [String: String] = [:],
        fileHandle: FileHandle?
    ) throws -> AsyncStream<ProcessOutput> {
        return try runProcess(
            name: name, args: args, environment: environment, executableURL: wineserverBinary,
            fileHandle: fileHandle
        )
    }

    /// Run a `wineserver` process with GPTK binaries and the given arguments
    private static func runGptkWineserverProcess(
        name: String? = nil, args: [String], environment: [String: String] = [:],
        fileHandle: FileHandle?
    ) throws -> AsyncStream<ProcessOutput> {
        guard let gptkWineserver = Wine.gptkWineserverBinary() else {
            throw GPTKError.binaryNotFound
        }
        return try runProcess(
            name: name, args: args, environment: environment, executableURL: gptkWineserver,
            fileHandle: fileHandle
        )
    }

    /// Run a `wine` process with the given arguments and environment variables returning a stream of output
    public static func runWineProcess(
        name: String? = nil, args: [String], bottle: Bottle, environment: [String: String] = [:]
    ) throws -> AsyncStream<ProcessOutput> {
        let fileHandle = try makeFileHandle()
        fileHandle.writeApplicaitonInfo()
        fileHandle.writeInfo(for: bottle)

        if bottle.settings.gptkEnabled, Wine.gptkWineBinary() != nil {
            return try runGptkProcess(
                name: name, args: args,
                environment: constructWineEnvironment(for: bottle, environment: environment),
                fileHandle: fileHandle
            )
        }

        return try runWineProcess(
            name: name, args: args,
            environment: constructWineEnvironment(for: bottle, environment: environment),
            fileHandle: fileHandle
        )
    }

    /// Run a `wineserver` process with the given arguments and environment variables returning a stream of output
    public static func runWineserverProcess(
        name: String? = nil, args: [String], bottle: Bottle, environment: [String: String] = [:]
    ) throws -> AsyncStream<ProcessOutput> {
        let fileHandle = try makeFileHandle()
        fileHandle.writeApplicaitonInfo()
        fileHandle.writeInfo(for: bottle)

        if bottle.settings.gptkEnabled, Wine.gptkWineserverBinary() != nil {
            return try runGptkWineserverProcess(
                name: name, args: args,
                environment: constructWineServerEnvironment(for: bottle, environment: environment),
                fileHandle: fileHandle
            )
        }

        return try runWineserverProcess(
            name: name, args: args,
            environment: constructWineServerEnvironment(for: bottle, environment: environment),
            fileHandle: fileHandle
        )
    }

    /// Execute a `wine start /unix {url}` command returning the output result
    public static func runProgram(
        at url: URL, args: [String] = [], bottle: Bottle, environment: [String: String] = [:]
    ) async throws {
        if bottle.settings.gptkEnabled, Wine.gptkWineBinary() != nil {
            // GPTK uses D3DMetal natively — no DXVK needed
            for await _ in try Self.runGptkProcess(
                name: url.lastPathComponent,
                args: ["start", "/unix", url.path(percentEncoded: false)] + args,
                environment: constructWineEnvironment(for: bottle, environment: environment),
                fileHandle: try makeFileHandle()
            ) { }
        } else {
            if bottle.settings.dxvk {
                try enableDXVK(bottle: bottle)
            }

            for await _ in try Self.runWineProcess(
                name: url.lastPathComponent,
                args: ["start", "/unix", url.path(percentEncoded: false)] + args,
                bottle: bottle, environment: environment
            ) { }
        }
    }

    /// Execute a `wine start /unix {url}` command via GPTK
    public static func runProgramGptk(
        at url: URL, args: [String] = [], bottle: Bottle, environment: [String: String] = [:]
    ) async throws {
        // GPTK uses D3DMetal natively — no DXVK needed
        for await _ in try Self.runGptkProcess(
            name: url.lastPathComponent,
            args: ["start", "/unix", url.path(percentEncoded: false)] + args,
            environment: constructWineEnvironment(for: bottle, environment: environment),
            fileHandle: try makeFileHandle()
        ) { }
    }

    public static func generateRunCommand(
        at url: URL, bottle: Bottle, args: String, environment: [String: String]
    ) -> String {
        // Use GPTK binary if enabled, otherwise use bundled Wine
        let wineBin = (bottle.settings.gptkEnabled && Wine.gptkWineBinary() != nil)
            ? Wine.gptkWineBinary()! : wineBinary
        var wineCmd = "\(wineBin.esc) start /unix \(url.esc) \(args)"
        let env = constructWineEnvironment(for: bottle, environment: environment)
        for environment in env {
            wineCmd = "\(environment.key)=\"\(environment.value)\" " + wineCmd
        }

        return wineCmd
    }

    public static func generateTerminalEnvironmentCommand(bottle: Bottle) -> String {
        // Use GPTK binary if enabled, otherwise use bundled Wine
        let wineBin = (bottle.settings.gptkEnabled && Wine.gptkWineBinary() != nil)
            ? Wine.gptkWineBinary()! : wineBinary

        var cmd = """
        export PATH="\(wineBin.deletingLastPathComponent().path):$PATH"
        export WINE="wine64"
        alias wine="wine64"
        alias winecfg="wine64 winecfg"
        alias msiexec="wine64 msiexec"
        alias regedit="wine64 regedit"
        alias regsvr32="wine64 regsvr32"
        alias wineboot="wine64 wineboot"
        alias wineconsole="wine64 wineconsole"
        alias winedbg="wine64 winedbg"
        alias winefile="wine64 winefile"
        alias winepath="wine64 winepath"
        """

        let env = constructWineEnvironment(for: bottle, environment: [:])
        for environment in env {
            cmd += "\nexport \(environment.key)=\"\(environment.value)\""
        }

        return cmd
    }

    @discardableResult
    private static func runWineserver(_ args: [String], bottle: Bottle) async throws -> String {
        var result: [ProcessOutput] = []
        let environment = constructWineServerEnvironment(for: bottle, environment: [:])

        let processRunner: () throws -> AsyncStream<ProcessOutput>
        if bottle.settings.gptkEnabled, Wine.gptkWineserverBinary() != nil {
            processRunner = { try runGptkWineserverProcess(args: args, environment: environment, fileHandle: nil) }
        } else {
            processRunner = { try runWineserverProcess(args: args, bottle: bottle, environment: [:]) }
        }

        for await output in try processRunner() {
            result.append(output)
        }

        return result.compactMap { output -> String? in
            switch output {
            case .started, .terminated:
                return nil
            case .message(let message), .error(let message):
                return message
            }
        }.joined()
    }

    @discardableResult
    /// Run a `wine` command with the given arguments and return the output result
    public static func runWine(
        _ args: [String], bottle: Bottle?, environment: [String: String] = [:]
    ) async throws -> String {
        var result: [String] = []
        let fileHandle = try makeFileHandle()
        fileHandle.writeApplicaitonInfo()
        var environment = environment

        if let bottle = bottle {
            fileHandle.writeInfo(for: bottle)
            environment = constructWineEnvironment(for: bottle, environment: environment)
        }

        let processRunner: () throws -> AsyncStream<ProcessOutput>
        if let bottle = bottle, bottle.settings.gptkEnabled, Wine.gptkWineBinary() != nil {
            processRunner = { try runGptkProcess(args: args, environment: environment, fileHandle: fileHandle) }
        } else {
            processRunner = { try runWineProcess(args: args, environment: environment, fileHandle: fileHandle) }
        }

        for await output in try processRunner() {
            switch output {
            case .started, .terminated:
                break
            case .message(let message), .error(let message):
                result.append(message)
            }
        }

        return result.joined()
    }

    public static func wineVersion() async throws -> String {
        var output = try await runWine(["--version"], bottle: nil)
        output.replace("wine-", with: "")

        // Deal with WineCX version names
        if let index = output.firstIndex(where: { $0.isWhitespace }) {
            return String(output.prefix(upTo: index))
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    public static func runBatchFile(url: URL, bottle: Bottle) async throws -> String {
        if bottle.settings.gptkEnabled, Wine.gptkWineBinary() != nil {
            return try await runBatchFileGptk(url: url, bottle: bottle)
        }
        return try await runWine(["cmd", "/c", url.path(percentEncoded: false)], bottle: bottle)
    }

    @discardableResult
    private static func runBatchFileGptk(url: URL, bottle: Bottle) async throws -> String {
        var result: [String] = []
        let fileHandle = try makeFileHandle()
        fileHandle.writeApplicaitonInfo()
        fileHandle.writeInfo(for: bottle)

        let env = constructWineEnvironment(for: bottle, environment: [:])

        for await output in try runGptkProcess(
            args: ["cmd", "/c", url.path(percentEncoded: false)],
            environment: env,
            fileHandle: fileHandle
        ) {
            switch output {
            case .started, .terminated:
                break
            case .message(let message), .error(let message):
                result.append(message)
            }
        }

        return result.joined()
    }

    public static func killBottle(bottle: Bottle) throws {
        Task.detached(priority: .userInitiated) {
            try await runWineserver(["-k"], bottle: bottle)
        }
    }

    public static func enableDXVK(bottle: Bottle) throws {
        try FileManager.default.replaceDLLs(
            in: bottle.url.appending(path: "drive_c").appending(path: "windows").appending(path: "system32"),
            withContentsIn: Wine.dxvkFolder.appending(path: "x64")
        )
        try FileManager.default.replaceDLLs(
            in: bottle.url.appending(path: "drive_c").appending(path: "windows").appending(path: "syswow64"),
            withContentsIn: Wine.dxvkFolder.appending(path: "x32")
        )
    }

    /// Construct an environment merging the bottle values with the given values
    private static func constructWineEnvironment(
        for bottle: Bottle, environment: [String: String] = [:]
    ) -> [String: String] {
        var result: [String: String] = [
            "WINEPREFIX": bottle.url.path,
            "WINEDEBUG": "fixme-all",
            "GST_DEBUG": "1"
        ]
        bottle.settings.environmentVariables(wineEnv: &result)
        guard !environment.isEmpty else { return result }
        result.merge(environment, uniquingKeysWith: { $1 })
        return result
    }

    /// Construct an environment merging the bottle values with the given values,
    /// including GPTK-specific variables when enabled.
    private static func constructWineServerEnvironment(
        for bottle: Bottle, environment: [String: String] = [:]
    ) -> [String: String] {
        var result: [String: String] = [
            "WINEPREFIX": bottle.url.path,
            "WINEDEBUG": "fixme-all",
            "GST_DEBUG": "1"
        ]
        // Apply bottle-level environment variables (DXVK, VKD3D, shader cache, perf mode, etc.)
        bottle.settings.environmentVariables(wineEnv: &result)
        guard !environment.isEmpty else { return result }
        result.merge(environment, uniquingKeysWith: { $1 })
        return result
    }
}

enum WineInterfaceError: Error {
    case invalidResponce
}

enum GPTKError: Error, LocalizedError {
    case binaryNotFound

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return String(localized: "gptk.error.binaryNotFound")
        }
    }
}

/// Information about a GPTK update check result
public struct GPTKUpdateInfo: Sendable {
    public let installed: String?  // Currently installed version
    public let latest: String?     // Latest available version
    public let needsUpdate: Bool   // Whether an update is available

    public init(installed: String?, latest: String?, needsUpdate: Bool) {
        self.installed = installed
        self.latest = latest
        self.needsUpdate = needsUpdate
    }

    /// A user-friendly description of the update status
    public var statusMessage: String {
        if let latest = latest, let installed = installed {
            return String(format: NSLocalizedString("gptk.update.available", comment: ""), installed, latest)
        } else if let installed = installed {
            return String(format: NSLocalizedString("gptk.update.current", comment: ""), installed)
        } else {
            return NSLocalizedString("gptk.update.unknown", comment: "")
        }
    }
}

enum RegistryType: String {
    case binary = "REG_BINARY"
    case dword = "REG_DWORD"
    case qword = "REG_QWORD"
    case string = "REG_SZ"
}

extension Wine {
    public static let logsFolder = FileManager.default.urls(
        for: .libraryDirectory, in: .userDomainMask
    )[0].appending(path: "Logs").appending(path: Bundle.whiskyBundleIdentifier)

    public static func makeFileHandle() throws -> FileHandle {
        if !FileManager.default.fileExists(atPath: Self.logsFolder.path) {
            try FileManager.default.createDirectory(at: Self.logsFolder, withIntermediateDirectories: true)
        }

        let dateString = Date.now.ISO8601Format()
        let fileURL = Self.logsFolder.appending(path: dateString).appendingPathExtension("log")
        try "".write(to: fileURL, atomically: true, encoding: .utf8)
        return try FileHandle(forWritingTo: fileURL)
    }
}

extension Wine {
    private enum RegistryKey: String {
        case currentVersion = #"HKLM\Software\Microsoft\Windows NT\CurrentVersion"#
        case macDriver = #"HKCU\Software\Wine\Mac Driver"#
        case desktop = #"HKCU\Control Panel\Desktop"#
    }

    private static func addRegistryKey(
        bottle: Bottle, key: String, name: String, data: String, type: RegistryType
    ) async throws {
        try await runWine(
            ["reg", "add", key, "-v", name, "-t", type.rawValue, "-d", data, "-f"],
            bottle: bottle
        )
    }

    private static func queryRegistryKey(
        bottle: Bottle, key: String, name: String, type: RegistryType
    ) async throws -> String? {
        let output = try await runWine(["reg", "query", key, "-v", name], bottle: bottle)
        let lines = output.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)

        guard let line = lines.first(where: { $0.contains(type.rawValue) }) else { return nil }
        let array = line.split(omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
        guard let value = array.last else { return nil }
        return String(value)
    }

    public static func changeBuildVersion(bottle: Bottle, version: Int) async throws {
        try await addRegistryKey(bottle: bottle, key: RegistryKey.currentVersion.rawValue,
                                name: "CurrentBuild", data: "\(version)", type: .string)
        try await addRegistryKey(bottle: bottle, key: RegistryKey.currentVersion.rawValue,
                                name: "CurrentBuildNumber", data: "\(version)", type: .string)
    }

    public static func winVersion(bottle: Bottle) async throws -> WinVersion {
        let output = try await Wine.runWine(["winecfg", "-v"], bottle: bottle)
        let lines = output.split(whereSeparator: \.isNewline)

        if let lastLine = lines.last {
            let winString = String(lastLine)

            if let version = WinVersion(rawValue: winString) {
                return version
            }
        }

        throw WineInterfaceError.invalidResponce
    }

    public static func buildVersion(bottle: Bottle) async throws -> String? {
        return try await Wine.queryRegistryKey(
            bottle: bottle, key: RegistryKey.currentVersion.rawValue,
            name: "CurrentBuild", type: .string
        )
    }

    public static func retinaMode(bottle: Bottle) async throws -> Bool {
        let values: Set<String> = ["y", "n"]
        guard let output = try await Wine.queryRegistryKey(
            bottle: bottle, key: RegistryKey.macDriver.rawValue, name: "RetinaMode", type: .string
        ), values.contains(output) else {
            try await changeRetinaMode(bottle: bottle, retinaMode: false)
            return false
        }
        return output == "y"
    }

    public static func changeRetinaMode(bottle: Bottle, retinaMode: Bool) async throws {
        try await Wine.addRegistryKey(
            bottle: bottle, key: RegistryKey.macDriver.rawValue, name: "RetinaMode", data: retinaMode ? "y" : "n",
            type: .string
        )
    }

    public static func dpiResolution(bottle: Bottle) async throws -> Int? {
        guard let output = try await Wine.queryRegistryKey(bottle: bottle, key: RegistryKey.desktop.rawValue,
                                                     name: "LogPixels", type: .dword
        ) else { return nil }

        let noPrefix = output.replacingOccurrences(of: "0x", with: "")
        let int = Int(noPrefix, radix: 16)
        guard let int = int else { return nil }
        return int
    }

    public static func changeDpiResolution(bottle: Bottle, dpi: Int) async throws {
        try await Wine.addRegistryKey(
            bottle: bottle, key: RegistryKey.desktop.rawValue, name: "LogPixels", data: String(dpi),
            type: .dword
        )
    }

    @discardableResult
    public static func control(bottle: Bottle) async throws -> String {
        return try await Wine.runWine(["control"], bottle: bottle)
    }

    @discardableResult
    public static func regedit(bottle: Bottle) async throws -> String {
        return try await Wine.runWine(["regedit"], bottle: bottle)
    }

    @discardableResult
    public static func cfg(bottle: Bottle) async throws -> String {
        return try await Wine.runWine(["winecfg"], bottle: bottle)
    }

    @discardableResult
    public static func changeWinVersion(bottle: Bottle, win: WinVersion) async throws -> String {
        return try await Wine.runWine(["winecfg", "-v", win.rawValue], bottle: bottle)
    }
}
