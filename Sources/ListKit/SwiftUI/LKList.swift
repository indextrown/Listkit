#if canImport(SwiftUI)
import SwiftUI

@MainActor
public struct LKList<Content: View>: View {
    let model: LKListModel
    let events: LKListEvents
    let sections: [LKSection]
    #if canImport(UIKit)
    let style: LKListStyle
    let updateEngine: LKUpdateEngine
    #endif

    @ViewBuilder
    public var body: some View {
        #if canImport(UIKit)
        LKCollectionViewRepresentable(
            model: model,
            listEvents: events,
            style: style,
            updateEngine: updateEngine
        )
        #else
        EmptyView()
        #endif
    }

    public init<Data, ID>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder rowContent: @escaping @MainActor (Data.Element) -> Content
    )
    where
        Data: RandomAccessCollection,
        ID: Hashable
    {
        let items = data.map { element in
            LKItemModel(
                id: element[keyPath: id],
                base: element,
                makeContent: { AnyView(rowContent(element)) }
            )
        }
        self.model = LKListModel(
            sections: [
                LKSectionModel(id: "ListKit.default-section", items: Array(items)),
            ]
        )
        self.events = LKListEvents()
        self.sections = []
        #if canImport(UIKit)
        self.style = .plain
        self.updateEngine = .reloadData
        #endif
    }

    public init(@LKListBuilder content: () -> [LKSection]) where Content == EmptyView {
        let sections = content()
        self.sections = sections
        self.model = LKListModel(sections: sections.map(\.model))
        self.events = LKListEvents()
        #if canImport(UIKit)
        self.style = .plain
        self.updateEngine = .reloadData
        #endif
    }

    #if canImport(UIKit)
    private init(
        model: LKListModel,
        events: LKListEvents,
        sections: [LKSection],
        style: LKListStyle,
        updateEngine: LKUpdateEngine
    ) {
        self.model = model
        self.events = events
        self.sections = sections
        self.style = style
        self.updateEngine = updateEngine
    }

    public func listKitStyle(_ style: LKListStyle) -> Self {
        Self(model: model, events: events, sections: sections, style: style, updateEngine: updateEngine)
    }

    public func updateEngine(_ updateEngine: LKUpdateEngine) -> Self {
        Self(model: model, events: events, sections: sections, style: style, updateEngine: updateEngine)
    }
    #endif

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

    private func replacing(events: LKListEvents) -> Self {
        #if canImport(UIKit)
        Self(model: model, events: events, sections: sections, style: style, updateEngine: updateEngine)
        #else
        self
        #endif
    }
}
#endif
