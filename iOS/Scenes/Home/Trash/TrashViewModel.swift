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

protocol TrashViewModelDelegate: AnyObject {
    func trashViewModelWantsToToggleSidebar()
    func trashViewModelWantsToShowLoadingHud()
    func trashViewModelWantsToHideLoadingHud()
    func trashViewModelWantsShowItemDetail(_ item: ItemContent)
    func trashViewModelDidRestoreItem(_ item: ItemIdentifiable, type: ItemContentType)
    func trashViewModelDidRestoreAllItems(count: Int)
    func trashViewModelDidDeleteItem(_ type: ItemContentType)
    func trashViewModelDidEmptyTrash()
    func trashViewModelDidFail(_ error: Error)
}

enum TrashViewModelError: Error {
    case itemNotFound(shareId: String, itemId: String)
}

final class TrashViewModel: DeinitPrintable, PullToRefreshable, ObservableObject {
    @Published private(set) var state = State.loading
    @Published private(set) var items = [ItemListUiModel]()

    private let symmetricKey: SymmetricKey
    private let shareRepository: ShareRepositoryProtocol
    private let itemRepository: ItemRepositoryProtocol

    /// `PullToRefreshable` conformance
    var pullToRefreshContinuation: CheckedContinuation<Void, Never>?
    let syncEventLoop: SyncEventLoop

    weak var delegate: TrashViewModelDelegate?

    enum State {
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
         itemRepository: ItemRepositoryProtocol,
         syncEventLoop: SyncEventLoop) {
        self.symmetricKey = symmetricKey
        self.shareRepository = shareRepository
        self.itemRepository = itemRepository
        self.syncEventLoop = syncEventLoop
        fetchAllTrashedItems()
    }

    func fetchAllTrashedItems() {
        Task { @MainActor in
            do {
                if case .error = state {
                    state = .loading
                }

                items = try await getTrashedItemsTask().value
                state = .loaded
            } catch {
                state = .error(error)
            }
        }
    }
}

// MARK: - Actions
extension TrashViewModel {
    func toggleSidebar() {
        delegate?.trashViewModelWantsToToggleSidebar()
    }

    func restoreAllItems() {
        Task { @MainActor in
            defer { delegate?.trashViewModelWantsToHideLoadingHud() }
            do {
                delegate?.trashViewModelWantsToShowLoadingHud()
                let count = try await restoreAllTask().value
                items.removeAll()
                delegate?.trashViewModelDidRestoreAllItems(count: count)
            } catch {
                delegate?.trashViewModelDidFail(error)
            }
        }
    }

    func emptyTrash() {
        Task { @MainActor in
            defer { delegate?.trashViewModelWantsToHideLoadingHud() }
            do {
                delegate?.trashViewModelWantsToShowLoadingHud()
                try await deleteAllTask().value
                items.removeAll()
                delegate?.trashViewModelDidEmptyTrash()
            } catch {
                delegate?.trashViewModelDidFail(error)
            }
        }
    }

    func selectItem(_ item: ItemListUiModel) {
        Task { @MainActor in
            do {
                let itemContent = try await getDecryptedItemContentTask(for: item).value
                delegate?.trashViewModelWantsShowItemDetail(itemContent)
            } catch {
                delegate?.trashViewModelDidFail(error)
            }
        }
    }

    func restore(_ item: ItemListUiModel) {
        Task { @MainActor in
            defer { delegate?.trashViewModelWantsToHideLoadingHud() }
            do {
                delegate?.trashViewModelWantsToShowLoadingHud()
                try await restoreItemTask(item).value
                remove(item)
                delegate?.trashViewModelDidRestoreItem(item, type: item.type)
            } catch {
                delegate?.trashViewModelDidFail(error)
            }
        }
    }

    func deletePermanently(_ item: ItemListUiModel) {
        Task { @MainActor in
            defer { delegate?.trashViewModelWantsToHideLoadingHud() }
            do {
                delegate?.trashViewModelWantsToShowLoadingHud()
                try await deleteItemTask(item).value
                remove(item)
                delegate?.trashViewModelDidDeleteItem(item.type)
            } catch {
                delegate?.trashViewModelDidFail(error)
            }
        }
    }

    private func remove(_ item: ItemListUiModel) {
        items.removeAll(where: { $0.itemId == item.itemId })
    }
}

// MARK: - Private supporting tasks
private extension TrashViewModel {
    func getTrashedItemsTask() -> Task<[ItemListUiModel], Error> {
        Task.detached(priority: .userInitiated) {
            let items = try await self.itemRepository.getItems(forceRefresh: false, state: .trashed)
            return try await items.parallelMap { try await $0.toItemListUiModel(self.symmetricKey) }
        }
    }

    func restoreItemTask(_ item: ItemListUiModel) -> Task<Void, Error> {
        Task.detached(priority: .userInitiated) {
            let item = try await self.getItem(item)
            try await self.itemRepository.untrashItems([item])
        }
    }

    func restoreAllTask() -> Task<Int, Error> {
        Task.detached(priority: .userInitiated) {
            let items = try await self.itemRepository.getItems(forceRefresh: false, state: .trashed)
            try await self.itemRepository.untrashItems(items)
            return items.count
        }
    }

    func deleteAllTask() -> Task<Void, Error> {
        Task.detached(priority: .userInitiated) {
            let items = try await self.itemRepository.getItems(forceRefresh: false, state: .trashed)
            try await self.itemRepository.deleteItems(items, skipTrash: false)
        }
    }

    func deleteItemTask(_ item: ItemListUiModel) -> Task<Void, Error> {
        Task.detached(priority: .userInitiated) {
            let item = try await self.getItem(item)
            try await self.itemRepository.deleteItems([item], skipTrash: false)
        }
    }

    func getItem(_ item: ItemListUiModel) async throws -> SymmetricallyEncryptedItem {
        guard let item = try await itemRepository.getItem(shareId: item.shareId,
                                                          itemId: item.itemId) else {
            throw TrashViewModelError.itemNotFound(shareId: item.shareId, itemId: item.itemId)
        }
        return item
    }

    func getDecryptedItemContentTask(for item: ItemListUiModel) -> Task<ItemContent, Error> {
        Task.detached(priority: .userInitiated) {
            let encryptedItem = try await self.getItem(item)
            return try encryptedItem.getDecryptedItemContent(symmetricKey: self.symmetricKey)
        }
    }
}

extension TrashViewModel: SyncEventLoopPullToRefreshDelegate {
    func pullToRefreshShouldStopRefreshing() {
        stopRefreshing()
    }
}
