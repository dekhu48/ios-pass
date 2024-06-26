//
// ProfileTabViewModel.swift
// Proton Pass - Created on 07/03/2023.
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
import ProtonCoreServices
import SwiftUI

@MainActor
protocol ProfileTabViewModelDelegate: AnyObject {
    func profileTabViewModelWantsToShowAccountMenu()
    func profileTabViewModelWantsToShowSettingsMenu()
    func profileTabViewModelWantsToShowFeedback()
    func profileTabViewModelWantsToQaFeatures()
}

@MainActor
final class ProfileTabViewModel: ObservableObject, DeinitPrintable {
    deinit { print(deinitMessage) }

    private let credentialManager = resolve(\SharedServiceContainer.credentialManager)
    private let logger = resolve(\SharedToolingContainer.logger)
    private let preferencesManager = resolve(\SharedToolingContainer.preferencesManager)
    private let accessRepository = resolve(\SharedRepositoryContainer.accessRepository)
    private let organizationRepository = resolve(\SharedRepositoryContainer.organizationRepository)
    private let notificationService = resolve(\SharedServiceContainer.notificationService)
    private let securitySettingsCoordinator: SecuritySettingsCoordinator

    private let policy = resolve(\SharedToolingContainer.localAuthenticationEnablingPolicy)
    private let checkBiometryType = resolve(\SharedUseCasesContainer.checkBiometryType)
    private let router = resolve(\SharedRouterContainer.mainUIKitSwiftUIRouter)

    // Use cases
    private let indexAllLoginItems = resolve(\SharedUseCasesContainer.indexAllLoginItems)
    private let unindexAllLoginItems = resolve(\SharedUseCasesContainer.unindexAllLoginItems)
    private let openAutoFillSettings = resolve(\UseCasesContainer.openAutoFillSettings)
    private let getSharedPreferences = resolve(\SharedUseCasesContainer.getSharedPreferences)
    private let updateSharedPreferences = resolve(\SharedUseCasesContainer.updateSharedPreferences)

    @Published private(set) var localAuthenticationMethod: LocalAuthenticationMethodUiModel = .none
    @Published private(set) var appLockTime: AppLockTime
    @Published private(set) var canUpdateAppLockTime = true
    @Published private(set) var fallbackToPasscode: Bool
    /// Whether user has picked Proton Pass as AutoFill provider in Settings
    @Published private(set) var autoFillEnabled = false
    @Published private(set) var quickTypeBar: Bool
    @Published private(set) var automaticallyCopyTotpCode: Bool
    @Published private(set) var showAutomaticCopyTotpCodeExplanation = false
    @Published private(set) var plan: Plan?

    private var cancellables = Set<AnyCancellable>()
    weak var delegate: (any ProfileTabViewModelDelegate)?

    init(childCoordinatorDelegate: any ChildCoordinatorDelegate) {
        let securitySettingsCoordinator = SecuritySettingsCoordinator()
        securitySettingsCoordinator.delegate = childCoordinatorDelegate
        self.securitySettingsCoordinator = securitySettingsCoordinator

        let preferences = getSharedPreferences()
        appLockTime = preferences.appLockTime
        fallbackToPasscode = preferences.fallbackToPasscode
        quickTypeBar = preferences.quickTypeBar
        automaticallyCopyTotpCode = preferences.automaticallyCopyTotpCode && preferences
            .localAuthenticationMethod != .none
        refresh()
        setUp()
    }
}

// MARK: - Public APIs

extension ProfileTabViewModel {
    func upgrade() {
        router.present(for: .upgradeFlow)
    }

    func refreshPlan() async {
        do {
            // First get local plan to optimistically display it
            // and then try to refresh the plan to have it updated
            plan = try await accessRepository.getPlan()
            plan = try await accessRepository.refreshAccess().plan
        } catch {
            handle(error: error)
        }
    }

    func editLocalAuthenticationMethod() {
        Task { [weak self] in
            guard let self else {
                return
            }
            securitySettingsCoordinator.editMethod()
        }
    }

    func editAppLockTime() {
        guard canUpdateAppLockTime else { return }
        Task { [weak self] in
            guard let self else {
                return
            }
            securitySettingsCoordinator.editAppLockTime()
        }
    }

    func editPINCode() {
        Task { [weak self] in
            guard let self else {
                return
            }
            securitySettingsCoordinator.editPINCode()
        }
    }

    func handleEnableAutoFillAction() {
        openAutoFillSettings()
    }

