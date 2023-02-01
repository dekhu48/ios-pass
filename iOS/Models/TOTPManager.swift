//
// TotpManager.swift
// Proton Pass - Created on 25/01/2023.
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
import SwiftOTP
import SwiftUI
import UIComponents

enum TOTPState: Equatable {
    case loading
    case empty
    case valid(TOTPData)
    case invalid
}

enum TOTPDataError: Error {
    case unsupportedOTP
    case failToDecodeSecret
    case failToGenerateTOTP
}

struct TOTPData: Equatable {
    let username: String
    let issuer: String?
    let code: String
    let timerData: TOTPTimerData
}

extension TOTPData {
    /// Init and calculate TOTP data of the current moment.
    /// Should only be used to quickly get TOTP data from a given URI in AutoFill context.
    init(uri: String) throws {
        let otpComponents = try URLUtils.OTPParser.parse(urlString: uri)
        guard otpComponents.type == .totp else {
            throw TOTPDataError.unsupportedOTP
        }

        guard let secretData = base32DecodeToData(otpComponents.secret) else {
            throw TOTPDataError.failToDecodeSecret
        }

        guard let totp = TOTP(secret: secretData,
                              digits: Int(otpComponents.digits),
                              timeInterval: Int(otpComponents.period),
                              algorithm: otpComponents.algorithm.otpAlgorithm) else {
            throw TOTPDataError.failToGenerateTOTP
        }
        self.username = otpComponents.label
        self.issuer = otpComponents.issuer
        let secondsPast1970 = Int(Date().timeIntervalSince1970)
        self.code = totp.generate(secondsPast1970: secondsPast1970) ?? ""
        self.timerData = totp.timerData(secondsPast1970: secondsPast1970)
    }
}

extension OTPComponents.Algorithm {
    var otpAlgorithm: OTPAlgorithm {
        switch self {
        case .sha1:
            return .sha1
        case .sha256:
            return .sha256
        case .sha512:
            return .sha512
        }
    }
}

final class TOTPManager: DeinitPrintable, ObservableObject {
    deinit {
        timer?.invalidate()
        print(deinitMessage)
    }

    private var timer: Timer?
    private let logger: Logger

    @Published private(set) var state = TOTPState.empty

    init(logManager: LogManager) {
        self.logger = .init(subsystem: Bundle.main.bundleIdentifier ?? "",
                            category: "\(Self.self)",
                            manager: logManager)
    }

    var totpData: TOTPData? {
        if case .valid(let data) = state {
            return data
        }
        return nil
    }

    func bind(uri: String) {
        timer?.invalidate()
        state = .loading
        guard !uri.isEmpty else {
            state = .empty
            return
        }

        do {
            let otpComponents = try URLUtils.OTPParser.parse(urlString: uri)
            guard otpComponents.type == .totp else {
                state = .invalid
                return
            }
            guard let secretData = base32DecodeToData(otpComponents.secret) else {
                state = .invalid
                return
            }

            guard let totp = TOTP(secret: secretData,
                                  digits: Int(otpComponents.digits),
                                  timeInterval: Int(otpComponents.period),
                                  algorithm: otpComponents.algorithm.otpAlgorithm) else {
                state = .invalid
                return
            }
            beginCaculating(totp: totp,
                            username: otpComponents.label,
                            issuer: otpComponents.issuer)
        } catch {
            logger.error(error)
            state = .invalid
        }
    }
}

private extension TOTPManager {
    func beginCaculating(totp: TOTP, username: String, issuer: String?) {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            let secondsPast1970 = Int(Date().timeIntervalSince1970)
            let code = totp.generate(secondsPast1970: secondsPast1970) ?? ""
            let timerData = totp.timerData(secondsPast1970: secondsPast1970)
            self?.state = .valid(.init(username: username,
                                       issuer: issuer,
                                       code: code,
                                       timerData: timerData))
        }
    }
}

extension TOTP {
    func timerData(secondsPast1970: Int = Int(Date().timeIntervalSince1970)) -> TOTPTimerData {
        let remainingSeconds = timeInterval - (secondsPast1970 % timeInterval)
        let code = generate(secondsPast1970: secondsPast1970) ?? ""
        return .init(total: timeInterval, remaining: remainingSeconds)
    }
}