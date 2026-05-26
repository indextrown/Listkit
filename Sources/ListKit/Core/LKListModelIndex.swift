import Foundation

struct LKListModelIndex {
    let indexPathByItemID: [AnyHashable: IndexPath]
    let itemIDs: Set<AnyHashable>

    init(model: LKListModel) {
        var indexPathByItemID = [AnyHashable: IndexPath]()
        var itemIDs = Set<AnyHashable>()

        for sectionIndex in model.sections.indices {
            let section = model.sections[sectionIndex]
            for itemIndex in section.items.indices {
                let itemID = section.items[itemIndex].id
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
