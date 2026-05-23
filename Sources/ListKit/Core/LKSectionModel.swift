/// Collection-view section model used by the adapter and update engines.
public struct LKSectionModel: Equatable {
    public let id: AnyHashable
    public var items: [LKItemModel]
    public var header: LKSupplementaryModel?
    public var footer: LKSupplementaryModel?
    public var supplementaries: [LKSupplementaryModel]
    #if canImport(UIKit)
    public var layout: LKSectionLayout?
    #endif

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
        #if canImport(UIKit)
        self.layout = nil
        #endif
    }

    #if canImport(UIKit)
    public init(
        id: some Hashable,
        items: [LKItemModel] = [],
        header: LKSupplementaryModel? = nil,
        footer: LKSupplementaryModel? = nil,
        supplementaries: [LKSupplementaryModel] = [],
        layout: LKSectionLayout?
    ) {
        self.id = AnyHashable(id)
        self.items = items
        self.header = header
        self.footer = footer
        self.supplementaries = supplementaries
        self.layout = layout
    }
    #endif

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

    public static func == (lhs: Self, rhs: Self) -> Bool {
        let coreIsEqual = lhs.id == rhs.id
            && lhs.items == rhs.items
            && lhs.header == rhs.header
            && lhs.footer == rhs.footer
            && lhs.supplementaries == rhs.supplementaries

        #if canImport(UIKit)
        return coreIsEqual && lhs.layout == rhs.layout
        #else
        return coreIsEqual
        #endif
    }
}
