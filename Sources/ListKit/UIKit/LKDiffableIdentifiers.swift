#if canImport(UIKit) && canImport(SwiftUI)
import Foundation

struct LKSectionIdentifier: Hashable, @unchecked Sendable {
    let id: AnyHashable

    init(_ section: LKSectionModel) {
        self.id = section.id
    }
}

struct LKItemIdentifier: Hashable, @unchecked Sendable {
    let sectionID: AnyHashable
    let itemID: AnyHashable

    init(sectionID: some Hashable, itemID: some Hashable) {
        self.sectionID = AnyHashable(sectionID)
        self.itemID = AnyHashable(itemID)
    }

    init(section: LKSectionModel, item: LKItemModel) {
        self.sectionID = section.id
        self.itemID = item.id
    }
}
#endif
