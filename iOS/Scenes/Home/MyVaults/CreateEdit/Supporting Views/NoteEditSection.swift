//
// NoteEditSection.swift
// Proton Pass - Created on 10/02/2023.
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

struct NoteEditSection: View {
    @FocusState var isFocused: Bool
    @Binding var note: String

    var body: some View {
        HStack {
            ItemDetailSectionIcon(icon: IconProvider.note, color: .textWeak)

            VStack(alignment: .leading, spacing: kItemDetailSectionPadding / 4) {
                Text("Note")
                    .sectionTitleText()

                ZStack(alignment: .topLeading) {
                    // Hacky way to make TextEditor grows in height gradually
                    Text(note)
                        .hidden()
                    TextEditorWithPlaceholder(text: $note,
                                              isFocused: _isFocused,
                                              placeholder: "Add note")
                }
                .frame(maxWidth: .infinity, maxHeight: 350, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !note.isEmpty {
                Button(action: {
                    note = ""
                }, label: {
                    ItemDetailSectionIcon(icon: IconProvider.cross, color: .textWeak)
                })
            }
        }
        .padding(kItemDetailSectionPadding)
        .roundedEditableSection()
        .animation(.default, value: note.isEmpty)
    }
}
