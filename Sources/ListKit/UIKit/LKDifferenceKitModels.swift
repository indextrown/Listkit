#if canImport(UIKit) && canImport(SwiftUI)
import DifferenceKit
import Foundation

struct LKDifferenceKitItem: Differentiable, Equatable {
    typealias DifferenceIdentifier = AnyHashable

    let model: LKItemModel

    var differenceIdentifier: AnyHashable {
        model.id
    }

    func isContentEqual(to source: LKDifferenceKitItem) -> Bool {
        model.contentToken == source.model.contentToken
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model == rhs.model
    }
}

struct LKDifferenceKitSection: DifferentiableSection, Equatable {
    typealias DifferenceIdentifier = AnyHashable
    typealias Collection = [LKDifferenceKitItem]

    let model: LKSectionModel
    let elements: [LKDifferenceKitItem]

    var differenceIdentifier: AnyHashable {
        model.id
    }

    init(section: LKSectionModel) {
        self.model = section
        self.elements = section.items.map(LKDifferenceKitItem.init(model:))
    }

    init<C: Swift.Collection>(source: LKDifferenceKitSection, elements: C) where C.Element == LKDifferenceKitItem {
        var model = source.model
        model.items = elements.map(\.model)
        self.model = model
        self.elements = Array(elements)
    }

    func isContentEqual(to source: LKDifferenceKitSection) -> Bool {
        model.id == source.model.id
            && model.header == source.model.header
            && model.footer == source.model.footer
            && model.supplementaries == source.model.supplementaries
            && model.layout == source.model.layout
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model == rhs.model && lhs.elements == rhs.elements
    }
}

extension LKListModel {
    var differenceKitSections: [LKDifferenceKitSection] {
        sections.map(LKDifferenceKitSection.init(section:))
    }

    init(differenceKitSections: [LKDifferenceKitSection]) {
        self.init(sections: differenceKitSections.map(\.model))
    }
}
#endif
