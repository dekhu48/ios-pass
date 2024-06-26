//
// CreatePasskey.swift
// Proton Pass - Created on 20/02/2024.
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

import Entities
import Foundation
import PassRustCore
import UIKit

public protocol CreatePasskeyUseCase: Sendable {
    func execute(_ request: PasskeyCredentialRequest,
                 bundle: Bundle,
                 device: UIDevice) async throws -> Entities.CreatePasskeyResponse
}

public extension CreatePasskeyUseCase {
    func callAsFunction(_ request: PasskeyCredentialRequest,
                        bundle: Bundle,
                        device: UIDevice) async throws -> Entities.CreatePasskeyResponse {
        try await execute(request, bundle: bundle, device: device)
    }
}

public final class CreatePasskey: CreatePasskeyUseCase {
    private let managerProvider: any PasskeyManagerProvider

    public init(managerProvider: any PasskeyManagerProvider) {
        self.managerProvider = managerProvider
    }

    public func execute(_ request: PasskeyCredentialRequest,
                        bundle: Bundle,
                        device: UIDevice) async throws -> Entities.CreatePasskeyResponse {
        let supportedAlgorithms = request.supportedAlgorithms.map { Int64($0.rawValue) }
        let createRequest = CreatePasskeyIosRequest(serviceIdentifier: request.serviceIdentifier.identifier,
                                                    rpId: request.relyingPartyIdentifier,
                                                    userName: request.userName,
                                                    userHandle: request.userHandle,
                                                    clientDataHash: request.clientDataHash,
                                                    supportedAlgorithms: supportedAlgorithms)
        let response = try managerProvider.manager.generateIosPasskey(request: createRequest)
        return await .from(response, bundle: bundle, device: device)
    }
}

private extension Entities.CreatePasskeyResponse {
    static func from(_ response: CreatePasskeyIosResponse,
                     bundle: Bundle,
                     device: UIDevice) async -> Self {
        await .init(passkey: response.passkey,
                    keyId: response.keyId,
                    domain: response.domain,
                    rpId: response.rpId,
                    rpName: response.rpName,
                    userName: response.userName,
                    userDisplayName: response.userDisplayName,
                    userId: response.userId,
                    credentialId: response.credentialId,
                    clientDataHash: response.clientDataHash,
                    userHandle: response.userHandle,
                    attestationObject: response.attestationObject,
                    osName: device.systemName,
                    osVersion: device.systemVersion,
                    deviceName: device.name,
                    appVersion: "ios-pass@\(bundle.fullAppVersionName)")
    }
}
