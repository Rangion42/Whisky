//
//  BottleCreationView.swift
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

struct BottleCreationView: View {
    @Binding var newlyCreatedBottleURL: URL?

    @State private var newBottleName: String = ""
    @State private var newBottleVersion: WinVersion = .win10
    @State private var newBottleTemplate: BottleTemplate = .blank
    @State private var newBottleURL: URL = UserDefaults.standard.url(forKey: "defaultBottleLocation")
                                           ?? BottleData.defaultBottleDir
    @State private var nameValid: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("create.name", text: $newBottleName)
                    .onChange(of: newBottleName) { _, name in
                        nameValid = !name.isEmpty
                    }

                Picker("create.win", selection: $newBottleVersion) {
                    ForEach(WinVersion.allCases.reversed(), id: \.self) {
                        Text($0.pretty())
                    }
                }

                Picker("create.template", selection: $newBottleTemplate) {
                    ForEach(BottleTemplate.allCases, id: \.self) { template in
                        VStack(alignment: .leading) {
                            Text(template.displayName)
                            Text(template.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ActionView(
                    text: "create.path",
                    subtitle: newBottleURL.prettyPath(),
                    actionName: "create.browse"
                ) {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.canCreateDirectories = true
                    panel.directoryURL = BottleData.containerDir
                    panel.begin { result in
                        if result == .OK, let url = panel.urls.first {
                            newBottleURL = url
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("create.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("create.cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("create.create") {
                        submit()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!nameValid)
                }
            }
            .onSubmit {
                submit()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: ViewWidth.small)
    }

    func submit() {
        let newBottleURL = BottleVM.shared.createNewBottle(bottleName: newBottleName,
                                                            winVersion: newBottleVersion,
                                                            bottleURL: newBottleURL)
        // Apply template-specific configuration after bottle is created
        Task(priority: .userInitiated) {
            if let bottle = BottleVM.shared.bottles.first(where: { $0.url == newBottleURL }) {
                applyTemplate(to: bottle, template: newBottleTemplate)
            }
        }
        dismiss()
    }

    private func applyTemplate(to bottle: Bottle, template: BottleTemplate) {
        // Apply template-specific settings
        switch template {
        case .steam:
            // Steam overlay works better with wined3d, not DXVK
            bottle.settings.dxvk = false
            // Steam needs specific locale
            // Additional Steam-specific env vars would be applied per-program
        case .epicGames:
            // Epic Games Store works better with DXVK
            bottle.settings.dxvk = true
            bottle.settings.dxvkAsync = true
        case .gog:
            // GOG games typically work well with DXVK
            bottle.settings.dxvk = true
        case .battleNet:
            // Battle.net launcher works better without DXVK for the launcher itself
            bottle.settings.dxvk = false
            // Some Battle.net games benefit from D3DMetal
            if #available(macOS 15, *) {
                bottle.settings.d3dmEnabled = true
            }
        case .riotGames:
            // Riot games often have anti-cheat conflicts with DXVK
            bottle.settings.dxvk = false
        case .blank:
            // No template-specific settings
            break
        }
    }
}

#Preview {
    BottleCreationView(newlyCreatedBottleURL: .constant(nil))
}
