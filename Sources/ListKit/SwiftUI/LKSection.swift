#if canImport(SwiftUI)
import SwiftUI

@MainActor
public struct LKSection {
    public let model: LKSectionModel
    public let events: LKSectionEvents
    public let headerEvents: LKSupplementaryEvents
    public let footerEvents: LKSupplementaryEvents
    public let rows: [LKAnyRow]

    public init(
        id: some Hashable,
        @LKRowsBuilder _ rows: () -> [LKAnyRow]
    ) {
        self.init(
            id: id,
            rows: rows(),
            header: nil,
            footer: nil
        )
    }

    public init<Header: View>(
        id: some Hashable,
        @LKRowsBuilder _ rows: () -> [LKAnyRow],
        @ViewBuilder header: @escaping @MainActor () -> Header
    ) {
        self.init(
            id: id,
            rows: rows(),
            header: LKSupplementaryModel(
                id: AnyHashable(id),
                kind: .header,
                makeContent: { AnyView(header()) }
            ),
            footer: nil
        )
    }

    public init<Header: View, Footer: View>(
        id: some Hashable,
        @LKRowsBuilder _ rows: () -> [LKAnyRow],
        @ViewBuilder header: @escaping @MainActor () -> Header,
        @ViewBuilder footer: @escaping @MainActor () -> Footer
    ) {
        self.init(
            id: id,
            rows: rows(),
            header: LKSupplementaryModel(
                id: AnyHashable(id),
                kind: .header,
                makeContent: { AnyView(header()) }
            ),
            footer: LKSupplementaryModel(
                id: AnyHashable(id),
                kind: .footer,
                makeContent: { AnyView(footer()) }
            )
        )
    }

    private init(
        id: some Hashable,
        rows: [LKAnyRow],
        header: LKSupplementaryModel?,
        footer: LKSupplementaryModel?
    ) {
        self.rows = rows
        self.events = LKSectionEvents()
        self.headerEvents = LKSupplementaryEvents()
        self.footerEvents = LKSupplementaryEvents()
        var model = LKSectionModel(
            id: id,
            items: rows.map(\.model),
            header: header,
            footer: footer
        )
        model.events = events
        model.headerEvents = headerEvents
        model.footerEvents = footerEvents
        self.model = model
    }

    private init(
        model: LKSectionModel,
        events: LKSectionEvents,
        headerEvents: LKSupplementaryEvents,
        footerEvents: LKSupplementaryEvents,
        rows: [LKAnyRow]
    ) {
        self.model = model
        self.events = events
        self.headerEvents = headerEvents
        self.footerEvents = footerEvents
        self.rows = rows
    }

    #if canImport(UIKit)
    public func sectionLayout(_ layout: LKSectionLayout) -> Self {
        var model = model
        model.layout = layout
        return Self(
            model: model,
            events: events,
            headerEvents: headerEvents,
            footerEvents: footerEvents,
            rows: rows
        )
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

    public func onWillDisplayHeader(_ handler: @escaping (LKSupplementaryContext) -> Void) -> Self {
        var events = headerEvents
        events.willDisplay = handler
        return replacing(headerEvents: events)
    }

    public func onDidEndDisplayingHeader(_ handler: @escaping (LKSupplementaryContext) -> Void) -> Self {
        var events = headerEvents
        events.didEndDisplaying = handler
        return replacing(headerEvents: events)
    }

    public func onWillDisplayFooter(_ handler: @escaping (LKSupplementaryContext) -> Void) -> Self {
        var events = footerEvents
        events.willDisplay = handler
        return replacing(footerEvents: events)
    }

    public func onDidEndDisplayingFooter(_ handler: @escaping (LKSupplementaryContext) -> Void) -> Self {
        var events = footerEvents
        events.didEndDisplaying = handler
        return replacing(footerEvents: events)
    }

    private func replacing(events: LKSectionEvents) -> Self {
        var model = model
        model.events = events
        return Self(
            model: model,
            events: events,
            headerEvents: headerEvents,
            footerEvents: footerEvents,
            rows: rows
        )
    }

    private func replacing(headerEvents: LKSupplementaryEvents) -> Self {
        var model = model
        model.headerEvents = headerEvents
        return Self(
            model: model,
            events: events,
            headerEvents: headerEvents,
            footerEvents: footerEvents,
            rows: rows
        )
    }

    private func replacing(footerEvents: LKSupplementaryEvents) -> Self {
        var model = model
        model.footerEvents = footerEvents
        return Self(
            model: model,
            events: events,
            headerEvents: headerEvents,
            footerEvents: footerEvents,
            rows: rows
        )
    }
}
#endif
