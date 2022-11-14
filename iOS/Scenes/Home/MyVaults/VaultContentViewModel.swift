//
// VaultContentViewModel.swift
// Proton Pass - Created on 21/07/2022.
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
import SwiftUI

enum VaultContentViewModelError: Error {
    case itemNotFound(shareId: String, itemId: String)
    case noSelectedVault
}

extension VaultContentViewModel {
    enum State {
        case loading
        case loaded
        case error(Error)

        var isLoaded: Bool {
            switch self {
            case .loaded:
                return true
            default:
                return false
            }
        }
    }
}

protocol VaultContentViewModelDelegate: AnyObject {
    func vaultContentViewModelWantsToToggleSidebar()
    func vaultContentViewModelWantsToSearch()
    func vaultContentViewModelWantsToCreateItem()
    func vaultContentViewModelWantsToCreateVault()
    func vaultContentViewModelWantsToShowItemDetail(_ item: ItemContent)
    func vaultContentViewModelWantsToEditItem(_ item: ItemContent)
    func vaultContentViewModelDidTrashItem(_ type: ItemContentType)
    func vaultContentViewModelWantsToShowSuccessMessage(_ message: String)
}

// MARK: - Initialization
final class VaultContentViewModel: BaseViewModel, DeinitPrintable, ObservableObject {
    deinit { print(deinitMessage) }

    @Published private(set) var state = State.loading
    @Published private(set) var items = [ItemListUiModel]()
    @Published var sortType = SortType.modifyTime { didSet { sortItems() } }
    @Published var sortDirection = SortDirection.descending { didSet { sortItems() } }

    private let vaultSelection: VaultSelection
    private let itemRepository: ItemRepositoryProtocol
    private let symmetricKey: SymmetricKey

    weak var itemCountDelegate: ItemCountDelegate?

    var selectedVault: VaultProtocol? { vaultSelection.selectedVault }
    var vaults: [VaultProtocol] { vaultSelection.vaults }

    weak var vaultContentViewModelDelegate: VaultContentViewModelDelegate?

