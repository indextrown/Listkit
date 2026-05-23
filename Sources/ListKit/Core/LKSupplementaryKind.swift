/// Supplementary view kind supported by the core list model.
public enum LKSupplementaryKind: Hashable, Sendable {
    case header
    case footer
    case custom(String)

    public var rawValue: String {
        switch self {
        case .header:
            "UICollectionElementKindSectionHeader"
        case .footer:
            "UICollectionElementKindSectionFooter"
        case .custom(let kind):
            kind
        }
    }
}
