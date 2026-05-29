#if canImport(UIKit)
import UIKit

public enum LKScrollPosition: Hashable, Sendable {
    case top
    case centeredVertically
    case bottom
    case left
    case centeredHorizontally
    case right

    var collectionViewScrollPosition: UICollectionView.ScrollPosition {
        switch self {
        case .top:
            .top
        case .centeredVertically:
            .centeredVertically
        case .bottom:
            .bottom
        case .left:
            .left
        case .centeredHorizontally:
            .centeredHorizontally
        case .right:
            .right
        }
    }
}

@MainActor
protocol LKListScrollControlling: AnyObject {
    func scrollToTop(animated: Bool)
    func scrollToOffset(_ offset: CGPoint, animated: Bool)
    func scrollToItem(
        id: AnyHashable,
        sectionID: AnyHashable?,
        position: LKScrollPosition,
        animated: Bool
    ) -> Bool
    func scrollToSection(
        id: AnyHashable,
        position: LKScrollPosition,
        animated: Bool
    ) -> Bool
}

@MainActor
public final class LKListProxy {
    private weak var scrollController: (any LKListScrollControlling)?

    public init() {}

    public func scrollToTop(animated: Bool = true) {
        scrollController?.scrollToTop(animated: animated)
    }

    public func scrollToOffset(_ offset: CGPoint, animated: Bool = true) {
        scrollController?.scrollToOffset(offset, animated: animated)
    }

    @discardableResult
    public func scrollToItem<ID: Hashable>(
        id: ID,
        sectionID: AnyHashable? = nil,
        position: LKScrollPosition = .top,
        animated: Bool = true
    ) -> Bool {
        scrollController?.scrollToItem(
            id: AnyHashable(id),
            sectionID: sectionID,
            position: position,
            animated: animated
        ) ?? false
    }

    @discardableResult
    public func scrollToSection<ID: Hashable>(
        id: ID,
        position: LKScrollPosition = .top,
        animated: Bool = true
    ) -> Bool {
        scrollController?.scrollToSection(
            id: AnyHashable(id),
            position: position,
            animated: animated
        ) ?? false
    }

    func attach(_ scrollController: any LKListScrollControlling) {
        self.scrollController = scrollController
    }

    func detach(_ scrollController: any LKListScrollControlling) {
        if self.scrollController === scrollController {
            self.scrollController = nil
        }
    }
}
#endif
