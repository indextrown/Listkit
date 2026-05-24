#if canImport(SwiftUI)
import SwiftUI
#endif

/// Collection-view item model used by the adapter and update engines.
public struct LKItemModel: Equatable {
    public let id: AnyHashable
    public let base: Any?
    public let reuseIdentifier: String
    public let hostingStrategy: LKHostingStrategy
    public let contentToken: AnyHashable?
    #if canImport(SwiftUI)
    var events: LKRowEvents
    let makeContent: (@MainActor () -> AnyView)?
    #endif

    public init(
        id: some Hashable,
        base: Any? = nil,
        reuseIdentifier: String = "ListKit.LKHostingCollectionViewCell",
        hostingStrategy: LKHostingStrategy = .hostingConfiguration,
        contentToken: AnyHashable? = nil
    ) {
        self.id = AnyHashable(id)
        self.base = base
        self.reuseIdentifier = reuseIdentifier
        self.hostingStrategy = hostingStrategy
        self.contentToken = contentToken
        #if canImport(SwiftUI)
        self.events = LKRowEvents()
        self.makeContent = nil
        #endif
    }

    #if canImport(SwiftUI)
    init(
        id: some Hashable,
        base: Any? = nil,
        reuseIdentifier: String = "ListKit.LKHostingCollectionViewCell",
        hostingStrategy: LKHostingStrategy = .hostingConfiguration,
        contentToken: AnyHashable? = nil,
        events: LKRowEvents = LKRowEvents(),
        makeContent: @escaping @MainActor () -> AnyView
    ) {
        self.id = AnyHashable(id)
        self.base = base
        self.reuseIdentifier = reuseIdentifier
        self.hostingStrategy = hostingStrategy
        self.contentToken = contentToken
        self.events = events
        self.makeContent = makeContent
    }
    #endif

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.reuseIdentifier == rhs.reuseIdentifier
            && lhs.hostingStrategy == rhs.hostingStrategy
            && lhs.contentToken == rhs.contentToken
    }
}
