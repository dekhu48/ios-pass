//
// AccessRepository.swift
// Proton Pass - Created on 04/05/2023.
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

@preconcurrency import Combine
import Core
import Entities

// sourcery: AutoMockable
public protocol AccessRepositoryProtocol: AnyObject, Sendable {
    var access: CurrentValueSubject<Access?, Never> { get }
    var didUpdateToNewPlan: PassthroughSubject<Void, Never> { get }

    /// Get from local, refresh if not exist
    func getAccess() async throws -> Access

    /// Conveniently get the plan of current access
    func getPlan() async throws -> Plan

    @discardableResult
    func refreshAccess() async throws -> Access

    func updateProtonAddressesMonitor(_ monitored: Bool) async throws
    func updateAliasesMonitor(_ monitored: Bool) async throws
}

public actor AccessRepository: AccessRepositoryProtocol {
    private let localDatasource: any LocalAccessDatasourceProtocol
    private let remoteDatasource: any RemoteAccessDatasourceProtocol
    private let userDataProvider: any UserDataProvider
    private let logger: Logger

    public nonisolated let access: CurrentValueSubject<Access?, Never> = .init(nil)
    public nonisolated let didUpdateToNewPlan: PassthroughSubject<Void, Never> = .init()

    public init(localDatasource: any LocalAccessDatasourceProtocol,
                remoteDatasource: any RemoteAccessDatasourceProtocol,
                userDataProvider: any UserDataProvider,
                logManager: any LogManagerProtocol) {
        self.localDatasource = localDatasource
        self.remoteDatasource = remoteDatasource
        self.userDataProvider = userDataProvider
        logger = .init(manager: logManager)
    }
}

public extension AccessRepository {
    func getAccess() async throws -> Access {
        let userId = try userDataProvider.getUserId()
        logger.trace("Getting access for user \(userId)")
        if let localAccess = try await localDatasource.getAccess(userId: userId) {
            logger.trace("Found local access for user \(userId)")
            access.send(localAccess)
            return localAccess
        }

        logger.trace("No local access found for user \(userId). Refreshing...")
        return try await refreshAccess()
    }

    func getPlan() async throws -> Plan {
        let userId = try userDataProvider.getUserId()
        logger.trace("Getting plan for user \(userId)")
        return try await getAccess().plan
    }

    @discardableResult
    func refreshAccess() async throws -> Access {
        let userId = try userDataProvider.getUserId()
        logger.trace("Refreshing access for user \(userId)")
        let remoteAccess = try await remoteDatasource.getAccess()
        access.send(remoteAccess)

        if let localAccess = try await localDatasource.getAccess(userId: userId),
           localAccess.plan != remoteAccess.plan {
            logger.info("New plan found")
            didUpdateToNewPlan.send()
        }

        logger.trace("Upserting access for user \(userId)")
        try await localDatasource.upsert(access: remoteAccess, userId: userId)

        logger.info("Refreshed access for user \(userId)")
        return remoteAccess
    }

    func updateProtonAddressesMonitor(_ monitored: Bool) async throws {
        try await updatePassMonitorState(.protonAddress(monitored))
    }

    func updateAliasesMonitor(_ monitored: Bool) async throws {
        try await updatePassMonitorState(.aliases(monitored))
    }
}

private extension AccessRepository {
    func updatePassMonitorState(_ request: UpdateMonitorStateRequest) async throws {
        let userId = try userDataProvider.getUserId()
        logger.trace("Updating monitor state for user \(userId)")
        var access = try await getAccess()
        let updatedMonitor = try await remoteDatasource.updatePassMonitorState(request)
        access.monitor = updatedMonitor

        logger.trace("Upserting access for user \(userId)")
        try await localDatasource.upsert(access: access, userId: userId)
        logger.trace("Upserted monitor state for user \(userId)")
        self.access.send(access)
    }
}
