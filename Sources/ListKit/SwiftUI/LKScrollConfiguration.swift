#if canImport(SwiftUI)
import CoreGraphics

public enum LKScrollIndicatorVisibility: Equatable {
    case automatic
    case visible
    case hidden
}

public enum LKReachEndThreshold: Equatable {
    case points(CGFloat)

    var points: CGFloat {
        switch self {
        case .points(let value):
            max(value, 0)
        }
    }
}

struct LKScrollConfiguration: Equatable {
    var indicatorVisibility: LKScrollIndicatorVisibility = .automatic
    var keyboardDismissMode: Int?
    var contentInsets: LKEdgeInsets?
    var reachEndThreshold: LKReachEndThreshold?

    init() {}
}
#endif
