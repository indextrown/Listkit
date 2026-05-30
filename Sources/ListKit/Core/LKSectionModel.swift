#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Collection-view section model used by the adapter and update engines.
public struct LKSectionModel: Equatable {
    public let id: AnyHashable
    public var items: [LKItemModel]
    public var header: LKSupplementaryModel?
    public var footer: LKSupplementaryModel?
    public var supplementaries: [LKSupplementaryModel]
    #if canImport(SwiftUI)
    var events: LKSectionEvents
    var headerEvents: LKSupplementaryEvents
    var footerEvents: LKSupplementaryEvents
    #endif
    #if canImport(UIKit)
    public var layout: LKSectionLayout?
    public var scrollAxis: LKSectionScrollAxis
    public var orthogonalScrollingBehavior: LKSectionOrthogonalScrollingBehavior
    public var itemSpacing: CGFloat?
    public var sectionContentInsets: LKEdgeInsets?
    public var supplementaryContentInsetsReference: UIContentInsetsReference?
    public var pinsHeader: Bool
    #endif

    public init(
        id: some Hashable,
        items: [LKItemModel] = [],
        header: LKSupplementaryModel? = nil,
        footer: LKSupplementaryModel? = nil,
        supplementaries: [LKSupplementaryModel] = []
    ) {
        self.id = AnyHashable(id)
        self.items = items
        self.header = header
        self.footer = footer
        self.supplementaries = supplementaries
        #if canImport(SwiftUI)
        self.events = LKSectionEvents()
        self.headerEvents = LKSupplementaryEvents()
        self.footerEvents = LKSupplementaryEvents()
        #endif
        #if canImport(UIKit)
        self.layout = nil
        self.scrollAxis = .vertical
        self.orthogonalScrollingBehavior = .continuous
        self.itemSpacing = nil
        self.sectionContentInsets = nil
        self.supplementaryContentInsetsReference = nil
        self.pinsHeader = false
        #endif
    }

    #if canImport(UIKit)
    public init(
        id: some Hashable,
        items: [LKItemModel] = [],
        header: LKSupplementaryModel? = nil,
        footer: LKSupplementaryModel? = nil,
        supplementaries: [LKSupplementaryModel] = [],
        layout: LKSectionLayout?,
        scrollAxis: LKSectionScrollAxis = .vertical,
        orthogonalScrollingBehavior: LKSectionOrthogonalScrollingBehavior = .continuous,
        itemSpacing: CGFloat? = nil,
        sectionContentInsets: LKEdgeInsets? = nil,
        supplementaryContentInsetsReference: UIContentInsetsReference? = nil,
        pinsHeader: Bool = false
    ) {
        self.id = AnyHashable(id)
        self.items = items
        self.header = header
        self.footer = footer
        self.supplementaries = supplementaries
        #if canImport(SwiftUI)
        self.events = LKSectionEvents()
        self.headerEvents = LKSupplementaryEvents()
        self.footerEvents = LKSupplementaryEvents()
        #endif
        self.layout = layout
        self.scrollAxis = scrollAxis
        self.orthogonalScrollingBehavior = orthogonalScrollingBehavior
        self.itemSpacing = itemSpacing
        self.sectionContentInsets = sectionContentInsets
        self.supplementaryContentInsetsReference = supplementaryContentInsetsReference
        self.pinsHeader = pinsHeader
    }
    #endif

    public func supplementary(kind: LKSupplementaryKind) -> LKSupplementaryModel? {
        switch kind {
        case .header:
            header
        case .footer:
            footer
        case .custom:
            supplementaries.first { $0.kind == kind }
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        let coreIsEqual = lhs.id == rhs.id
            && lhs.items == rhs.items
            && lhs.header == rhs.header
            && lhs.footer == rhs.footer
            && lhs.supplementaries == rhs.supplementaries

        #if canImport(UIKit)
        return coreIsEqual
            && lhs.layout == rhs.layout
            && lhs.scrollAxis == rhs.scrollAxis
            && lhs.orthogonalScrollingBehavior == rhs.orthogonalScrollingBehavior
            && lhs.itemSpacing == rhs.itemSpacing
            && lhs.sectionContentInsets == rhs.sectionContentInsets
            && lhs.supplementaryContentInsetsReference == rhs.supplementaryContentInsetsReference
            && lhs.pinsHeader == rhs.pinsHeader
        #else
        return coreIsEqual
        #endif
    }
}
