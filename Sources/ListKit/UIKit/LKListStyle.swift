#if canImport(UIKit)
import UIKit

public enum LKListStyle: Hashable, Sendable {
    case plain
    case grouped
    case insetGrouped
    case sidebar

    var listAppearance: UICollectionLayoutListConfiguration.Appearance {
        switch self {
        case .plain:
            .plain
        case .grouped:
            .grouped
        case .insetGrouped:
            .insetGrouped
        case .sidebar:
            .sidebar
        }
    }
}
#endif
