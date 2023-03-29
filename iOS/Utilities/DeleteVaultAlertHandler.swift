//
// DeleteVaultAlertHandler.swift
// Proton Pass - Created on 27/03/2023.
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
import Core
import UIKit

protocol DeleteVaultAlertHandlerDelegate: AnyObject {
    func confirmDelete(vault: Vault)
}

final class DeleteVaultAlertHandler: DeinitPrintable {
    deinit { print(deinitMessage) }

    private let alert: UIAlertController
    private let rootViewController: UIViewController
    private let vault: Vault
    private let delegate: DeleteVaultAlertHandlerDelegate

    init(rootViewController: UIViewController,
         vault: Vault,
         delegate: DeleteVaultAlertHandlerDelegate) {
        self.rootViewController = rootViewController
        self.vault = vault

        let alert = UIAlertController(title: "Permanently delete vault",
                                      // swiftlint:disable:next line_length
                                      message: "Vault \"\(vault.name)\" is not empty. Deleting this vault will also delete all its items. Please enter vault name to confirm.",
                                      preferredStyle: .alert)
        self.alert = alert
        self.delegate = delegate

        alert.addTextField { [unowned self] textField in
            textField.placeholder = "Confirm vault name"
            textField.addTarget(self, action: #selector(textDidChanged), for: .editingChanged)
        }

        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [unowned alert, delegate] _ in
            if alert.textFields?.first?.text == vault.name {
                delegate.confirmDelete(vault: vault)
            }
        }
        deleteAction.isEnabled = false
        alert.addAction(deleteAction)

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)
    }

    @objc
    private func textDidChanged(_ sender: UITextField) {
        alert.actions.first?.isEnabled = sender.text == vault.name
    }

    func showAlert() {
        rootViewController.present(alert, animated: true)
    }
}