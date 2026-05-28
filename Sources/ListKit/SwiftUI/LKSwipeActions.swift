#if canImport(UIKit) && canImport(SwiftUI)
import UIKit

public enum LKSwipeActionsEdge {
    case leading
    case trailing
}

public struct LKSwipeAction {
    public let style: UIContextualAction.Style
    public let title: String?
    public let image: UIImage?
    public let backgroundColor: UIColor?
    let handler: (LKAnyItemContext, @escaping (Bool) -> Void) -> Void

    public init(
        style: UIContextualAction.Style = .normal,
        title: String? = nil,
        image: UIImage? = nil,
        backgroundColor: UIColor? = nil,
        handler: @escaping (LKAnyItemContext, @escaping (Bool) -> Void) -> Void
    ) {
        self.style = style
        self.title = title
        self.image = image
        self.backgroundColor = backgroundColor
        self.handler = handler
    }
}

public struct LKSwipeActions {
    public let actions: [LKSwipeAction]
    public let allowsFullSwipe: Bool

    public init(actions: [LKSwipeAction], allowsFullSwipe: Bool = true) {
        self.actions = actions
        self.allowsFullSwipe = allowsFullSwipe
    }
}
#endif
