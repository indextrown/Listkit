import Foundation

struct LKModelItemIdentity: Hashable {
    let sectionID: AnyHashable
    let itemID: AnyHashable
}

struct LKListModelIndex {
    let indexPathByItemID: [AnyHashable: IndexPath]
    let itemIDs: Set<AnyHashable>

    init(model: LKListModel) {
        var indexPathByItemID = [AnyHashable: IndexPath]()
        var itemIDs = Set<AnyHashable>()

        for sectionIndex in model.sections.indices {
            let section = model.sections[sectionIndex]
            for itemIndex in section.items.indices {
                let item = section.items[itemIndex]
                let itemID = item.id

                if itemIDs.insert(itemID).inserted {
                    indexPathByItemID[itemID] = IndexPath.lkIndexPath(
                        item: itemIndex,
                        section: sectionIndex
                    )
                }
            }
        }

        self.indexPathByItemID = indexPathByItemID
        self.itemIDs = itemIDs
    }

    func indexPath(forItemID itemID: AnyHashable) -> IndexPath? {
        indexPathByItemID[itemID]
    }
}

struct LKListContentTokenIndex {
    let itemIdentities: Set<LKModelItemIdentity>
    let contentTokenByItemIdentity: [LKModelItemIdentity: AnyHashable]

    func containsItem(_ identity: LKModelItemIdentity) -> Bool {
        itemIdentities.contains(identity)
    }

    func contentToken(for identity: LKModelItemIdentity) -> AnyHashable? {
        contentTokenByItemIdentity[identity]
    }

    init(model: LKListModel) {
        var itemIdentities = Set<LKModelItemIdentity>()
        var contentTokenByItemIdentity = [LKModelItemIdentity: AnyHashable]()

        for section in model.sections {
            for item in section.items {
                let identity = LKModelItemIdentity(
                    sectionID: section.id,
                    itemID: item.id
                )
                itemIdentities.insert(identity)
                if let contentToken = item.contentToken {
                    contentTokenByItemIdentity[identity] = contentToken
                }
            }
        }

        self.itemIdentities = itemIdentities
        self.contentTokenByItemIdentity = contentTokenByItemIdentity
    }
}
