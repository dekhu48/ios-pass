//
//
// GetBreachesForAlias.swift
// Proton Pass - Created on 29/04/2024.
// Copyright (c) 2024 Proton Technologies AG
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
//

import Client
import Entities

public protocol GetBreachesForAliasUseCase: Sendable {
    func execute(shareId: String, itemId: String) async throws -> EmailBreaches
}

public extension GetBreachesForAliasUseCase {
    func callAsFunction(shareId: String, itemId: String) async throws -> EmailBreaches {
        try await execute(shareId: shareId, itemId: itemId)
    }
}

public final class GetBreachesForAlias: GetBreachesForAliasUseCase {
    private let repository: any PassMonitorRepositoryProtocol

    public init(repository: any PassMonitorRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(shareId: String, itemId: String) async throws -> EmailBreaches {
        try await repository.getBreachesForAlias(sharedId: shareId,
                                                 itemId: itemId)
    }
}
