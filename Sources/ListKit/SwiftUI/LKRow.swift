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
            base: item,
            reuseIdentifier: reuseIdentifier
        ) {
            content()
        }
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
            base: item,
            reuseIdentifier: reuseIdentifier
        ) {
            content()
        }
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
                base: model.base,
                reuseIdentifier: model.reuseIdentifier,
                hostingStrategy: model.hostingStrategy,
                contentToken: AnyHashable(token),
                events: events
            ) {
                content(item)
            },
            events: events,
            content: content
        )
    }

    public func onShouldSelect(_ handler: @escaping (LKAnyItemContext) -> Bool) -> Self {
        var events = events
        events.shouldSelect = handler
        return replacing(events: events)
    }

    public func onSelect(_ handler: @escaping (LKAnyItemContext) -> Void) -> Self {
        var events = events
        events.didSelect = handler
        return replacing(events: events)
    }

    public func onShouldDeselect(_ handler: @escaping (LKAnyItemContext) -> Bool) -> Self {
        var events = events
        events.shouldDeselect = handler
        return replacing(events: events)
    }

    public func onDeselect(_ handler: @escaping (LKAnyItemContext) -> Void) -> Self {
        var events = events
        events.didDeselect = handler
        return replacing(events: events)
    }

    public func onShouldHighlight(_ handler: @escaping (LKAnyItemContext) -> Bool) -> Self {
        var events = events
        events.shouldHighlight = handler
        return replacing(events: events)
    }

    public func onHighlight(_ handler: @escaping (LKAnyItemContext) -> Void) -> Self {
        var events = events
        events.didHighlight = handler
        return replacing(events: events)
    }

    public func onUnhighlight(_ handler: @escaping (LKAnyItemContext) -> Void) -> Self {
        var events = events
        events.didUnhighlight = handler
        return replacing(events: events)
    }

    public func onWillDisplay(_ handler: @escaping (LKAnyItemContext) -> Void) -> Self {
        var events = events
        events.willDisplay = handler
        return replacing(events: events)
    }

    public func onDidEndDisplaying(_ handler: @escaping (LKAnyItemContext) -> Void) -> Self {
        var events = events
        events.didEndDisplaying = handler
        return replacing(events: events)
    }

    func eraseToAnyRow() -> LKAnyRow {
        var model = model
        model.events = events
        return LKAnyRow(model: model, events: events)
    }

    func renderContent() -> Content {
        content(item)
    }

    private func replacing(events: LKRowEvents) -> Self {
        var model = model
        model.events = events
        return LKRow(item: item, model: model, events: events, content: content)
    }
}
#endif
