#if canImport(SwiftUI)
import SwiftUI

@MainActor
public struct LKRow<Item, Content: View> {
    public let item: Item
    public let model: LKItemModel
    public let events: LKRowEvents
    private let content: @MainActor (Item) -> Content

    public init<ID: Hashable>(
        _ item: Item,
        id: KeyPath<Item, ID>,
        reuseIdentifier: String = "ListKit.LKHostingCollectionViewCell",
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.item = item
        self.model = LKItemModel(
            id: item[keyPath: id],
            reuseIdentifier: reuseIdentifier,
            makeContent: { AnyView(content()) }
        )
        self.events = LKRowEvents()
        self.content = { _ in content() }
    }

    public init(
        id: some Hashable,
        reuseIdentifier: String = "ListKit.LKHostingCollectionViewCell",
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) where Item == Void {
        self.item = ()
        self.model = LKItemModel(
            id: id,
            reuseIdentifier: reuseIdentifier,
            makeContent: { AnyView(content()) }
        )
        self.events = LKRowEvents()
        self.content = { _ in content() }
    }

    private init(
        item: Item,
        model: LKItemModel,
        events: LKRowEvents,
        content: @escaping @MainActor (Item) -> Content
    ) {
        self.item = item
        self.model = model
        self.events = events
        self.content = content
    }

    public func equatableToken(_ token: some Hashable) -> Self {
        LKRow(
            item: item,
            model: LKItemModel(
                id: model.id,
                reuseIdentifier: model.reuseIdentifier,
                hostingStrategy: model.hostingStrategy,
                contentToken: AnyHashable(token),
                makeContent: model.makeContent ?? { AnyView(content(item)) }
            ),
            events: events,
            content: content
        )
    }

    func eraseToAnyRow() -> LKAnyRow {
        LKAnyRow(model: model, events: events)
    }

    func renderContent() -> Content {
        content(item)
    }
}
#endif
