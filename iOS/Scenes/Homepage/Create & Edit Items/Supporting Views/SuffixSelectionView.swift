//
// SuffixSelectionView.swift
// Proton Pass - Created on 03/05/2023.
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

import Client
import DesignSystem
import Entities
import Factory
import ProtonCoreUIFoundations
import SwiftUI

struct SuffixSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SuffixSelectionViewModel

    init(viewModel: SuffixSelectionViewModel) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    private var selection: SuffixSelection { viewModel.suffixSelection }
    private var tintColor: UIColor { ItemContentType.alias.normMajor2Color }

    var body: some View {
        NavigationStack {
            // ZStack instead of VStack because of SwiftUI bug.
            // See more in "CreateAliasLiteView.swift"
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(selection.suffixes, id: \.suffix) { suffix in
                            HStack {
                                Text(suffix.suffix)
                                    .foregroundStyle((isSelected(suffix) ?
                                            tintColor : PassColor.textNorm).toColor)
                                Spacer()

                                if isSelected(suffix) {
                                    Image(uiImage: IconProvider.checkmark)
                                        .foregroundStyle(tintColor.toColor)
                                }
                            }
                            .contentShape(.rect)
                            .background(Color.clear)
                            .padding(.horizontal)
                            .frame(height: OptionRowHeight.compact.value)
                            .onTapGesture {
                                selection.selectedSuffix = suffix
                                dismiss()
                            }

                            PassDivider()
                                .padding(.horizontal)
                        }

                        if viewModel.shouldUpgrade {
                            upgradeButton
                        }
                    }
                }
            }
            .background(PassColor.backgroundWeak.toColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Suffix")
                        .navigationTitleText()
                }
            }
        }
    }

    private func isSelected(_ suffix: Suffix) -> Bool {
        suffix == selection.selectedSuffix
    }

    private var upgradeButton: some View {
        Button(action: viewModel.upgrade) {
            HStack {
                Text("Upgrade for custom domains")
                Image(uiImage: IconProvider.arrowOutSquare)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 20)
            }
            .contentShape(.rect)
            .foregroundStyle(tintColor.toColor)
        }
        .frame(height: OptionRowHeight.compact.value)
    }
}
