//
//  Bottle.swift
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
import SwiftUI
import os.log

// swiftlint:disable:next todo
// TODO: Should not be unchecked!
public final class Bottle: ObservableObject, Equatable, Hashable, Identifiable, Comparable, @unchecked Sendable {
    public let url: URL
    private let metadataURL: URL
    @Published public var settings: BottleSettings {
        didSet { saveSettings() }
    }
    @Published public var programs: [Program] = []
    @Published public var inFlight: Bool = false
    public var isAvailable: Bool = false

    /// Whether this bottle contains 32-bit executables
    public var is32Bit: Bool {
        let driveC = url.appending(path: "drive_c")
        let windows = driveC.appending(path: "windows")
        let system32 = windows.appending(path: "system32")
        let syswow64 = windows.appending(path: "syswow64")

        // syswow64 existing indicates a 64-bit Wine with 32-bit support
        // But we check for 32-bit PE files in common locations
        let checkDirs = [system32, syswow64]
        for dir in checkDirs {
            do {
                let files = try FileManager.default.contentsOfDirectory(
                    at: dir, includingPropertiesForKeys: nil, options: []
                )
                for file in files where file.pathExtension.lowercased() == "exe" || file.pathExtension.lowercased() == "dll" {
                    if isPE32Bit(url: file) {
                        return true
                    }
                }
            } catch {
                // Directory doesn't exist or can't be read
            }
        }
        return false
    }

    /// Check if a PE file is 32-bit by reading the COFF header
    private func isPE32Bit(url: URL) -> Bool {
        guard let peFile = try? PEFile(url: url) else { return false }
        return peFile.architecture == .x32
    }

    /// Health check results for this bottle
    public struct HealthCheck: Codable {
        public enum Severity: String, Codable {
            case ok, warning, error
        }

        public struct Issue: Codable {
            public var severity: Severity
            public var message: String
            public var suggestion: String?
        }

        public var issues: [Issue] = []
        public var isHealthy: Bool {
            return !issues.contains { $0.severity == .error }
        }
        public var warningCount: Int {
            return issues.filter { $0.severity == .warning }.count
        }
        public var errorCount: Int {
            return issues.filter { $0.severity == .error }.count
        }
    }

    /// Run a health check on this bottle, returning any issues found
    public func diagnose() -> HealthCheck {
        var issues: [HealthCheck.Issue] = []

        // Check Wine binary exists
        let wineBin = Wine.wineBinary(for: self)
        if !FileManager.default.fileExists(atPath: wineBin.path) {
            issues.append(HealthCheck.Issue(
                severity: .error,
                message: String(localized: "diagnostics.wineNotFound"),
                suggestion: String(localized: "diagnostics.wineNotFound.suggestion")
            ))
        }

        // Check drive_c exists
        let driveC = url.appending(path: "drive_c")
        if !FileManager.default.fileExists(atPath: driveC.path) {
            issues.append(HealthCheck.Issue(
                severity: .warning,
                message: String(localized: "diagnostics.noDriveC"),
                suggestion: String(localized: "diagnostics.noDriveC.suggestion")
            ))
        }

        // Check for 32-bit executables
        if is32Bit {
            issues.append(HealthCheck.Issue(
                severity: .warning,
                message: String(localized: "diagnostics.has32Bit"),
                suggestion: String(localized: "diagnostics.has32Bit.suggestion")
            ))
        }

        // Check DXVK DLLs if DXVK is enabled
        if settings.dxvk {
            let system32 = driveC.appending(path: "windows").appending(path: "system32")
            let dxvkDlls = ["d3d11.dll", "d3d10.dll", "dxgi.dll"]
            for dll in dxvkDlls {
                let dllPath = system32.appending(path: dll)
                if !FileManager.default.fileExists(atPath: dllPath.path) {
                    issues.append(HealthCheck.Issue(
                        severity: .warning,
                        message: String(format: String(localized: "diagnostics.missingDll"), dll),
                        suggestion: String(localized: "diagnostics.missingDll.suggestion")
                    ))
                    break
                }
            }
        }

        // Check metadata file integrity
        do {
            _ = try BottleSettings.decode(from: metadataURL)
        } catch {
            issues.append(HealthCheck.Issue(
                severity: .error,
                message: String(localized: "diagnostics.corruptMetadata"),
                suggestion: String(localized: "diagnostics.corruptMetadata.suggestion")
            ))
        }

        return HealthCheck(issues: issues)
    }

    /// All pins with their associated programs
    public var pinnedPrograms: [(pin: PinnedProgram, program: Program, // swiftlint:disable:this large_tuple
                                 id: String)] {
        return settings.pins.compactMap { pin in
            let exists = FileManager.default.fileExists(atPath: pin.url?.path(percentEncoded: false) ?? "")
            guard let program = programs.first(where: { $0.url == pin.url && exists }) else { return nil }
            return (pin, program, "\(pin.name)//\(program.url)")
        }
    }

    public init(bottleUrl: URL, inFlight: Bool = false, isAvailable: Bool = false) {
        let metadataURL = bottleUrl.appending(path: "Metadata").appendingPathExtension("plist")
        self.url = bottleUrl
        self.inFlight = inFlight
        self.isAvailable = isAvailable
        self.metadataURL = metadataURL

        do {
            self.settings = try BottleSettings.decode(from: metadataURL)
        } catch {
            Logger.wineKit.error(
              "Failed to load settings for bottle `\(metadataURL.path(percentEncoded: false))`: \(error)"
            )
            self.settings = BottleSettings()
        }

        // Get rid of duplicates and pins that reference removed files
        var found: Set<URL> = []
        self.settings.pins = self.settings.pins.filter { pin in
            guard let url = pin.url else { return false }
            guard !found.contains(url) else { return false }
            found.insert(url)
            let urlPath = url.path(percentEncoded: false)
            let volume: URL?
            do {
                volume = try url.resourceValues(forKeys: [.volumeURLKey]).volume ?? nil
            } catch {
                volume = nil
            }
            let legallyRemoved = pin.removable && volume == nil
            return FileManager.default.fileExists(atPath: urlPath) || legallyRemoved
        }
    }

    /// Encode and save the bottle settings
    private func saveSettings() {
        do {
            try settings.encode(to: self.metadataURL)
        } catch {
            Logger.wineKit.error(
                "Failed to encode settings for bottle `\(self.metadataURL.path(percentEncoded: false))`: \(error)"
            )
        }
    }

    // MARK: - Equatable

    public static func == (lhs: Bottle, rhs: Bottle) -> Bool {
        return lhs.url == rhs.url
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        return hasher.combine(url)
    }

    // MARK: - Identifiable

    public var id: URL {
        self.url
    }

    // MARK: - Comparable

    public static func < (lhs: Bottle, rhs: Bottle) -> Bool {
        lhs.settings.name.lowercased() < rhs.settings.name.lowercased()
    }
}

public extension Sequence where Iterator.Element == Program {
    /// Filter all pinned programs
    var pinned: [Program] {
        return self.filter({ $0.pinned })
    }

    /// Filter all unpinned programs
    var unpinned: [Program] {
        return self.filter({ !$0.pinned })
    }
}
