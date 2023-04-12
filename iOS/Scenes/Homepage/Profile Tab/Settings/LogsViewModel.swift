//
// LogsViewModel.swift
// Proton Pass - Created on 31/03/2023.
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

import Core
import SwiftUI

protocol LogsViewModelDelegate: AnyObject {
    func logsViewModelWantsToShowSpinner()
    func logsViewModelWantsToHideSpinner()
    func logsViewModelWantsToShareLogs(_ url: URL)
    func logsViewModelDidEncounter(error: Error)
}

final class LogsViewModel: DeinitPrintable, ObservableObject {
    deinit {
        print(deinitMessage)
        if let fileToDelete {
            try? FileManager.default.removeItem(at: fileToDelete)
        }
    }

    @Published private(set) var isLoading = true
    @Published private(set) var entries = [LogEntry]()
    @Published private(set) var error: Error?

    var formattedEntries: [String] { entries.map(logFormatter.format(entry:)) }

    private var fileToDelete: URL?

    private let logManager: LogManager
    private let logFormatter: LogFormatter
    let module: PassLogModule

    weak var delegate: LogsViewModelDelegate?

    init(module: PassLogModule) {
        self.module = module
        self.logManager = .init(module: module)
        self.logFormatter = .default
        self.loadLogs()
    }

    func loadLogs() {
        Task { @MainActor in
            defer { isLoading = false }
            do {
                isLoading = true
                entries = try await logManager.getLogEntries()
                isLoading = false
            } catch {
                self.error = error
            }
        }
    }

    func shareLogs() {
        Task { @MainActor in
            do {
                delegate?.logsViewModelWantsToShowSpinner()
                let file = FileManager.default.temporaryDirectory.appendingPathComponent(module.logFileName)
                let log = await logFormatter.format(entries: entries)
                try log.write(to: file, atomically: true, encoding: .utf8)
                fileToDelete = file
                delegate?.logsViewModelWantsToHideSpinner()
                delegate?.logsViewModelWantsToShareLogs(file)
            } catch {
                delegate?.logsViewModelWantsToHideSpinner()
                delegate?.logsViewModelDidEncounter(error: error)
            }
        }
    }
}