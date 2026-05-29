#if canImport(UIKit)
import UIKit

public typealias LKCustomSectionLayoutProvider = (
    Int,
    NSCollectionLayoutEnvironment
) -> NSCollectionLayoutSection

public enum LKSectionLayout {
    case list(appearance: UICollectionLayoutListConfiguration.Appearance)
    case grid(columns: Int, spacing: CGFloat)
    case custom(LKCustomSectionLayoutProvider)
}

public enum LKSectionScrollAxis: Hashable, Sendable {
    case vertical
    case horizontal
}

extension LKSectionLayout: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.list(lhsAppearance), .list(rhsAppearance)):
            lhsAppearance == rhsAppearance
        case let (.grid(lhsColumns, lhsSpacing), .grid(rhsColumns, rhsSpacing)):
            lhsColumns == rhsColumns && lhsSpacing == rhsSpacing
        case (.custom, .custom):
            true
        default:
            false
        }
    }
}

extension LKSectionLayout {
    var signature: String {
        switch self {
        case let .list(appearance):
            "list-\(appearance)"
        case let .grid(columns, spacing):
            "grid-\(columns)-\(spacing)"
        case .custom:
            "custom"
        }
    }
}
#endif
