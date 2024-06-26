//
// AppCoordinator.swift
// Proton Pass - Created on 02/07/2022.
// Copyright (c) 2022 Proton Technologies AG
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
import CoreData
import CryptoKit
import Entities
import Factory
import Macro
import MBProgressHUD
import ProtonCoreAccountRecovery
import ProtonCoreAuthentication
import ProtonCoreFeatureFlags
import ProtonCoreKeymaker
import ProtonCoreLogin
import ProtonCoreNetworking
import ProtonCorePushNotifications
import ProtonCoreServices
import ProtonCoreUtilities
import Sentry
import SwiftUI
import UIKit

@MainActor
final class AppCoordinator {
    private let window: UIWindow
    private let appStateObserver: AppStateObserver
    private var isUITest: Bool

    private var homepageCoordinator: HomepageCoordinator?
    private var welcomeCoordinator: WelcomeCoordinator?
    private var rootViewController: UIViewController? { window.rootViewController }

    private var cancellables = Set<AnyCancellable>()

    private var preferences = resolve(\SharedToolingContainer.preferences)
    private let preferencesManager = resolve(\SharedToolingContainer.preferencesManager)
    private let appData = resolve(\SharedDataContainer.appData)
    private let logger = resolve(\SharedToolingContainer.logger)
    private let loginMethod = resolve(\SharedDataContainer.loginMethod)
    private let corruptedSessionEventStream = resolve(\SharedDataStreamContainer.corruptedSessionEventStream)
    private var corruptedSessionStream: AnyCancellable?
    private var featureFlagsRepository = resolve(\SharedRepositoryContainer.featureFlagsRepository)
    private var pushNotificationService = resolve(\ServiceContainer.pushNotificationService)

    @LazyInjected(\SharedToolingContainer.apiManager) private var apiManager
    @LazyInjected(\SharedUseCasesContainer.wipeAllData) private var wipeAllData

    private let sendErrorToSentry = resolve(\SharedUseCasesContainer.sendErrorToSentry)

    private var theme: Theme {
        preferencesManager.sharedPreferences.unwrapped().theme
    }

    init(window: UIWindow) {
        self.window = window
        appStateObserver = .init()

        isUITest = false
        clearUserDataInKeychainIfFirstRun()
        bindAppState()

        // if ui test reset everything
        if ProcessInfo.processInfo.arguments.contains("RunningInUITests") {
            resetAllData()
        }

        apiManager.sessionWasInvalidated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionUID in
                guard let self else { return }
                captureErrorAndLogOut(PassError.unexpectedLogout, sessionId: sessionUID)
            }
            .store(in: &cancellables)
    }

    deinit {
        corruptedSessionStream?.cancel()
        corruptedSessionStream = nil
    }

    // swiftlint:disable:next todo
    // TODO: Remove preferences and this function once session migration is done
    private func clearUserDataInKeychainIfFirstRun() {
        guard preferences.isFirstRun else { return }
        preferences.isFirstRun = false
        appData.setUserData(nil)
        appData.setCredential(nil)
    }

    private func bindAppState() {
        appStateObserver.$appState
            .receive(on: DispatchQueue.main)
            .dropFirst() // Don't react to default undefined state
            .sink { [weak self] appState in
                guard let self else { return }
                switch appState {
                case let .loggedOut(reason):
                    logger.info("Logged out \(reason)")
                    if reason != .noAuthSessionButUnauthSessionAvailable {
                        resetAllData()
                    }
                    showWelcomeScene(reason: reason)
                case .alreadyLoggedIn:
                    logger.info("Already logged in")
                    connectToCorruptedSessionStream()
                    showHomeScene(manualLogIn: false)
                    if let sessionID = appData.getCredential()?.sessionID {
                        registerForPushNotificationsIfNeededAndAddHandlers(uid: sessionID)
                    }
                case let .manuallyLoggedIn(userData):
                    logger.info("Logged in manual")
                    appData.setUserData(userData)
                    connectToCorruptedSessionStream()
                    showHomeScene(manualLogIn: true)
                    registerForPushNotificationsIfNeededAndAddHandlers(uid: userData.credential.sessionID)
                case .undefined:
                    logger.warning("Undefined app state. Don't know what to do...")
                }
            }
            .store(in: &cancellables)

        preferencesManager
            .sharedPreferencesUpdates
            .receive(on: DispatchQueue.main)
            .filter(\.theme)
            .sink { [weak self] theme in
                guard let self else { return }
                window.overrideUserInterfaceStyle = theme.userInterfaceStyle
            }
            .store(in: &cancellables)
    }

    /// Necessary set up like initializing preferences before starting user flow
    func setUpAndStart() {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await preferencesManager.setUp()
                window.overrideUserInterfaceStyle = theme.userInterfaceStyle
                start()
            } catch {
                appStateObserver.updateAppState(.loggedOut(.failedToInitializePreferences(error)))
            }
        }
    }
}

