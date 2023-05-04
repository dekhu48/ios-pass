//
// PassPlanEntity.swift
// Proton Pass - Created on 04/05/2023.
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

import CoreData

@objc(PassPlanEntity)
public class PassPlanEntity: NSManagedObject {}

extension PassPlanEntity: Identifiable {}

extension PassPlanEntity {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<PassPlanEntity> {
        NSFetchRequest<PassPlanEntity>(entityName: "PassPlanEntity")
    }

    @NSManaged var displayName: String
    @NSManaged var internalName: String
    @NSManaged var type: String
    @NSManaged var userID: String

    // All limits are -1 by default (unlimited)
    @NSManaged var aliasLimit: Int64
    @NSManaged var totpLimit: Int64
    @NSManaged var vaultLimit: Int64
}

extension PassPlanEntity {
    func toPassPlan() -> PassPlan {
        .init(type: type,
              internalName: internalName,
              displayName: displayName,
              vaultLimit: vaultLimit == -1 ? nil : Int(vaultLimit),
              aliasLimit: aliasLimit == -1 ? nil : Int(aliasLimit),
              totpLimit: totpLimit == -1 ? nil : Int(totpLimit))
    }

    func hydrate(from passPlan: PassPlan, userId: String) {
        self.displayName = passPlan.displayName
        self.internalName = passPlan.internalName
        self.type = passPlan.type
        self.userID = userId
        self.aliasLimit = Int64(passPlan.aliasLimit ?? -1)
        self.totpLimit = Int64(passPlan.totpLimit ?? -1)
        self.vaultLimit = Int64(passPlan.vaultLimit ?? -1)
    }
}