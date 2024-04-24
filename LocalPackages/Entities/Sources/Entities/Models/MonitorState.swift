//
// MonitorState.swift
// Proton Pass - Created on 19/04/2024.
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

import Foundation

public enum MonitorState: Sendable, Equatable {
    case active(MonitorBreachState)
    case inactive(MonitorBreachState)

    public static var `default`: Self {
        .inactive(.noBreaches)
    }

    public var breachCount: Int? {
        switch self {
        case let .active(state):
            state.breachCount
        case let .inactive(state):
            state.breachCount
        }
    }
}

public enum MonitorBreachState: Sendable, Equatable {
    case noBreaches
    case noBreachesButWeakOrReusedPasswords
    case breachesFound(Int)

    public var breachCount: Int? {
        if case let .breachesFound(count) = self {
            count
        } else {
            nil
        }
    }
}