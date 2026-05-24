#if canImport(SwiftUI)
import Foundation
import CoreGraphics

public struct LKItemContext<Item> {
    public let item: Item
    public let id: AnyHashable
    public let indexPath: IndexPath
    public let sectionID: AnyHashable

    public init(item: Item, id: AnyHashable, indexPath: IndexPath, sectionID: AnyHashable) {
        self.item = item
        self.id = id
        self.indexPath = indexPath
        self.sectionID = sectionID
    }
}

public struct LKAnyItemContext {
    public let id: AnyHashable
    public let item: Any
    public let indexPath: IndexPath
    public let sectionID: AnyHashable

    public init(id: AnyHashable, item: Any, indexPath: IndexPath, sectionID: AnyHashable) {
        self.id = id
        self.item = item
        self.indexPath = indexPath
        self.sectionID = sectionID
    }
}

public struct LKSupplementaryContext {
    public let id: AnyHashable
    public let kind: LKSupplementaryKind
    public let indexPath: IndexPath
    public let sectionID: AnyHashable

    public init(id: AnyHashable, kind: LKSupplementaryKind, indexPath: IndexPath, sectionID: AnyHashable) {
        self.id = id
        self.kind = kind
        self.indexPath = indexPath
        self.sectionID = sectionID
    }
}

public struct LKScrollContext {
    public let contentOffset: CGPoint
    public let contentSize: CGSize
    public let boundsSize: CGSize
    public let adjustedContentInset: LKEdgeInsets

    public init(
        contentOffset: CGPoint,
        contentSize: CGSize,
        boundsSize: CGSize,
        adjustedContentInset: LKEdgeInsets
    ) {
        self.contentOffset = contentOffset
        self.contentSize = contentSize
        self.boundsSize = boundsSize
        self.adjustedContentInset = adjustedContentInset
    }
}

public struct LKEdgeInsets: Equatable {
    public let top: CGFloat
    public let left: CGFloat
    public let bottom: CGFloat
    public let right: CGFloat

    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
}

/// List-level event storage.
public struct LKListEvents {
    var shouldSelect: ((LKAnyItemContext) -> Bool)?
    var didSelect: ((LKAnyItemContext) -> Void)?
    var shouldDeselect: ((LKAnyItemContext) -> Bool)?
    var didDeselect: ((LKAnyItemContext) -> Void)?
    var shouldHighlight: ((LKAnyItemContext) -> Bool)?
    var didHighlight: ((LKAnyItemContext) -> Void)?
    var didUnhighlight: ((LKAnyItemContext) -> Void)?
    var willDisplay: ((LKAnyItemContext) -> Void)?
    var didEndDisplaying: ((LKAnyItemContext) -> Void)?
    public init() {}
}

/// Section-level event storage.
public struct LKSectionEvents {
    var shouldSelect: ((LKAnyItemContext) -> Bool)?
    var didSelect: ((LKAnyItemContext) -> Void)?
    var shouldDeselect: ((LKAnyItemContext) -> Bool)?
    var didDeselect: ((LKAnyItemContext) -> Void)?
    var shouldHighlight: ((LKAnyItemContext) -> Bool)?
    var didHighlight: ((LKAnyItemContext) -> Void)?
    var didUnhighlight: ((LKAnyItemContext) -> Void)?
    var willDisplay: ((LKAnyItemContext) -> Void)?
    var didEndDisplaying: ((LKAnyItemContext) -> Void)?
    public init() {}
}

/// Row-level event storage.
public struct LKRowEvents {
    var shouldSelect: ((LKAnyItemContext) -> Bool)?
    var didSelect: ((LKAnyItemContext) -> Void)?
    var shouldDeselect: ((LKAnyItemContext) -> Bool)?
    var didDeselect: ((LKAnyItemContext) -> Void)?
    var shouldHighlight: ((LKAnyItemContext) -> Bool)?
    var didHighlight: ((LKAnyItemContext) -> Void)?
    var didUnhighlight: ((LKAnyItemContext) -> Void)?
    var willDisplay: ((LKAnyItemContext) -> Void)?
    var didEndDisplaying: ((LKAnyItemContext) -> Void)?
    public init() {}
}

/// Supplementary-level event storage.
public struct LKSupplementaryEvents {
    var willDisplay: ((LKSupplementaryContext) -> Void)?
    var didEndDisplaying: ((LKSupplementaryContext) -> Void)?
    public init() {}
}
#endif
