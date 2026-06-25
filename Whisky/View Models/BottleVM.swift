//
//  BottleVM.swift
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
import SemanticVersion
import WhiskyKit

// swiftlint:disable:next todo
// TODO: Don't use unchecked!
final class BottleVM: ObservableObject, @unchecked Sendable {
    @MainActor static let shared = BottleVM()

    var bottlesList = BottleData()
    @Published var bottles: [Bottle] = []

    @MainActor
    func loadBottles() {
        bottles = bottlesList.loadBottles()
    }

    func countActive() -> Int {
        return bottles.filter { $0.isAvailable == true }.count
    }

    func createNewBottle(bottleName: String, winVersion: WinVersion, bottleURL: URL) -> URL {
        let newBottleDir = bottleURL.appending(path: UUID().uuidString)

        Task.detached {
            var bottleId: Bottle?
            do {
                try FileManager.default.createDirectory(atPath: newBottleDir.path(percentEncoded: false),
                                                        withIntermediateDirectories: true)
                let bottle = Bottle(bottleUrl: newBottleDir, inFlight: true)
                bottleId = bottle

                await MainActor.run {
                    self.bottles.append(bottle)
                }

                bottle.settings.windowsVersion = winVersion
                bottle.settings.name = bottleName
                try await Wine.changeWinVersion(bottle: bottle, win: winVersion)
                let wineVer = try await Wine.wineVersion()
                bottle.settings.wineVersion = SemanticVersion(wineVer) ?? SemanticVersion(0, 0, 0)
                // Add record
                await MainActor.run {
                    self.bottlesList.paths.append(newBottleDir)
                    self.loadBottles()
                }
            } catch {
                print("Failed to create new bottle: \(error)")
                if let bottle = bottleId {
                    await MainActor.run {
                        if let index = self.bottles.firstIndex(of: bottle) {
                            self.bottles.remove(at: index)
                        }
                    }
                }
            }
        }
        return newBottleDir
    }

    /// Clone an existing bottle with a new name
    @MainActor
    func cloneBottle(source: Bottle, cloneName: String) -> URL? {
        // Generate a unique clone name if not provided
        let baseName = cloneName.isEmpty ? "\(source.settings.name) (Clone)" : cloneName
        let existingDirs = bottlesList.paths.map { $0.lastPathComponent }
        var cloneName = baseName
        var counter = 1
        while existingDirs.contains(cloneName) {
            cloneName = "\(baseName) \(counter)"
            counter += 1
        }

        let cloneDir = source.url.deletingLastPathComponent().appending(path: cloneName)

        Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.copyItem(at: source.url, to: cloneDir)
                let bottle = Bottle(bottleUrl: cloneDir)
                bottle.settings.name = cloneName

                await MainActor.run {
                    self.bottles.append(bottle)
                    self.bottlesList.paths.append(cloneDir)
                    self.loadBottles()
                }

                return cloneDir
            } catch {
                print("Failed to clone bottle: \(error)")
                return nil
            }
        }

        return nil
    }

    /// Import a bottle from a .tar or .tar.gz archive
    @MainActor
    func importBottle(from archiveURL: URL, destination: URL) -> URL? {
        Task.detached(priority: .userInitiated) {
            do {
                // Extract archive to a temp location first
                let tempDir = FileManager.default.temporaryDirectory.appending(path: "whisky-import-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                try Tar.untar(tarBall: archiveURL, toURL: tempDir)

                // Find the extracted bottle directory (look for Metadata.plist)
                let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                var bottleDir: URL?
                for item in contents {
                    if item.hasDirectoryPath {
                        let metadataURL = item.appending(path: "Metadata").appendingPathExtension("plist")
                        if FileManager.default.fileExists(atPath: metadataURL.path) {
                            bottleDir = item
                            break
                        }
                    }
                }

                guard let bottleDir = bottleDir else {
                    print("No valid bottle found in archive")
                    return nil
                }

                // Generate a unique import name
                let baseName = bottleDir.lastPathComponent
                let existingDirs = self.bottlesList.paths.map { $0.lastPathComponent }
                var importName = baseName
                var counter = 1
                while existingDirs.contains(importName) {
                    importName = "\(baseName) (Imported) \(counter)"
                    counter += 1
                }

                let importDir = destination.appending(path: importName)
                try FileManager.default.copyItem(at: bottleDir, to: importDir)

                let bottle = Bottle(bottleUrl: importDir)
                bottle.settings.name = importName

                await MainActor.run {
                    self.bottles.append(bottle)
                    self.bottlesList.paths.append(importDir)
                    self.loadBottles()
                }

                return importDir
            } catch {
                print("Failed to import bottle: \(error)")
                return nil
            }
        }

        return nil
    }
}
