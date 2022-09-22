//
// TrashViewModel.swift
// Proton Pass - Created on 09/09/2022.
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
import ProtonCore_Login
import SwiftUI

final class TrashViewModel: BaseViewModel, DeinitPrintable, ObservableObject {
    @Published private(set) var state = State.idle
    @Published private(set) var items = [ItemListUiModel]()
    @Published var successMessage: String?

    private let symmetricKey: SymmetricKey
    private let shareRepository: ShareRepositoryProtocol
    private let itemRepository: ItemRepositoryProtocol

    var onToggleSidebar: (() -> Void)?
    var onShowOptions: ((ItemListUiModel) -> Void)?
    var onRestoredItem: (() -> Void)?
    var onDeletedItem: (() -> Void)?

    enum State {
        case idle
        case loading
        case loaded
        case error(Error)
    }

    var isEmpty: Bool {
        switch state {
        case .loaded:
            return items.isEmpty
        default:
            return true
        }
    }

    init(symmetricKey: SymmetricKey,
         shareRepository: ShareRepositoryProtocol,
         itemRepository: ItemRepositoryProtocol) {
        self.symmetricKey = symmetricKey
        self.shareRepository = shareRepository
        self.itemRepository = itemRepository
        super.init()
        fetchAllTrashedItems(forceRefresh: false)
    }

    func fetchAllTrashedItems(forceRefresh: Bool) {
        Task { @MainActor in
            do {
                // Only show loading indicator on first load
                switch state {
                case .error, .idle:
                    state = .loading
                default:
                    break
                }

                let encryptedItems = try await itemRepository.getItems(forceRefresh: forceRefresh, state: .trashed)

                items = try await encryptedItems.parallelMap { try await $0.toItemListUiModel(self.symmetricKey) }
                state = .loaded
            } catch {
                state = .error(error)
            }
        }
    }
}

// MARK: - Actions
extension TrashViewModel {
    func toggleSidebar() { onToggleSidebar?() }

    func restoreAllItems() {
        Task { @MainActor in
            do {
                isLoading = true
                let items = try await itemRepository.getItems(forceRefresh: false, state: .trashed)
                try await itemRepository.untrashItems(items)
                isLoading = false
                removeAllItems()
                successMessage = "\(items.count) items restored"
                onRestoredItem?()
            } catch {
                self.isLoading = false
                self.error = error
            }
        }
    }

    func emptyTrash() {
        Task { @MainActor in
            do {
                isLoading = true
                let items = try await itemRepository.getItems(forceRefresh: false, state: .trashed)
                try await itemRepository.deleteItems(items)
                isLoading = false
                removeAllItems()
                successMessage = "Trash emptied"
            } catch {
                self.isLoading = false
                self.error = error
            }
        }
    }

    func showOptions(_ item: ItemListUiModel) {
        onShowOptions?(item)
    }

    func restore(_ item: ItemListUiModel) {
        Task { @MainActor in
            do {
                guard let itemToBeRestored =
                        try await itemRepository.getItem(shareId: item.shareId,
                                                         itemId: item.itemId) else { return }
                isLoading = true
                try await itemRepository.untrashItems([itemToBeRestored])
                isLoading = false
                switch item.type {
                case .note:
                    successMessage = "Note restored"
                case .login:
                    successMessage = "Login restored"
                case .alias:
                    successMessage = "Alias restored"
                }
                remove(item)
                onRestoredItem?()
            } catch {
                self.isLoading = false
                self.error = error
            }
        }
    }

    func deletePermanently(_ item: ItemListUiModel) {
        Task { @MainActor in
            do {
                guard let itemToBeDeleted =
                        try await itemRepository.getItem(shareId: item.shareId,
                                                         itemId: item.itemId) else { return }
                isLoading = true
                try await itemRepository.deleteItems([itemToBeDeleted])
                isLoading = false
                switch item.type {
                case .note:
                    successMessage = "Note permanently deleted"
                case .login:
                    successMessage = "Login permanently deleted"
                case .alias:
                    successMessage = "Alias permanently deleted"
                }
                remove(item)
                onDeletedItem?()
            } catch {
                self.isLoading = false
                self.error = error
            }
        }
    }

    private func remove(_ item: ItemListUiModel) {
        items.removeAll(where: { $0.itemId == item.itemId })
    }

    private func removeAllItems() {
        items = []
    }
}
