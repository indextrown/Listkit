#if canImport(UIKit)
import UIKit

public typealias LKCustomSectionLayoutProvider = (
    Int,
    NSCollectionLayoutEnvironment
) -> NSCollectionLayoutSection

public enum LKSectionLayout {
    case list(appearance: UICollectionLayoutListConfiguration.Appearance)
    case horizontal(width: CGFloat, height: CGFloat? = nil)
    case grid(columns: Int, spacing: CGFloat)
    case custom(LKCustomSectionLayoutProvider)
}

public enum LKSectionScrollAxis: Hashable, Sendable {
    case vertical
    case horizontal
}

public enum LKSectionOrthogonalScrollingBehavior: Hashable, Sendable {
    case none
    case continuous
    case continuousGroupLeadingBoundary
    case paging
    case groupPaging
    case groupPagingCentered
}

extension LKSectionOrthogonalScrollingBehavior {
    var uiKitValue: UICollectionLayoutSectionOrthogonalScrollingBehavior {
        switch self {
        case .none:
            .none
        case .continuous:
            .continuous
        case .continuousGroupLeadingBoundary:
            .continuousGroupLeadingBoundary
        case .paging:
            .paging
        case .groupPaging:
            .groupPaging
        case .groupPagingCentered:
            .groupPagingCentered
        }
    }
}

extension LKSectionLayout: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.list(lhsAppearance), .list(rhsAppearance)):
            lhsAppearance == rhsAppearance
        case let (.horizontal(lhsWidth, lhsHeight), .horizontal(rhsWidth, rhsHeight)):
            lhsWidth == rhsWidth && lhsHeight == rhsHeight
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
        case let .horizontal(width, height):
            "horizontal-\(width)-\(height.map(String.init(describing:)) ?? "estimated")"
        case let .grid(columns, spacing):
            "grid-\(columns)-\(spacing)"
        case .custom:
            "custom"
        }
    }
}
#endif
