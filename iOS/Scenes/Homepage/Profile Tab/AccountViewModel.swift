//
// AccountViewModel.swift
// Proton Pass - Created on 30/03/2023.
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
import Combine
import Core
import Entities
import Factory
import ProtonCoreAccountRecovery
import ProtonCoreDataModel
import ProtonCoreFeatureFlags
import ProtonCorePasswordChange

@MainActor
protocol AccountViewModelDelegate: AnyObject {
    func accountViewModelWantsToGoBack()
    func accountViewModelWantsToSignOut()
    func accountViewModelWantsToDeleteAccount()
    func accountViewModelWantsToShowAccountRecovery(_ completion: @escaping (AccountRecovery) -> Void)
}

@MainActor
final class AccountViewModel: ObservableObject, DeinitPrintable {
    deinit { print(deinitMessage) }

    private let accessRepository = resolve(\SharedRepositoryContainer.accessRepository)
    private let accountRepository = resolve(\SharedRepositoryContainer.accountRepository)
    private let featureFlagsRepository = resolve(\SharedRepositoryContainer.featureFlagsRepository)
    private let userDataProvider = resolve(\SharedDataContainer.userDataProvider)
    private let logger = resolve(\SharedToolingContainer.logger)
    private let revokeCurrentSession = resolve(\SharedUseCasesContainer.revokeCurrentSession)
    private let router = resolve(\SharedRouterContainer.mainUIKitSwiftUIRouter)
    private let paymentsManager = resolve(\ServiceContainer.paymentManager) // To remove after Dynaplans
    private let userSettingsRepository = resolve(\SharedRepositoryContainer.userSettingsRepository)
    let isShownAsSheet: Bool
    @Published private(set) var plan: Plan?
    @Published private(set) var isLoading = false
    @Published private(set) var passwordMode: UserSettings.Password.PasswordMode = .singlePassword
    private(set) var accountRecovery: AccountRecovery?

    weak var delegate: (any AccountViewModelDelegate)?

    var username: String { userDataProvider.getUserData()?.user.email ?? "" }

    init(isShownAsSheet: Bool) {
        self.isShownAsSheet = isShownAsSheet
        refreshUserPlan()
        refreshAccountRecovery()
        refreshAccountPasswordMode()
    }

    private func refreshUserPlan() {
        Task { [weak self] in
            guard let self else { return }
            do {
                // First get local plan to optimistically display it
                // and then try to refresh the plan to have it updated
                plan = try await accessRepository.getPlan()
                plan = try await accessRepository.refreshAccess().plan
            } catch {
                logger.error(error)
            }
        }
    }

    private func refreshAccountRecovery() {
        guard featureFlagsRepository.isEnabled(CoreFeatureFlagType.accountRecovery, reloadValue: true) else {
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                accountRecovery = try await accountRepository.accountRecovery()
            } catch {
                router.display(element: .displayErrorBanner(error))
            }
        }
    }

    private func refreshAccountPasswordMode() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let userId = try userDataProvider.getUserId()
                let settings = await userSettingsRepository.getSettings(for: userId)
                passwordMode = settings.password.mode
            } catch {
                logger.error(error)
                router.display(element: .displayErrorBanner(error))
            }
        }
    }
}

extension AccountViewModel {
    func goBack() {
        delegate?.accountViewModelWantsToGoBack()
    }

    func manageSubscription() {
        paymentsManager.manageSubscription { [weak self] result in
            guard let self else { return }
            handlePaymentsResult(result: result)
        }
    }

    func upgradeSubscription() {
        paymentsManager.upgradeSubscription { [weak self] result in
            guard let self else { return }
            handlePaymentsResult(result: result)
        }
    }

    var canChangePassword: Bool {
        featureFlagsRepository.isEnabled(CoreFeatureFlagType.changePassword, reloadValue: true)
    }

    var canChangeMailboxPassword: Bool {
        guard featureFlagsRepository.isEnabled(CoreFeatureFlagType.changePassword, reloadValue: true)
        else { return false }
        return passwordMode == .loginAndMailboxPassword
    }

    func openChangeUserPassword() {
        let mode: PasswordChangeModule
            .PasswordChangeMode = passwordMode == .singlePassword ? .singlePassword : .loginPassword
        router.present(for: .changePassword(mode))
    }

    func openChangeMailboxPassword() {
        router.present(for: .changePassword(.mailboxPassword))
    }

    func openAccountSettings() {
        router.present(for: .accountSettings)
    }

    func signOut() {
        Task { [weak self] in
            guard let self else { return }
            isLoading = true
            await revokeCurrentSession()
            isLoading = false
            delegate?.accountViewModelWantsToSignOut()
        }
    }

    func deleteAccount() {
        delegate?.accountViewModelWantsToDeleteAccount()
    }

    func openAccountRecovery() {
        delegate?.accountViewModelWantsToShowAccountRecovery { _ in
            self.refreshAccountRecovery()
        }
    }
}

private extension AccountViewModel {
    func handlePaymentsResult(result: PaymentsManager.PaymentsResult) {
        switch result {
        case let .success(inAppPurchasePlan):
            if inAppPurchasePlan != nil {
                refreshUserPlan()
            } else {
                logger
                    .debug("""
                    Payment is done but no plan is purchased.
                     Or purchase was cancelled.
                     Or completed, and sheet is being dismissed.
                    """)
            }
        case let .failure(error):
            logger.error(error)
        }
    }
}
