// Generated using Sourcery 2.0.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// Proton Pass.
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
// swiftlint:disable all

@testable import Core
import Foundation

final class LogManagerProtocolMock: @unchecked Sendable, LogManagerProtocol {
    // MARK: - shouldLog
    var invokedShouldLogSetter = false
    var invokedShouldLogSetterCount = 0
    var invokedShouldLog: Bool?
    var invokedShouldLogList = [Bool?]()
    var invokedShouldLogGetter = false
    var invokedShouldLogGetterCount = 0
    var stubbedShouldLog: Bool!
    var shouldLog: Bool {
        set {
            invokedShouldLogSetter = true
            invokedShouldLogSetterCount += 1
            invokedShouldLog = newValue
            invokedShouldLogList.append(newValue)
        } get {
            invokedShouldLogGetter = true
            invokedShouldLogGetterCount += 1
            return stubbedShouldLog
        }
    }
    // MARK: - log
    var closureLog: () -> () = {}
    var invokedLog = false
    var invokedLogCount = 0
    var invokedLogParameters: (entry: LogEntry, Void)?
    var invokedLogParametersList = [(entry: LogEntry, Void)]()

    func log(entry: LogEntry) {
        invokedLog = true
        invokedLogCount += 1
        invokedLogParameters = (entry, ())
        invokedLogParametersList.append((entry, ()))
        closureLog()
    }
    // MARK: - getLogEntries
    var getLogEntriesThrowableError: Error?
    var closureGetLogEntries: () -> () = {}
    var invokedGetLogEntries = false
    var invokedGetLogEntriesCount = 0
    var stubbedGetLogEntriesResult: [LogEntry]!

    func getLogEntries() async throws -> [LogEntry] {
        invokedGetLogEntries = true
        invokedGetLogEntriesCount += 1
        if let error = getLogEntriesThrowableError {
            throw error
        }
        closureGetLogEntries()
        return stubbedGetLogEntriesResult
    }
    // MARK: - removeAllLogs
    var closureRemoveAllLogs: () -> () = {}
    var invokedRemoveAllLogs = false
    var invokedRemoveAllLogsCount = 0

    func removeAllLogs() {
        invokedRemoveAllLogs = true
        invokedRemoveAllLogsCount += 1
        closureRemoveAllLogs()
    }
    // MARK: - saveAllLogs
    var closureSaveAllLogs: () -> () = {}
    var invokedSaveAllLogs = false
    var invokedSaveAllLogsCount = 0

    func saveAllLogs() {
        invokedSaveAllLogs = true
        invokedSaveAllLogsCount += 1
        closureSaveAllLogs()
    }
    // MARK: - toggleLogging
    var closureToggleLogging: () -> () = {}
    var invokedToggleLogging = false
    var invokedToggleLoggingCount = 0
    var invokedToggleLoggingParameters: (shouldLog: Bool, Void)?
    var invokedToggleLoggingParametersList = [(shouldLog: Bool, Void)]()

    func toggleLogging(shouldLog: Bool) {
        invokedToggleLogging = true
        invokedToggleLoggingCount += 1
        invokedToggleLoggingParameters = (shouldLog, ())
        invokedToggleLoggingParametersList.append((shouldLog, ()))
        closureToggleLogging()
    }
}
