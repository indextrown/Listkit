#if canImport(SwiftUI)
import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

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
    var didScroll: ((LKScrollContext) -> Void)?
    var willBeginDragging: ((LKScrollContext) -> Void)?
    var willEndDragging: ((LKScrollContext) -> Void)?
    var didEndDragging: ((LKScrollContext) -> Void)?
    var willBeginDecelerating: ((LKScrollContext) -> Void)?
    var didEndDecelerating: ((LKScrollContext) -> Void)?
    var shouldScrollToTop: ((LKScrollContext) -> Bool)?
    var didScrollToTop: ((LKScrollContext) -> Void)?
    var didReachEnd: (() -> Void)?
    var didPrefetch: (([LKAnyItemContext]) -> Void)?
    var didCancelPrefetch: (([LKAnyItemContext]) -> Void)?
    var didEmitWarning: ((LKListKitWarning) -> Void)?
    var canPerformPrimaryAction: ((LKAnyItemContext) -> Bool)?
    var didPerformPrimaryAction: ((LKAnyItemContext) -> Void)?
    var shouldBeginMultipleSelectionInteraction: ((LKAnyItemContext) -> Bool)?
    var didBeginMultipleSelectionInteraction: ((LKAnyItemContext) -> Void)?
    var didEndMultipleSelectionInteraction: (() -> Void)?
    #if canImport(UIKit)
    var uiContextMenuConfiguration: ((LKAnyItemContext, CGPoint) -> UIContextMenuConfiguration?)?
    var uiWillPerformPreviewAction: ((UIContextMenuConfiguration, UIContextMenuInteractionCommitAnimating) -> Void)?
    var uiPreviewForHighlightingContextMenu: ((UIContextMenuConfiguration) -> UITargetedPreview?)?
    var uiPreviewForDismissingContextMenu: ((UIContextMenuConfiguration) -> UITargetedPreview?)?
    var canFocus: ((LKAnyItemContext) -> Bool)?
    var shouldUpdateFocus: ((UICollectionViewFocusUpdateContext) -> Bool)?
    var didUpdateFocus: ((UICollectionViewFocusUpdateContext, UIFocusAnimationCoordinator) -> Void)?
    var preferredFocusedItemID: AnyHashable?
    var shouldShowEditMenu: ((LKAnyItemContext) -> Bool)?
    var canPerformMenuAction: ((LKAnyItemContext, Selector, Any?) -> Bool)?
    var performMenuAction: ((LKAnyItemContext, Selector, Any?) -> Void)?
    var shouldSpringLoad: ((LKAnyItemContext, UISpringLoadedInteractionContext) -> Bool)?
    var leadingSwipeActions: ((LKAnyItemContext) -> LKSwipeActions?)?
    var trailingSwipeActions: ((LKAnyItemContext) -> LKSwipeActions?)?
    #endif
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
    #if canImport(UIKit)
    var leadingSwipeActions: ((LKAnyItemContext) -> LKSwipeActions?)?
    var trailingSwipeActions: ((LKAnyItemContext) -> LKSwipeActions?)?
    #endif
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
    #if canImport(UIKit)
    var leadingSwipeActions: ((LKAnyItemContext) -> LKSwipeActions?)?
    var trailingSwipeActions: ((LKAnyItemContext) -> LKSwipeActions?)?
    #endif
    public init() {}
}

/// Supplementary-level event storage.
public struct LKSupplementaryEvents {
    var willDisplay: ((LKSupplementaryContext) -> Void)?
    var didEndDisplaying: ((LKSupplementaryContext) -> Void)?
    public init() {}
}
#endif