private extension AppCoordinator {
    func start() {
        if appData.isAuthenticated {
            appStateObserver.updateAppState(.alreadyLoggedIn)
        } else if appData.getCredential() != nil {
            appStateObserver.updateAppState(.loggedOut(.noAuthSessionButUnauthSessionAvailable))
        } else {
            appStateObserver.updateAppState(.loggedOut(.noSessionDataAtAll))
        }
    }

    func showWelcomeScene(reason: LogOutReason) {
        let welcomeCoordinator = WelcomeCoordinator(apiService: apiManager.apiService,
                                                    theme: theme)
        welcomeCoordinator.delegate = self
        self.welcomeCoordinator = welcomeCoordinator
        homepageCoordinator = nil
        animateUpdateRootViewController(welcomeCoordinator.rootViewController) { [weak self] in
            guard let self else { return }
            handle(logOutReason: reason)
            stopStream()
        }
    }

    func showHomeScene(manualLogIn: Bool) {
        Task { [weak self] in
            guard let self else {
                return
            }
            await loginMethod.setLogInFlow(newState: manualLogIn)
            let homepageCoordinator = HomepageCoordinator()
            homepageCoordinator.delegate = self
            self.homepageCoordinator = homepageCoordinator
            welcomeCoordinator = nil
            animateUpdateRootViewController(homepageCoordinator.rootViewController) {
                homepageCoordinator.onboardIfNecessary()
            }
        }
    }

    func animateUpdateRootViewController(_ newRootViewController: UIViewController,
                                         completion: (() -> Void)? = nil) {
        window.rootViewController = newRootViewController
        UIView.transition(with: window,
                          duration: 0.35,
                          options: .transitionCrossDissolve,
                          animations: nil) { _ in completion?() }
    }

    func resetAllData() {
        Task { [weak self] in
            guard let self else { return }
            await wipeAllData()
            SharedViewContainer.shared.reset()
        }
    }
}

// MARK: - Utils

private extension AppCoordinator {
    func connectToCorruptedSessionStream() {
        guard corruptedSessionStream == nil else {
            return
        }

        corruptedSessionStream = corruptedSessionEventStream
            .removeDuplicates()
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reason in
                guard let self else { return }
                captureErrorAndLogOut(PassError.corruptedSession(reason), sessionId: reason.sessionId)
            }
    }

    func stopStream() {
        corruptedSessionEventStream.send(nil)
        corruptedSessionStream?.cancel()
        corruptedSessionStream = nil
    }
}

private extension AppCoordinator {
    func registerForPushNotificationsIfNeededAndAddHandlers(uid: String) {
        guard featureFlagsRepository.isEnabled(CoreFeatureFlagType.pushNotifications, reloadValue: true)
        else { return }

        pushNotificationService.setup()
        pushNotificationService.registerForRemoteNotifications(uid: uid)

        guard featureFlagsRepository.isEnabled(CoreFeatureFlagType.accountRecovery, reloadValue: true)
        else { return }

        let passHandler = AccountRecoveryHandler()
        passHandler.handler = { [weak self] _ in
            guard let self else { return .failure(.couldNotOpenAccountRecoveryURL) }
            homepageCoordinator?.accountViewModelWantsToShowAccountRecovery { _ in }
            return .success
        }

        for accountRecoveryType in NotificationType.allAccountRecoveryTypes {
            pushNotificationService.registerHandler(passHandler, forType: accountRecoveryType)
        }
    }
}

private extension AppCoordinator {
    /// Show an alert with a single "OK" button that does nothing
    func alert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(.init(title: #localized("OK"), style: .default))
        rootViewController?.present(alert, animated: true)
    }

    func handle(logOutReason: LogOutReason) {
        switch logOutReason {
        case .expiredRefreshToken, .sessionInvalidated:
            alert(title: #localized("Your session is expired"),
                  message: #localized("Please log in again"))
        case .failedBiometricAuthentication:
            alert(title: #localized("Failed to authenticate"),
                  message: #localized("Please log in again"))
        case let .failedToInitializePreferences(error):
            alert(title: #localized("Error occured"), message: error.localizedDescription)
        default:
            break
        }
    }

    func captureErrorAndLogOut(_ error: any Error, sessionId: String) {
        sendErrorToSentry(error, sessionId: sessionId)
        appStateObserver.updateAppState(.loggedOut(.sessionInvalidated))
    }
}

// MARK: - WelcomeCoordinatorDelegate

extension AppCoordinator: WelcomeCoordinatorDelegate {
    func welcomeCoordinator(didFinishWith userData: LoginData) {
        appStateObserver.updateAppState(.manuallyLoggedIn(userData))
    }
}

// MARK: - HomepageCoordinatorDelegate

extension AppCoordinator: HomepageCoordinatorDelegate {
    func homepageCoordinatorWantsToLogOut() {
        appStateObserver.updateAppState(.loggedOut(.userInitiated))
    }

    func homepageCoordinatorDidFailLocallyAuthenticating() {
        appStateObserver.updateAppState(.loggedOut(.failedBiometricAuthentication))
    }
}
