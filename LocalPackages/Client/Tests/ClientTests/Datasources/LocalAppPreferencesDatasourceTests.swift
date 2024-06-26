//
// LocalAppPreferencesDatasourceTests.swift
// Proton Pass - Created on 03/04/2024.
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

@testable import Client
import Entities
import Foundation
import XCTest

final class LocalAppPreferencesDatasourceTests: XCTestCase {
    var sut: LocalAppPreferencesDatasourceProtocol!

    override func setUp() {
        super.setUp()
        let userDefaults = UserDefaults.standard
        userDefaults.removeAllObjects()
        sut = LocalAppPreferencesDatasource(userDefault: userDefaults)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }
}

extension LocalAppPreferencesDatasourceTests {
    func testGetAndUpsertPreferences() throws {
        try XCTAssertNil(sut.getPreferences())

        let givenPrefs = AppPreferences.random()
        try sut.upsertPreferences(givenPrefs)

        let result1 = try XCTUnwrap(sut.getPreferences())
        XCTAssertEqual(result1, givenPrefs)

        let updatedPrefs = AppPreferences.random()
        try sut.upsertPreferences(updatedPrefs)
        let result2 = try XCTUnwrap(sut.getPreferences())
        XCTAssertEqual(result2, updatedPrefs)

        sut.removePreferences()
        try XCTAssertNil(sut.getPreferences())
    }
}
