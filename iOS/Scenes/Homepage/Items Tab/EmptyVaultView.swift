//
// EmptyVaultView.swift
// Proton Pass - Created on 07/09/2022.
// Copyright (c) 2022 Proton Technologies AG
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

import SwiftUI
import UIComponents

struct EmptyVaultView: View {
    let onCreateNewItem: () -> Void

    var body: some View {
        VStack {
            VStack {
                Spacer()
                Image(uiImage: PassIcon.emptyFolder)
                    .resizable()
                    .scaledToFit()
            }

            VStack(alignment: .center) {
                Text("Add your first item")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom)
                Text("Or use the Proton Pass web extension to import items from another password manager.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                CapsuleTextButton(title: "Create new item",
                                  titleColor: .white,
                                  backgroundColor: .passBrand,
                                  disabled: false,
                                  maxWidth: nil,
                                  action: onCreateNewItem)
                Spacer()
            }
        }
    }
}