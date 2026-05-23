/// Header, footer, or custom supplementary model used by the adapter.
public struct LKSupplementaryModel: Equatable {
    public let id: AnyHashable
    public let kind: LKSupplementaryKind
    public let reuseIdentifier: String
    public let hostingStrategy: LKHostingStrategy
    public let contentToken: AnyHashable?

    public init(
        id: some Hashable,
        kind: LKSupplementaryKind,
        reuseIdentifier: String = "ListKit.LKHostingSupplementaryView",
        hostingStrategy: LKHostingStrategy = .hostingConfiguration,
        contentToken: AnyHashable? = nil
    ) {
        self.id = AnyHashable(id)
        self.kind = kind
        self.reuseIdentifier = reuseIdentifier
        self.hostingStrategy = hostingStrategy
        self.contentToken = contentToken
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.kind == rhs.kind
            && lhs.reuseIdentifier == rhs.reuseIdentifier
            && lhs.hostingStrategy == rhs.hostingStrategy
            && lhs.contentToken == rhs.contentToken
    }
}
