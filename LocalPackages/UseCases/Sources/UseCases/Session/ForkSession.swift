//
// ForkSession.swift
// Proton Pass - Created on 17/01/2024.
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
import Foundation

/// Fork the session and return the `selector`
public protocol ForkSessionUseCase: Sendable {
    func execute(payload: String?, childClientId: String, independent: Int) async throws -> String
}

public extension ForkSessionUseCase {
    func callAsFunction(payload: String?, childClientId: String, independent: Int) async throws -> String {
        try await execute(payload: payload, childClientId: childClientId, independent: independent)
    }
}

public final class ForkSession: ForkSessionUseCase {
    private let networkRepository: any NetworkRepositoryProtocol

    public init(networkRepository: any NetworkRepositoryProtocol) {
        self.networkRepository = networkRepository
    }

    public func execute(payload: String?, childClientId: String, independent: Int) async throws -> String {
        try await networkRepository.forkSession(payload: payload,
                                                childClientId: childClientId,
                                                independent: independent)
    }
}