    func toggleFallbackToPasscode() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let newValue = !fallbackToPasscode
                try await updateSharedPreferences(\.fallbackToPasscode, value: newValue)
                fallbackToPasscode = newValue
            } catch {
                handle(error: error)
            }
        }
    }

    func toggleQuickTypeBar() {
        Task { [weak self] in
            guard let self else { return }
            defer { router.display(element: .globalLoading(shouldShow: false)) }
            do {
                router.display(element: .globalLoading(shouldShow: true))
                let newValue = !quickTypeBar
                async let updateSharedPreferences: () = updateSharedPreferences(\.quickTypeBar,
                                                                                value: newValue)
                async let reindex: () = reindexCredentials(newValue)
                _ = try await (updateSharedPreferences, reindex)
                quickTypeBar = newValue
            } catch {
                handle(error: error)
            }
        }
    }

    func toggleAutomaticCopyTotpCode() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let localAuthenticationMethod = getSharedPreferences().localAuthenticationMethod
                if !automaticallyCopyTotpCode, localAuthenticationMethod == .none {
                    showAutomaticCopyTotpCodeExplanation = true
                    return
                }
                let newValue = !automaticallyCopyTotpCode
                if newValue {
                    notificationService.requestNotificationPermission()
                }
                try await updateSharedPreferences(\.automaticallyCopyTotpCode, value: newValue)
                automaticallyCopyTotpCode = newValue && localAuthenticationMethod != .none
            } catch {
                handle(error: error)
            }
        }
    }

    func showAccountMenu() {
        delegate?.profileTabViewModelWantsToShowAccountMenu()
    }

    func showSettingsMenu() {
        delegate?.profileTabViewModelWantsToShowSettingsMenu()
    }

    func showPrivacyPolicy() {
        router.navigate(to: .urlPage(urlString: ProtonLink.privacyPolicy))
    }

    func showTermsOfService() {
        router.navigate(to: .urlPage(urlString: ProtonLink.termsOfService))
    }

    func showImportInstructions() {
        router.navigate(to: .urlPage(urlString: ProtonLink.howToImport))
    }

    func showImportExportFlow() {
        router.present(for: .importExport)
    }

    func showTutorial() {
        router.present(for: .tutorial)
    }

    func showFeedback() {
        delegate?.profileTabViewModelWantsToShowFeedback()
    }

    func qaFeatures() {
        delegate?.profileTabViewModelWantsToQaFeatures()
    }
}

// MARK: - Private APIs

private extension ProfileTabViewModel {
    func setUp() {
        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                refresh()
            }
            .store(in: &cancellables)

        preferencesManager
            .sharedPreferencesUpdates
            .receive(on: DispatchQueue.main)
            .filter(\.appLockTime)
            .sink { [weak self] newValue in
                guard let self else { return }
                appLockTime = newValue
            }
            .store(in: &cancellables)

        preferencesManager
            .sharedPreferencesUpdates
            .receive(on: DispatchQueue.main)
            .filter(\.localAuthenticationMethod)
            .sink { [weak self] _ in
                guard let self else { return }
                refreshLocalAuthenticationMethod()
                showAutomaticCopyTotpCodeExplanation = false
            }
            .store(in: &cancellables)

        $plan
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .removeDuplicates()
            .sink { [weak self] plan in
                guard let self else { return }
                if plan.isBusinessUser {
                    applyOrganizationSettings()
                }
            }
            .store(in: &cancellables)
    }

    func refresh() {
        Task { [weak self] in
            guard let self else { return }
            autoFillEnabled = await credentialManager.isAutoFillEnabled
            refreshLocalAuthenticationMethod()
        }
    }

    func refreshLocalAuthenticationMethod() {
        switch getSharedPreferences().localAuthenticationMethod {
        case .none:
            localAuthenticationMethod = .none
            automaticallyCopyTotpCode = false
        case .biometric:
            do {
                let biometryType = try checkBiometryType(policy: policy)
                localAuthenticationMethod = .biometric(biometryType)
            } catch {
                // Fallback to `none`, not much we can do except displaying the error
                logger.error(error)
                router.display(element: .displayErrorBanner(error))
                localAuthenticationMethod = .none
            }
        case .pin:
            localAuthenticationMethod = .pin
        }
    }

    func applyOrganizationSettings() {
        Task { [weak self] in
            guard let self else { return }
            do {
                if let organization = try await organizationRepository.getOrganization() {
                    canUpdateAppLockTime = organization.settings?.appLockTime == nil
                }
            } catch {
                handle(error: error)
            }
        }
    }

    func reindexCredentials(_ indexable: Bool) async throws {
        // When not enabled, iOS already deleted the credential database.
        // Atempting to populate this database will throw an error anyway so early exit here
        guard autoFillEnabled else { return }
        logger.trace("Reindexing credentials")
        if indexable {
            try await indexAllLoginItems()
        } else {
            try await unindexAllLoginItems()
        }
        logger.info("Reindexed credentials")
    }

    func handle(error: any Error) {
        logger.error(error)
        router.display(element: .displayErrorBanner(error))
    }
}
