//
// PassMonitorRepository.swift
// Proton Pass - Created on 06/03/2024.
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

@preconcurrency import Combine
import CryptoKit
import Entities
import Foundation
import PassRustCore

public enum ItemFlag: Sendable, Hashable {
    case skipHealthCheck(Bool)
}

private struct InternalPassMonitorItem {
    let encrypted: SymmetricallyEncryptedItem
    let loginData: LogInItemData
}

// sourcery: AutoMockable
public protocol PassMonitorRepositoryProtocol: Sendable {
    var state: CurrentValueSubject<MonitorState, Never> { get }
    var weaknessStats: CurrentValueSubject<WeaknessStats, Never> { get }
    var itemsWithSecurityIssues: CurrentValueSubject<[SecurityAffectedItem], Never> { get }

    func refreshSecurityChecks() async throws
    func getItemsWithSamePassword(item: ItemContent) async throws -> [ItemContent]

    // MARK: - Breaches

    func getAllBreachesForUser() async throws -> UserBreaches
    func getAllCustomEmailForUser() async throws -> [CustomEmail]
    func addEmailToBreachMonitoring(email: String) async throws -> CustomEmail
    func verifyCustomEmail(emailId: String, code: String) async throws
    func removeEmailFromBreachMonitoring(emailId: String) async throws
    func resendEmailVerification(emailId: String) async throws
    func getBreachesForAlias(sharedId: String, itemId: String) async throws -> EmailBreaches

    /// For testing purpose
    func updateState(_ newValue: MonitorState) async
}

public actor PassMonitorRepository: PassMonitorRepositoryProtocol {
    private let itemRepository: any ItemRepositoryProtocol
    private let symmetricKeyProvider: any SymmetricKeyProvider
    private let passwordScorer: any PasswordScorerProtocol
    private let twofaDomainChecker: any TwofaDomainCheckerProtocol
    private let remoteDataSource: any RemoteBreachDataSourceProtocol

    public let state: CurrentValueSubject<MonitorState, Never> = .init(.default)
    public let weaknessStats: CurrentValueSubject<WeaknessStats, Never> = .init(.default)
    public let itemsWithSecurityIssues: CurrentValueSubject<[SecurityAffectedItem], Never> = .init([])

    private var cancellable = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?

    public init(itemRepository: any ItemRepositoryProtocol,
                remoteDataSource: any RemoteBreachDataSourceProtocol,
                symmetricKeyProvider: any SymmetricKeyProvider,
                passwordScorer: any PasswordScorerProtocol = PasswordScorer(),
                twofaDomainChecker: any TwofaDomainCheckerProtocol = TwofaDomainChecker()) {
        self.itemRepository = itemRepository
        self.symmetricKeyProvider = symmetricKeyProvider
        self.passwordScorer = passwordScorer
        self.twofaDomainChecker = twofaDomainChecker
        self.remoteDataSource = remoteDataSource

        Task { [weak self] in
            guard let self else {
                return
            }
            await setup()
        }
    }

    public func refreshSecurityChecks() async throws {
        var reusedPasswords = [String: Int]()
        let symmetricKey = try symmetricKeyProvider.getSymmetricKey()
        let loginItems = try await itemRepository.getActiveLogInItems()
            .compactMap { encryptedItem -> InternalPassMonitorItem? in
                guard let item = try? encryptedItem.getItemContent(symmetricKey: symmetricKey),
                      let loginItem = item.loginItem else {
                    return nil
                }

                if !encryptedItem.item.skipHealthCheck, !loginItem.password.isEmpty {
                    reusedPasswords[loginItem.password, default: 0] += 1
                }
                return InternalPassMonitorItem(encrypted: encryptedItem, loginData: loginItem)
            }

        // Filter out unique passwords
        reusedPasswords = reusedPasswords.filter { $0.value > 1 }

        var numberOfWeakPassword = 0
        var numberOfMissing2fa = 0
        var numberOfExcludedItems = 0

        var securityAffectedItems = [SecurityAffectedItem]()

        for item in loginItems {
            var weaknesses = [SecurityWeakness]()

            if item.encrypted.item
                .skipHealthCheck {
                weaknesses.append(.excludedItems)
                numberOfExcludedItems += 1
            } else {
                if reusedPasswords[item.loginData.password] != nil {
                    weaknesses.append(.reusedPasswords)
                }

                if !item.loginData.password.isEmpty,
                   passwordScorer.checkScore(password: item.loginData.password) != .strong {
                    weaknesses.append(.weakPasswords)
                    numberOfWeakPassword += 1
                }

                if item.loginData.totpUri.isEmpty,
                   item.loginData.urls.contains(where: { twofaDomainChecker.twofaDomainEligible(domain: $0) }) {
                    weaknesses.append(.missing2FA)
                    numberOfMissing2fa += 1
                }
            }

            if !weaknesses.isEmpty {
                securityAffectedItems.append(SecurityAffectedItem(item: item.encrypted, weaknesses: weaknesses))
            }
        }
        weaknessStats.send(WeaknessStats(weakPasswords: numberOfWeakPassword,
                                         reusedPasswords: reusedPasswords.count,
                                         missing2FA: numberOfMissing2fa,
                                         excludedItems: numberOfExcludedItems))
        itemsWithSecurityIssues.send(securityAffectedItems)
    }

    public func getItemsWithSamePassword(item: ItemContent) async throws -> [ItemContent] {
        guard let login = item.loginItem else {
            return []
        }
        let symmetricKey = try symmetricKeyProvider.getSymmetricKey()
        let encryptedItems = try await itemRepository.getActiveLogInItems()

        return encryptedItems.compactMap { encryptedItem in
            guard let decriptedItem = try? encryptedItem.getItemContent(symmetricKey: symmetricKey),
                  !decriptedItem.item.skipHealthCheck,
                  let loginItem = decriptedItem.loginItem,
                  decriptedItem.ids != item.ids,
                  !loginItem.password.isEmpty, loginItem.password == login.password else {
                return nil
            }
            return decriptedItem
        }
    }

    public func updateState(_ newValue: MonitorState) async {
        state.send(newValue)
    }
}

