/// Collection-view section model used by the adapter and update engines.
public struct LKSectionModel: Equatable {
    public let id: AnyHashable
    public var items: [LKItemModel]
    public var header: LKSupplementaryModel?
    public var footer: LKSupplementaryModel?
    public var supplementaries: [LKSupplementaryModel]

    public init(
        id: some Hashable,
        items: [LKItemModel] = [],
        header: LKSupplementaryModel? = nil,
        footer: LKSupplementaryModel? = nil,
        supplementaries: [LKSupplementaryModel] = []
    ) {
        self.id = AnyHashable(id)
        self.items = items
        self.header = header
        self.footer = footer
        self.supplementaries = supplementaries
    }

    public func supplementary(kind: LKSupplementaryKind) -> LKSupplementaryModel? {
        switch kind {
        case .header:
            header
        case .footer:
            footer
        case .custom:
            supplementaries.first { $0.kind == kind }
        }
    }
}
