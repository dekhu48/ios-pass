//
// ExtensionSettingsView.swift
// Proton Pass - Created on 05/04/2023.
// Copyright (c) 2023 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Pass is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Pass is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.

import ProtonCore_UIFoundations
import SwiftUI
import UIComponents

struct ExtensionSettingsView: View {
    @StateObject var viewModel: ExtensionSettingsViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    OptionRow(height: .medium) {
                        Toggle(isOn: $viewModel.quickTypeBar) {
                            Text("QuickType bar suggestions")
                        }
                        .tint(.passBrand)
                    }
                    .roundedEditableSection()
                    Text("Quickly pick a login item from suggestions above the keyboard.")
                        .sectionTitleText()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                        .frame(height: 24)

                    OptionRow(height: .medium) {
                        Toggle(isOn: $viewModel.automaticallyCopyTotpCode) {
                            Text("Copy Two Factor Authentication code")
                        }
                        .tint(.passBrand)
                    }
                    .roundedEditableSection()

                    // swiftlint:disable:next line_length
                    Text("When autofilling, you will be warned if Two Factor Authentication code expires in less than 10 seconds.")
                        .sectionTitleText()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                }
                .padding(.horizontal)
            }
            .background(Color.passBackground)
            .navigationTitle("AutoFill")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    CircleButton(icon: IconProvider.cross,
                                 color: .passBrand,
                                 action: viewModel.dismiss)
                }
            }
        }
        .navigationViewStyle(.stack)
        .theme(viewModel.preferences.theme)
    }
}