// MARK: - Breaches

public extension PassMonitorRepository {
    func getAllBreachesForUser() async throws -> UserBreaches {
        let breaches = try await remoteDataSource.getAllBreachesForUser()
        return breaches
    }

    func getAllCustomEmailForUser() async throws -> [CustomEmail] {
        let emails = try await remoteDataSource.getAllCustomEmailForUser()
        return emails
    }

    func addEmailToBreachMonitoring(email: String) async throws -> CustomEmail {
        let email = try await remoteDataSource.addEmailToBreachMonitoring(email: email)
        return email
    }

    func verifyCustomEmail(emailId: String, code: String) async throws {
        try await remoteDataSource.verifyCustomEmail(emailId: emailId, code: code)
    }

    func removeEmailFromBreachMonitoring(emailId: String) async throws {
        try await remoteDataSource.removeEmailFromBreachMonitoring(emailId: emailId)
    }

    func resendEmailVerification(emailId: String) async throws {
        try await remoteDataSource.removeEmailFromBreachMonitoring(emailId: emailId)
    }

    func getBreachesForAlias(sharedId: String, itemId: String) async throws -> EmailBreaches {
        try Task.checkCancellation()
        return try await remoteDataSource.getBreachesForAlias(sharedId: sharedId, itemId: itemId)
    }
}

private extension PassMonitorRepository {
    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else {
                return
            }
            try? await refreshSecurityChecks()
        }
    }

    func setup() {
        itemRepository.itemsWereUpdated
            .dropFirst()
            .sink { [weak self] in
                guard let self else {
                    return
                }
                Task { [weak self] in
                    guard let self else {
                        return
                    }
                    await refresh()
                }
            }
            .store(in: &cancellable)
        refresh()
    }
}
