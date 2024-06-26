//
// VaultSelection+Extension.swift
// Proton Pass - Created on 07/12/2023.
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

import Entities
import Macro

public extension VaultSelection {
    var searchBarPlacehoder: String {
        switch self {
        case .all:
            #localized("Search in all vaults...", bundle: .module)
        case let .precise(vault):
            #localized("Search in %@...", bundle: .module, vault.name)
        case .trash:
            #localized("Search in Trash...", bundle: .module)
        }
    }
}
