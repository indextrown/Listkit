/// Collection-view item model used by the adapter and update engines.
public struct LKItemModel: Equatable {
    public let id: AnyHashable
    public let reuseIdentifier: String
    public let hostingStrategy: LKHostingStrategy
    public let contentToken: AnyHashable?

    public init(
        id: some Hashable,
        reuseIdentifier: String = "ListKit.LKHostingCollectionViewCell",
        hostingStrategy: LKHostingStrategy = .hostingConfiguration,
        contentToken: AnyHashable? = nil
    ) {
        self.id = AnyHashable(id)
        self.reuseIdentifier = reuseIdentifier
        self.hostingStrategy = hostingStrategy
        self.contentToken = contentToken
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.reuseIdentifier == rhs.reuseIdentifier
            && lhs.hostingStrategy == rhs.hostingStrategy
            && lhs.contentToken == rhs.contentToken
    }
}
