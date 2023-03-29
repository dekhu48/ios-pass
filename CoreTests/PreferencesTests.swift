//
// PreferencesTests.swift
// Proton Pass - Created on 02/03/2023.
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

@testable import Core
import XCTest

extension UserDefaults {
    func reset() {
        dictionaryRepresentation().keys.forEach(removeObject(forKey:))
    }
}

final class PreferencesTests: XCTestCase {
    private var sut: Preferences!

    override func setUp() {
        super.setUp()
        sut = .init()
    }

    override func tearDown() {
        kSharedUserDefaults?.reset()
        super.tearDown()
    }

    func testQuickTypeBarEnabledByDefault() {
        XCTAssertTrue(sut.quickTypeBar)
    }

    func testQuickTypeBarEnabledAfterResetting() {
        sut.quickTypeBar = false
        XCTAssertFalse(sut.quickTypeBar)
        sut.reset()
        XCTAssertTrue(sut.quickTypeBar)
    }

    func testAutomaticallyCopyTotpCodeDisabledByDefault() {
        XCTAssertFalse(sut.automaticallyCopyTotpCode)
    }

    func testAutomaticallyCopyTotpCodeDisabledAfterResetting() {
        sut.automaticallyCopyTotpCode = true
        XCTAssertTrue(sut.automaticallyCopyTotpCode)
        sut.reset()
        XCTAssertFalse(sut.automaticallyCopyTotpCode)
    }

    func testFailedAttemptCountZeroByDefault() {
        XCTAssertEqual(sut.failedAttemptCount, 0)
    }

    func testFailedAttempCountZeroAfterResetting() {
        sut.failedAttemptCount = 1
        XCTAssertEqual(sut.failedAttemptCount, 1)
        sut.failedAttemptCount = 2
        XCTAssertEqual(sut.failedAttemptCount, 2)
        sut.reset()
        XCTAssertEqual(sut.failedAttemptCount, 0)
    }

    func testBiometricAuthenticationDisabledByDefault() {
        XCTAssertFalse(sut.biometricAuthenticationEnabled)
    }

    func testBiometricAuthenticationDisabledAfterResetting() {
        sut.biometricAuthenticationEnabled = true
        XCTAssertTrue(sut.biometricAuthenticationEnabled)
        sut.reset()
        XCTAssertFalse(sut.biometricAuthenticationEnabled)
    }

    func testNotOnboardedByDefault() {
        XCTAssertFalse(sut.onboarded)
    }

    func testOnboardJustOnce() {
        sut.onboarded = true
        XCTAssertTrue(sut.onboarded)
        sut.reset()
        XCTAssertTrue(sut.onboarded)
    }

    func testOnboardOnEveryUITestCase() {
        sut.onboarded = true
        XCTAssertTrue(sut.onboarded)
        sut.reset(isUITests: true)
        XCTAssertFalse(sut.onboarded)
    }

    func testAutoFillBannerNotDisplayedByDefault() {
        XCTAssertFalse(sut.autoFillBannerDisplayed)
    }

    func testAutoFillBannerDisplayedAgainAfterResetting() {
        sut.autoFillBannerDisplayed = true
        XCTAssertTrue(sut.autoFillBannerDisplayed)
        sut.reset()
        XCTAssertFalse(sut.autoFillBannerDisplayed)
    }

    func testThemeIsDarkByDefault() {
        XCTAssertEqual(sut.theme, .dark)
    }

    func testThemeIsDarkAfterResetting() {
        sut.theme = .light
        XCTAssertEqual(sut.theme, .light)
        sut.theme = .matchSystem
        XCTAssertEqual(sut.theme, .matchSystem)
        sut.reset()
        XCTAssertEqual(sut.theme, .dark)
    }

    func testBrowserIsSafariByDefault() {
        XCTAssertEqual(sut.browser, .safari)
    }

    func testBrowserIsSafariAfterResetting() {
        sut.browser = .brave
        XCTAssertEqual(sut.browser, .brave)
        sut.browser = .duckDuckGo
        XCTAssertEqual(sut.browser, .duckDuckGo)
        sut.reset()
        XCTAssertEqual(sut.browser, .safari)
    }

    func testClipboardExpiresAfter30SecondsByDefault() {
        XCTAssertEqual(sut.clipboardExpiration, .thirtySeconds)
    }

    func testClipboardExpiresAfter40SecondsAfterResetting() {
        sut.clipboardExpiration = .fifteenSeconds
        XCTAssertEqual(sut.clipboardExpiration, .fifteenSeconds)
        sut.reset()
        XCTAssertEqual(sut.clipboardExpiration, .thirtySeconds)
    }

    func testDoNotShareClipboardByDefault() {
        XCTAssertFalse(sut.shareClipboard)
    }

    func testDoNotShareClipboardAfterResetting() {
        sut.shareClipboard = true
        XCTAssertTrue(sut.shareClipboard)
        sut.reset()
        XCTAssertFalse(sut.shareClipboard)
    }

    func testAskBeforeTrashingByDefault() {
        XCTAssertTrue(sut.askBeforeTrashing)
    }

    func testAskBeforeTrashingAfterResetting() {
        sut.askBeforeTrashing = false
        XCTAssertFalse(sut.askBeforeTrashing)
        sut.reset()
        XCTAssertTrue(sut.askBeforeTrashing)
    }

    func testIsFirstRunByDefault() {
        XCTAssertTrue(sut.isFirstRun)
    }

    func testNoMoreFirstRunAfterResetting() {
        sut.isFirstRun = false
        XCTAssertFalse(sut.isFirstRun)
        sut.reset()
        XCTAssertFalse(sut.isFirstRun)
    }
}