//
// BaseItemDetailViewModel.swift
// Proton Pass - Created on 08/09/2022.
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
import Core
import CryptoKit
import UIKit

let kItemDetailSectionPadding: CGFloat = 16

protocol ItemDetailViewModelDelegate: AnyObject {
    func itemDetailViewModelWantsToShowSpinner()
    func itemDetailViewModelWantsToHideSpinner()
    func itemDetailViewModelWantsToGoBack()
    func itemDetailViewModelWantsToEditItem(_ itemContent: ItemContent)
    func itemDetailViewModelWantsToCopy(text: String, bannerMessage: String)
    func itemDetailViewModelWantsToShowFullScreen(_ text: String)
    func itemDetailViewModelWantsToOpen(urlString: String)
    func itemDetailViewModelDidMoveToTrash(item: ItemTypeIdentifiable)
    func itemDetailViewModelDidRestore(item: ItemTypeIdentifiable)
    func itemDetailViewModelDidPermanentlyDelete(item: ItemTypeIdentifiable)
    func itemDetailViewModelDidFail(_ error: Error)
}

class BaseItemDetailViewModel {
    let itemRepository: ItemRepositoryProtocol
    private(set) var itemContent: ItemContent
    let logger: Logger

    weak var delegate: ItemDetailViewModelDelegate?

    private var symmetricKey: SymmetricKey { itemRepository.symmetricKey }

    init(itemContent: ItemContent,
         itemRepository: ItemRepositoryProtocol,
         logManager: LogManager) {
        self.itemContent = itemContent
        self.itemRepository = itemRepository
        self.logger = .init(subsystem: Bundle.main.bundleIdentifier ?? "",
                            category: "\(Self.self)",
                            manager: logManager)
        self.bindValues()
    }

    /// To be overidden by subclasses
    func bindValues() {}

    /// Copy to clipboard and trigger a toast message
    /// - Parameters:
    ///    - text: The text to be copied to clipboard.
    ///    - message: The message of the toast (e.g. "Note copied", "Alias copied")
    func copyToClipboard(text: String, message: String) {
        delegate?.itemDetailViewModelWantsToCopy(text: text, bannerMessage: message)
    }

    func goBack() {
        delegate?.itemDetailViewModelWantsToGoBack()
    }

    func edit() {
        delegate?.itemDetailViewModelWantsToEditItem(itemContent)
    }

    func refresh() {
        Task { @MainActor in
            guard let updatedItemContent =
                    try await itemRepository.getDecryptedItemContent(shareId: itemContent.shareId,
                                                                     itemId: itemContent.item.itemID) else {
                return
            }
            itemContent = updatedItemContent
            bindValues()
        }
    }

    func showLarge(_ text: String) {
        delegate?.itemDetailViewModelWantsToShowFullScreen(text)
    }

    func copyNote(_ text: String) {
        copyToClipboard(text: text, message: "Note copied")
    }

    func moveToTrash() {
        Task { @MainActor in
            defer { delegate?.itemDetailViewModelWantsToHideSpinner() }
            do {
                logger.trace("Trashing \(itemContent.debugInformation)")
                delegate?.itemDetailViewModelWantsToShowSpinner()
                let encryptedItem = try await getItemTask(item: itemContent).value
                let item = try encryptedItem.getDecryptedItemContent(symmetricKey: symmetricKey)
                try await itemRepository.trashItems([encryptedItem])
                delegate?.itemDetailViewModelDidMoveToTrash(item: item)
                logger.info("Trashed \(item.debugInformation)")
            } catch {
                logger.error(error)
                delegate?.itemDetailViewModelDidFail(error)
            }
        }
    }

    func restore() {
        Task { @MainActor in
            defer { delegate?.itemDetailViewModelWantsToHideSpinner() }
            do {
                logger.trace("Restoring \(itemContent.debugInformation)")
                delegate?.itemDetailViewModelWantsToShowSpinner()
                let encryptedItem = try await getItemTask(item: itemContent).value
                let symmetricKey = itemRepository.symmetricKey
                let item = try encryptedItem.getDecryptedItemContent(symmetricKey: symmetricKey)
                try await itemRepository.untrashItems([encryptedItem])
                delegate?.itemDetailViewModelDidRestore(item: item)
                logger.info("Restored \(item.debugInformation)")
            } catch {
                logger.error(error)
                delegate?.itemDetailViewModelDidFail(error)
            }
        }
    }

    func permanentlyDelete() {
        Task { @MainActor in
            defer { delegate?.itemDetailViewModelWantsToHideSpinner() }
            do {
                logger.trace("Permanently deleting \(itemContent.debugInformation)")
                delegate?.itemDetailViewModelWantsToShowSpinner()
                let encryptedItem = try await getItemTask(item: itemContent).value
                let symmetricKey = itemRepository.symmetricKey
                let item = try encryptedItem.getDecryptedItemContent(symmetricKey: symmetricKey)
                try await itemRepository.deleteItems([encryptedItem], skipTrash: false)
                delegate?.itemDetailViewModelDidPermanentlyDelete(item: item)
                logger.info("Permanently deleted \(item.debugInformation)")
            } catch {
                logger.error(error)
                delegate?.itemDetailViewModelDidFail(error)
            }
        }
    }
}

private extension BaseItemDetailViewModel {
    func getItemTask(item: ItemIdentifiable) -> Task<SymmetricallyEncryptedItem, Error> {
        Task.detached(priority: .userInitiated) {
            guard let item = try await self.itemRepository.getItem(shareId: item.shareId,
                                                                   itemId: item.itemId) else {
                throw PPError.itemNotFound(shareID: item.shareId, itemID: item.itemId)
            }
            return item
        }
    }
}