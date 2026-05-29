#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Header, footer, or custom supplementary model used by the adapter.
public struct LKSupplementaryModel: Equatable {
    public let id: AnyHashable
    public let kind: LKSupplementaryKind
    public let reuseIdentifier: String
    public let hostingStrategy: LKHostingStrategy
    public let contentToken: AnyHashable?
    #if canImport(UIKit)
    public var backgroundColor: UIColor?
    #endif
    #if canImport(SwiftUI)
    let content: LKAnyViewContent?
    #endif

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
        #if canImport(UIKit)
        self.backgroundColor = nil
        #endif
        #if canImport(SwiftUI)
        self.content = nil
        #endif
    }

    #if canImport(SwiftUI)
    init<Content: View>(
        id: some Hashable,
        kind: LKSupplementaryKind,
        reuseIdentifier: String = "ListKit.LKHostingSupplementaryView",
        hostingStrategy: LKHostingStrategy = .hostingConfiguration,
        contentToken: AnyHashable? = nil,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = AnyHashable(id)
        self.kind = kind
        self.reuseIdentifier = reuseIdentifier
        self.hostingStrategy = hostingStrategy
        self.contentToken = contentToken
        #if canImport(UIKit)
        self.backgroundColor = nil
        #endif
        self.content = LKAnyViewContent(content)
    }
    #endif

    public static func == (lhs: Self, rhs: Self) -> Bool {
        let coreIsEqual = lhs.id == rhs.id
            && lhs.kind == rhs.kind
            && lhs.reuseIdentifier == rhs.reuseIdentifier
            && lhs.hostingStrategy == rhs.hostingStrategy
            && lhs.contentToken == rhs.contentToken

        #if canImport(UIKit)
        return coreIsEqual
            && lhs.backgroundColor == rhs.backgroundColor
        #else
        return coreIsEqual
        #endif
    }
}