    init(vaultSelection: VaultSelection,
         itemRepository: ItemRepositoryProtocol,
         symmetricKey: SymmetricKey) {
        self.vaultSelection = vaultSelection
        self.itemRepository = itemRepository
        self.symmetricKey = symmetricKey
        super.init()

        vaultSelection.objectWillChange
            .sink { [unowned self] _ in
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func sortItems() {
        items.sort(type: sortType, direction: sortDirection)
    }
}

// MARK: - Public actions
extension VaultContentViewModel {
    func toggleSidebar() {
        vaultContentViewModelDelegate?.vaultContentViewModelWantsToToggleSidebar()
    }

    func createItem() {
        vaultContentViewModelDelegate?.vaultContentViewModelWantsToCreateItem()
    }

    func search() {
        vaultContentViewModelDelegate?.vaultContentViewModelWantsToSearch()
    }

    @MainActor
    func forceRefreshItems() async {
        do {
            items = try await getItemsTask(forceRefresh: true).value
        } catch {
            state = .error(error)
        }
    }

    func fetchItems(forceRefresh: Bool) {
        Task { @MainActor in
            if case .error = state {
                state = .loading
            }

            do {
                items = try await getItemsTask(forceRefresh: forceRefresh).value
                state = .loaded
            } catch {
                state = .error(error)
            }
        }
    }

    func selectItem(_ item: ItemListUiModel) {
        Task { @MainActor in
            do {
                let itemContent = try await getDecryptedItemContentTask(for: item).value
                vaultContentViewModelDelegate?.vaultContentViewModelWantsToShowItemDetail(itemContent)
            } catch {
                self.error = error
            }
        }
    }

    func editItem(_ item: ItemListUiModel) {
        Task { @MainActor in
            do {
                let itemContent = try await getDecryptedItemContentTask(for: item).value
                vaultContentViewModelDelegate?.vaultContentViewModelWantsToEditItem(itemContent)
            } catch {
                self.error = error
            }
        }
    }

    func copyUsername(_ item: ItemListUiModel) {
        guard case .login = item.type else { return }
        Task { @MainActor in
            do {
                let itemContent = try await getDecryptedItemContentTask(for: item).value
                if case let .login(username, _, _) = itemContent.contentData {
                    UIPasteboard.general.string = username
                    let message = "Username copied to clipboard"
                    vaultContentViewModelDelegate?.vaultContentViewModelWantsToShowSuccessMessage(message)
                }
            } catch {
                self.error = error
            }
        }
    }

    func copyPassword(_ item: ItemListUiModel) {
        guard case .login = item.type else { return }
        Task { @MainActor in
            do {
                let itemContent = try await getDecryptedItemContentTask(for: item).value
                if case let .login(_, password, _) = itemContent.contentData {
                    UIPasteboard.general.string = password
                    let message = "Password copied to clipboard"
                    vaultContentViewModelDelegate?.vaultContentViewModelWantsToShowSuccessMessage(message)
                }
            } catch {
                self.error = error
            }
        }
    }

    func copyEmailAddress(_ item: ItemListUiModel) {
        guard case .alias = item.type else { return }
        Task { @MainActor in
            do {
                let item = try await getItem(shareId: item.shareId, itemId: item.itemId)
                if let emailAddress = item.item.aliasEmail {
                    UIPasteboard.general.string = emailAddress
                    let message = "Email address copied to clipboard"
                    vaultContentViewModelDelegate?.vaultContentViewModelWantsToShowSuccessMessage(message)
                }
            } catch {
                self.error = error
            }
        }
    }

    func trashItem(_ item: ItemListUiModel) {
        Task { @MainActor in
            defer { isLoading = false }
            isLoading = true
            do {
                try await trashItemTask(for: item).value
                fetchItems(forceRefresh: false)
                vaultContentViewModelDelegate?.vaultContentViewModelDidTrashItem(item.type)
            } catch {
                self.error = error
            }
        }
    }
}

// MARK: - Private supporting tasks
private extension VaultContentViewModel {
    func getItemsTask(forceRefresh: Bool) -> Task<[ItemListUiModel], Error> {
        Task.detached(priority: .userInitiated) {
            guard let shareId = self.vaultSelection.selectedVault?.shareId else {
                throw VaultContentViewModelError.noSelectedVault
            }
            let encryptedItems = try await self.itemRepository.getItems(forceRefresh: forceRefresh,
                                                                        shareId: shareId,
                                                                        state: .active)
            var items = try await encryptedItems.parallelMap { try await $0.toItemListUiModel(self.symmetricKey) }
            items.sort(type: self.sortType, direction: self.sortDirection)
            self.itemCountDelegate?.itemCountDidUpdate(items.generateItemCount())
            return items
        }
    }

    func getDecryptedItemContentTask(for item: ItemListUiModel) -> Task<ItemContent, Error> {
        Task.detached(priority: .userInitiated) {
            let encryptedItem = try await self.getItem(shareId: item.shareId, itemId: item.itemId)
            return try encryptedItem.getDecryptedItemContent(symmetricKey: self.symmetricKey)
        }
    }

    func trashItemTask(for item: ItemListUiModel) -> Task<Void, Error> {
        Task.detached(priority: .userInitiated) {
            let itemToBeTrashed = try await self.getItem(shareId: item.shareId, itemId: item.itemId)
            try await self.itemRepository.trashItems([itemToBeTrashed])
        }
    }

    func getItem(shareId: String, itemId: String) async throws -> SymmetricallyEncryptedItem {
        guard let item = try await itemRepository.getItem(shareId: shareId,
                                                          itemId: itemId) else {
            throw VaultContentViewModelError.itemNotFound(shareId: shareId, itemId: itemId)
        }
        return item
    }
}

private extension Array where Element == ItemListUiModel {
    mutating func sort(type: SortType, direction: SortDirection) {
        sort { lhs, rhs in
            switch (type, direction) {
            case (.title, .ascending):
                return lhs.title < rhs.title
            case (.title, .descending):
                return lhs.title > rhs.title
            case (.type, .ascending):
                return lhs.type.rawValue < rhs.type.rawValue
            case (.type, .descending):
                return lhs.type.rawValue > rhs.type.rawValue
            case (.createTime, .ascending):
                return lhs.createTime < rhs.createTime
            case (.createTime, .descending):
                return lhs.createTime > rhs.createTime
            case (.modifyTime, .ascending):
                return lhs.modifyTime < rhs.modifyTime
            case (.modifyTime, .descending):
                return lhs.modifyTime > rhs.modifyTime
            }
        }
    }

    func generateItemCount() -> ItemCount {
        var dictionary: [ItemContentType: Int] = [:]
        for type in ItemContentType.allCases {
            let count = filter { $0.type == type }.count
            dictionary[type] = count
        }
        return .init(total: count, typeCountDictionary: dictionary)
    }
}
