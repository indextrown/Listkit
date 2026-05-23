#if canImport(SwiftUI)
import SwiftUI

public struct LKRow<Item, Content: View> {
    public let item: Item
    public let model: LKItemModel
    public let events: LKRowEvents
    private let content: (Item) -> Content

    public init<ID: Hashable>(
        _ item: Item,
        id: KeyPath<Item, ID>,
        reuseIdentifier: String = "ListKit.LKHostingCollectionViewCell",
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.item = item
        self.model = LKItemModel(
            id: item[keyPath: id],
            reuseIdentifier: reuseIdentifier
        )
        self.events = LKRowEvents()
        self.content = { _ in content() }
    }

    public init(
        id: some Hashable,
        reuseIdentifier: String = "ListKit.LKHostingCollectionViewCell",
        @ViewBuilder content: @escaping () -> Content
    ) where Item == Void {
        self.item = ()
        self.model = LKItemModel(id: id, reuseIdentifier: reuseIdentifier)
        self.events = LKRowEvents()
        self.content = { _ in content() }
    }

    private init(
        item: Item,
        model: LKItemModel,
        events: LKRowEvents,
        content: @escaping (Item) -> Content
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
                contentToken: AnyHashable(token)
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
