//
// DeleteVaultEndpoint.swift
// Proton Pass - Created on 17/01/2023.
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

import ProtonCore_Networking
import ProtonCore_Services

public struct DeleteVaultEndpoint: Endpoint {
    public typealias Body = EmptyRequest
    public typealias Response = CodeOnlyResponse

    public var debugDescription: String
    public var path: String
    public var method: HTTPMethod
    public var authCredential: AuthCredential?

    public init(credential: AuthCredential,
                shareId: String) {
        self.debugDescription = "Delete vault"
        self.authCredential = credential
        self.path = "/pass/v1/vault/\(shareId)"
        self.method = .delete
    }
}