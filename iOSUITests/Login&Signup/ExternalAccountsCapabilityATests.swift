//
//  ExternalAccountsCapabilityATests.swift
//  iOSUITests - Created on 12/23/22.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

import pmtest
import ProtonCore_Environment
import ProtonCore_QuarkCommands
import ProtonCore_TestingToolkit
import XCTest

final class ExternalAccountsCapabilityATests: LoginBaseTestCase {
    let welcomeRobot = WelcomeRobot()

    // Sign-in with internal account works
    // Sign-in with external account works
    // Sign-in with username account works (account is converted to internal under the hood)
    func testSignInWithInternalAccountWorks() {
        let doh = Environment.black.doh
        let randomUsername = StringUtils.randomAlphanumericString(length: 8)
        let randomPassword = StringUtils.randomAlphanumericString(length: 8)
        let expectQuarkCommandToFinish = expectation(description: "Quark command should finish")
        var quarkCommandResult: Result<CreatedAccountDetails, CreateAccountError>?
        QuarkCommands.create(account: .freeWithAddressAndKeys(username: randomUsername, password: randomPassword),
                             currentlyUsedHostUrl: Environment.black.doh.getCurrentlyUsedHostUrl()) { result in
            quarkCommandResult = result
            QuarkCommands.addPassScopeToUser(username: randomUsername,
                                             currentlyUsedHostUrl: doh.getCurrentlyUsedHostUrl()) { result in
                if case .failure(let error) = result {
                    XCTFail("\(error)")
                }
                expectQuarkCommandToFinish.fulfill()
            }
        }
        wait(for: [expectQuarkCommandToFinish], timeout: 5.0)
        if case .failure(let error) = quarkCommandResult {
            XCTFail("Internal account creation failed: \(error.userFacingMessageInQuarkCommands)")
            return
        }
        welcomeRobot.logIn()
            .fillUsername(username: randomUsername)
            .fillpassword(password: randomPassword)
            .signIn(robot: OnboardingRobot.self)
            .verify.isOnboardingViewShown()
    }

    func testSignInWithExternalAccountWorks() {
        let doh = Environment.black.doh
        let randomEmail = "\(StringUtils.randomAlphanumericString(length: 8))@proton.uitests"
        let randomPassword = StringUtils.randomAlphanumericString(length: 8)

        let expectQuarkCommandToFinish = expectation(description: "Quark command should finish")
        var quarkCommandResult: Result<CreatedAccountDetails, CreateAccountError>?
        QuarkCommands.create(account: .external(email: randomEmail, password: randomPassword),
                             currentlyUsedHostUrl: Environment.black.doh.getCurrentlyUsedHostUrl()) { result in
            quarkCommandResult = result
            QuarkCommands.addPassScopeToUser(username: randomEmail,
                                             currentlyUsedHostUrl: doh.getCurrentlyUsedHostUrl()) { result in
                if case .failure(let error) = result {
                    XCTFail("\(error)")
                }
                expectQuarkCommandToFinish.fulfill()
            }
        }
        wait(for: [expectQuarkCommandToFinish], timeout: 5.0)
        if case .failure(let error) = quarkCommandResult {
            XCTFail("External account creation failed: \(error.userFacingMessageInQuarkCommands)")
            return
        }
        welcomeRobot.logIn()
            .fillUsername(username: randomEmail)
            .fillpassword(password: randomPassword)
            .signIn(robot: OnboardingRobot.self)
            .verify.isOnboardingViewShown()
    }

    func testSignInWithUsernameAccountWorks() {
        let doh = Environment.black.doh
        let randomUsername = StringUtils.randomAlphanumericString(length: 8)
        let randomPassword = StringUtils.randomAlphanumericString(length: 8)
        let expectQuarkCommandToFinish = expectation(description: "Quark command should finish")
        var quarkCommandResult: Result<CreatedAccountDetails, CreateAccountError>?
        QuarkCommands.create(account: .freeNoAddressNoKeys(username: randomUsername, password: randomPassword),
                             currentlyUsedHostUrl: Environment.black.doh.getCurrentlyUsedHostUrl()) { result in
            quarkCommandResult = result
            QuarkCommands.addPassScopeToUser(username: randomUsername,
                                             currentlyUsedHostUrl: doh.getCurrentlyUsedHostUrl()) { result in
                if case .failure(let error) = result {
                    XCTFail("\(error)")
                }
                expectQuarkCommandToFinish.fulfill()
            }
        }
        wait(for: [expectQuarkCommandToFinish], timeout: 5.0)
        if case .failure(let error) = quarkCommandResult {
            XCTFail("Username account creation failed: \(error.userFacingMessageInQuarkCommands)")
            return
        }
        welcomeRobot.logIn()
            .fillUsername(username: randomUsername)
            .fillpassword(password: randomPassword)
            .signIn(robot: OnboardingRobot.self)
            .verify.isOnboardingViewShown()
    }

    // Sign-up with internal account works
    // The UI for sign-up with external account is not available
    // The UI for sign-up with username account is not available

    func testSignUpWithInternalAccountWorks() {
        let doh = Environment.black.doh
        let randomUsername = StringUtils.randomAlphanumericString(length: 8)
        let randomPassword = StringUtils.randomAlphanumericString(length: 8)
        let randomEmail = "\(StringUtils.randomAlphanumericString(length: 8))@proton.uitests"
        let summaryBot = welcomeRobot.logIn()
            .switchToCreateAccount()
            .verify.domainsButtonIsShown()
            .verify.signupScreenIsShown()
            .insertName(name: randomUsername)
            .nextButtonTap(robot: PasswordRobot.self)
            .verify.passwordScreenIsShown()
            .insertPassword(password: randomPassword)
            .insertRepeatPassword(password: randomPassword)
            .nextButtonTap(robot: RecoveryRobot.self)
            .verify.recoveryScreenIsShown()
            .skipButtonTap()
            .verify.recoveryDialogDisplay()
            .skipButtonTap(robot: SignupHumanVerificationV3Robot.self)
            .switchToEmailHVMethod()
            .performEmailVerificationV3(email: randomEmail, code: "666666", to: AccountSummaryRobot.self)
            .verify.startUsingPassButtonIsShown()
        QuarkCommands.addPassScopeToUser(username: randomUsername,
                                         currentlyUsedHostUrl: doh.getCurrentlyUsedHostUrl()) { result in
            if case .failure(let error) = result {
                XCTFail("\(error)")
            }
            _ = summaryBot
                .startUsingAppTap(robot: AccountSummaryRobot.self)
//                .verify.startUsingPassButtonIsShown()
//                .verify.isOnboardingViewShown()
        }
    }

    func testSignUpWithExternalAccountIsNotAvailable() {
        welcomeRobot.logIn()
            .switchToCreateAccount()
            .verify.otherAccountExtButtonIsNotShown()
    }

    func testSignUpWithUsernameAccountIsNotAvailable() {
        welcomeRobot.logIn()
            .switchToCreateAccount()
            .verify.domainsButtonIsShown()
    }
}

private let kDomainsButtonId = "SignupViewController.nextButton"

public extension SignupRobot.Verify {
    @discardableResult
    func domainsButtonIsShown() -> SignupRobot {
        button(kDomainsButtonId).checkExists()
        return SignupRobot()
    }
}