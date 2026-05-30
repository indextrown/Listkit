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
    case fixedGrid(columns: Int, itemHeight: CGFloat, columnSpacing: CGFloat, rowSpacing: CGFloat)
    case custom(LKCustomSectionLayoutProvider)
}

extension LKSectionLayout {
    public static func grid(
        columns: Int,
        itemHeight: CGFloat,
        columnSpacing: CGFloat,
        rowSpacing: CGFloat
    ) -> Self {
        .fixedGrid(
            columns: columns,
            itemHeight: itemHeight,
            columnSpacing: columnSpacing,
            rowSpacing: rowSpacing
        )
    }
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
        case let (
            .fixedGrid(lhsColumns, lhsItemHeight, lhsColumnSpacing, lhsRowSpacing),
            .fixedGrid(rhsColumns, rhsItemHeight, rhsColumnSpacing, rhsRowSpacing)
        ):
            lhsColumns == rhsColumns
                && lhsItemHeight == rhsItemHeight
                && lhsColumnSpacing == rhsColumnSpacing
                && lhsRowSpacing == rhsRowSpacing
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
        case let .fixedGrid(columns, itemHeight, columnSpacing, rowSpacing):
            "fixed-grid-\(columns)-\(itemHeight)-\(columnSpacing)-\(rowSpacing)"
        case .custom:
            "custom"
        }
    }
}
#endif
