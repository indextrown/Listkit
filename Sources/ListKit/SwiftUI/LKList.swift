#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public struct LKList<Content: View>: View {
    let model: LKListModel
    let events: LKListEvents
    let selectionConfiguration: LKSelectionConfiguration
    let scrollConfiguration: LKScrollConfiguration
    let refreshConfiguration: LKRefreshConfiguration
    let diagnosticsMode: LKListKitDiagnosticsMode
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
            selectionConfiguration: selectionConfiguration,
            scrollConfiguration: scrollConfiguration,
            refreshConfiguration: refreshConfiguration,
            diagnosticsMode: diagnosticsMode,
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
                base: element
            ) {
                rowContent(element)
            }
        }
        self.model = LKListModel(
            sections: [
                LKSectionModel(id: "ListKit.default-section", items: Array(items)),
            ]
        )
        self.events = LKListEvents()
        self.selectionConfiguration = LKSelectionConfiguration()
        self.scrollConfiguration = LKScrollConfiguration()
        self.refreshConfiguration = LKRefreshConfiguration()
        self.diagnosticsMode = .disabled
        self.sections = []
        #if canImport(UIKit)
        self.style = .plain
        self.updateEngine = .differenceKit
        #endif
    }

    public init(@LKListBuilder content: () -> [LKSection]) where Content == EmptyView {
        let sections = content()
        self.sections = sections
        self.model = LKListModel(sections: sections.map(\.model))
        self.events = LKListEvents()
        self.selectionConfiguration = LKSelectionConfiguration()
        self.scrollConfiguration = LKScrollConfiguration()
        self.refreshConfiguration = LKRefreshConfiguration()
        self.diagnosticsMode = .disabled
        #if canImport(UIKit)
        self.style = .plain
        self.updateEngine = .differenceKit
        #endif
    }

    #if canImport(UIKit)
    private init(
        model: LKListModel,
        events: LKListEvents,
        selectionConfiguration: LKSelectionConfiguration,
        scrollConfiguration: LKScrollConfiguration,
        refreshConfiguration: LKRefreshConfiguration,
        diagnosticsMode: LKListKitDiagnosticsMode,
        sections: [LKSection],
        style: LKListStyle,
        updateEngine: LKUpdateEngine
    ) {
        self.model = model
        self.events = events
        self.selectionConfiguration = selectionConfiguration
        self.scrollConfiguration = scrollConfiguration
        self.refreshConfiguration = refreshConfiguration
        self.diagnosticsMode = diagnosticsMode
        self.sections = sections
        self.style = style
        self.updateEngine = updateEngine
    }

    public func listKitStyle(_ style: LKListStyle) -> Self {
        Self(
            model: model,
            events: events,
            selectionConfiguration: selectionConfiguration,
            scrollConfiguration: scrollConfiguration,
            refreshConfiguration: refreshConfiguration,
            diagnosticsMode: diagnosticsMode,
            sections: sections,
            style: style,
            updateEngine: updateEngine
        )
    }

    public func updateEngine(_ updateEngine: LKUpdateEngine) -> Self {
        Self(
            model: model,
            events: events,
            selectionConfiguration: selectionConfiguration,
            scrollConfiguration: scrollConfiguration,
            refreshConfiguration: refreshConfiguration,
            diagnosticsMode: diagnosticsMode,
            sections: sections,
            style: style,
            updateEngine: updateEngine
        )
    }
    #endif

    public func selection<ID: Hashable>(_ selection: Binding<ID?>) -> Self {
        replacing(selectionConfiguration: LKSelectionConfiguration(selection: selection))
    }

    public func selection<ID: Hashable>(_ selection: Binding<Set<ID>>) -> Self {
        replacing(selectionConfiguration: LKSelectionConfiguration(selection: selection))
    }

    public func selectionMode(_ mode: LKSelectionMode) -> Self {
        replacing(selectionConfiguration: selectionConfiguration.replacing(mode: mode))
    }

    public func refreshable(action: @escaping @MainActor () async -> Void) -> Self {
        var refreshConfiguration = refreshConfiguration
        refreshConfiguration.action = action
        return replacing(refreshConfiguration: refreshConfiguration)
    }

    #if canImport(UIKit)
    public func refreshControlTint(_ color: UIColor) -> Self {
        var refreshConfiguration = refreshConfiguration
        refreshConfiguration.tintColor = color
        return replacing(refreshConfiguration: refreshConfiguration)
    }
    #endif

    public func onScroll(_ handler: @escaping (LKScrollContext) -> Void) -> Self {
        var events = events
        events.didScroll = handler
        return replacing(events: events)
    }

    public func onWillBeginDragging(_ handler: @escaping (LKScrollContext) -> Void) -> Self {
        var events = events
        events.willBeginDragging = handler
        return replacing(events: events)
    }

    public func onWillEndDragging(_ handler: @escaping (LKScrollContext) -> Void) -> Self {
        var events = events
        events.willEndDragging = handler
        return replacing(events: events)
    }

    public func onDidEndDragging(_ handler: @escaping (LKScrollContext) -> Void) -> Self {
        var events = events
        events.didEndDragging = handler
        return replacing(events: events)
    }

    public func onWillBeginDecelerating(_ handler: @escaping (LKScrollContext) -> Void) -> Self {
        var events = events
        events.willBeginDecelerating = handler
        return replacing(events: events)
    }

    public func onDidEndDecelerating(_ handler: @escaping (LKScrollContext) -> Void) -> Self {
        var events = events
        events.didEndDecelerating = handler
        return replacing(events: events)
    }

    public func onShouldScrollToTop(_ handler: @escaping (LKScrollContext) -> Bool) -> Self {
        var events = events
        events.shouldScrollToTop = handler
        return replacing(events: events)
    }

    public func onDidScrollToTop(_ handler: @escaping (LKScrollContext) -> Void) -> Self {
        var events = events
        events.didScrollToTop = handler
        return replacing(events: events)
    }

    public func onReachEnd(threshold: LKReachEndThreshold = .points(300), _ handler: @escaping () -> Void) -> Self {
        var events = events
        events.didReachEnd = handler
        var scrollConfiguration = scrollConfiguration
        scrollConfiguration.reachEndThreshold = threshold
        return replacing(events: events, scrollConfiguration: scrollConfiguration)
    }

    public func onPrefetch(_ handler: @escaping ([LKAnyItemContext]) -> Void) -> Self {
        var events = events
        events.didPrefetch = handler
        return replacing(events: events)
    }

    public func onCancelPrefetch(_ handler: @escaping ([LKAnyItemContext]) -> Void) -> Self {
        var events = events
        events.didCancelPrefetch = handler
        return replacing(events: events)
    }

    public func listKitDiagnostics(_ mode: LKListKitDiagnosticsMode) -> Self {
        replacing(diagnosticsMode: mode)
    }

    public func onListKitWarning(_ handler: @escaping (LKListKitWarning) -> Void) -> Self {
        var events = events
        events.didEmitWarning = handler
        return replacing(events: events)
    }

    public func onCanPerformPrimaryAction(_ handler: @escaping (LKAnyItemContext) -> Bool) -> Self {
        var events = events
        events.canPerformPrimaryAction = handler
        return replacing(events: events)
    }

    public func onPrimaryAction(_ handler: @escaping (LKAnyItemContext) -> Void) -> Self {
        var events = events
        events.didPerformPrimaryAction = handler
        return replacing(events: events)
    }

    public func onShouldBeginMultipleSelectionInteraction(_ handler: @escaping (LKAnyItemContext) -> Bool) -> Self {
        var events = events
        events.shouldBeginMultipleSelectionInteraction = handler
        return replacing(events: events)
    }

    public func onBeginMultipleSelectionInteraction(_ handler: @escaping (LKAnyItemContext) -> Void) -> Self {
        var events = events
        events.didBeginMultipleSelectionInteraction = handler
        return replacing(events: events)
    }

    public func onEndMultipleSelectionInteraction(_ handler: @escaping () -> Void) -> Self {
        var events = events
        events.didEndMultipleSelectionInteraction = handler
        return replacing(events: events)
    }

    #if canImport(UIKit)
    public func uiContextMenuConfiguration(
        _ handler: @escaping (LKAnyItemContext, CGPoint) -> UIContextMenuConfiguration?
    ) -> Self {
        var events = events
        events.uiContextMenuConfiguration = handler
        return replacing(events: events)
    }

    public func onPreviewCommit(
        _ handler: @escaping (UIContextMenuConfiguration, UIContextMenuInteractionCommitAnimating) -> Void
    ) -> Self {
        var events = events
        events.uiWillPerformPreviewAction = handler
        return replacing(events: events)
    }

    public func previewForHighlightingContextMenu(
        _ handler: @escaping (UIContextMenuConfiguration) -> UITargetedPreview?
    ) -> Self {
        var events = events
        events.uiPreviewForHighlightingContextMenu = handler
        return replacing(events: events)
    }

    public func previewForDismissingContextMenu(
        _ handler: @escaping (UIContextMenuConfiguration) -> UITargetedPreview?
    ) -> Self {
        var events = events
        events.uiPreviewForDismissingContextMenu = handler
        return replacing(events: events)
    }

    public func onCanFocus(_ handler: @escaping (LKAnyItemContext) -> Bool) -> Self {
        var events = events
        events.canFocus = handler
        return replacing(events: events)
    }

    public func onShouldUpdateFocus(_ handler: @escaping (UICollectionViewFocusUpdateContext) -> Bool) -> Self {
        var events = events
        events.shouldUpdateFocus = handler
        return replacing(events: events)
    }

    public func onDidUpdateFocus(
        _ handler: @escaping (UICollectionViewFocusUpdateContext, UIFocusAnimationCoordinator) -> Void
    ) -> Self {
        var events = events
        events.didUpdateFocus = handler
        return replacing(events: events)
    }

    public func preferredFocusedItem(id: AnyHashable?) -> Self {
        var events = events
        events.preferredFocusedItemID = id
        return replacing(events: events)
    }

    public func onShouldShowEditMenu(_ handler: @escaping (LKAnyItemContext) -> Bool) -> Self {
        var events = events
        events.shouldShowEditMenu = handler
        return replacing(events: events)
    }

    public func onCanPerformMenuAction(
        _ handler: @escaping (LKAnyItemContext, Selector, Any?) -> Bool
    ) -> Self {
        var events = events
        events.canPerformMenuAction = handler
        return replacing(events: events)
    }

    public func onPerformMenuAction(
        _ handler: @escaping (LKAnyItemContext, Selector, Any?) -> Void
    ) -> Self {
        var events = events
        events.performMenuAction = handler
        return replacing(events: events)
    }

    public func onShouldSpringLoad(
        _ handler: @escaping (LKAnyItemContext, UISpringLoadedInteractionContext) -> Bool
    ) -> Self {
        var events = events
        events.shouldSpringLoad = handler
        return replacing(events: events)
    }

    public func swipeActions(
        edge: LKSwipeActionsEdge = .trailing,
        allowsFullSwipe: Bool = true,
        actions: @escaping (LKAnyItemContext) -> [LKSwipeAction]
    ) -> Self {
        var events = events
        let provider: (LKAnyItemContext) -> LKSwipeActions? = { context in
            let actions = actions(context)
            guard actions.isEmpty == false else { return nil }
            return LKSwipeActions(actions: actions, allowsFullSwipe: allowsFullSwipe)
        }

        switch edge {
        case .leading:
            events.leadingSwipeActions = provider
        case .trailing:
            events.trailingSwipeActions = provider
        }
        return replacing(events: events)
    }
    #endif

    public func scrollIndicators(_ visibility: LKScrollIndicatorVisibility) -> Self {
        var scrollConfiguration = scrollConfiguration
        scrollConfiguration.indicatorVisibility = visibility
        return replacing(scrollConfiguration: scrollConfiguration)
    }

    public func contentInsets(_ insets: LKEdgeInsets) -> Self {
        var scrollConfiguration = scrollConfiguration
        scrollConfiguration.contentInsets = insets
        return replacing(scrollConfiguration: scrollConfiguration)
    }

    #if canImport(UIKit)
    public func keyboardDismissMode(_ mode: UIScrollView.KeyboardDismissMode) -> Self {
        var scrollConfiguration = scrollConfiguration
        scrollConfiguration.keyboardDismissMode = mode.rawValue
        return replacing(scrollConfiguration: scrollConfiguration)
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
        Self(
            model: model,
            events: events,
            selectionConfiguration: selectionConfiguration,
            scrollConfiguration: scrollConfiguration,
            refreshConfiguration: refreshConfiguration,
            diagnosticsMode: diagnosticsMode,
            sections: sections,
            style: style,
            updateEngine: updateEngine
        )
        #else
        self
        #endif
    }

    private func replacing(selectionConfiguration: LKSelectionConfiguration) -> Self {
        #if canImport(UIKit)
        Self(
            model: model,
            events: events,
            selectionConfiguration: selectionConfiguration,
            scrollConfiguration: scrollConfiguration,
            refreshConfiguration: refreshConfiguration,
            diagnosticsMode: diagnosticsMode,
            sections: sections,
            style: style,
            updateEngine: updateEngine
        )
        #else
        self
        #endif
    }

    private func replacing(scrollConfiguration: LKScrollConfiguration) -> Self {
        #if canImport(UIKit)
        Self(
            model: model,
            events: events,
            selectionConfiguration: selectionConfiguration,
            scrollConfiguration: scrollConfiguration,
            refreshConfiguration: refreshConfiguration,
            diagnosticsMode: diagnosticsMode,
            sections: sections,
            style: style,
            updateEngine: updateEngine
        )
        #else
        self
        #endif
    }

    private func replacing(events: LKListEvents, scrollConfiguration: LKScrollConfiguration) -> Self {
        #if canImport(UIKit)
        Self(
            model: model,
            events: events,
            selectionConfiguration: selectionConfiguration,
            scrollConfiguration: scrollConfiguration,
            refreshConfiguration: refreshConfiguration,
            diagnosticsMode: diagnosticsMode,
            sections: sections,
            style: style,
            updateEngine: updateEngine
        )
        #else
        self
        #endif
    }

    private func replacing(refreshConfiguration: LKRefreshConfiguration) -> Self {
        #if canImport(UIKit)
        Self(
            model: model,
            events: events,
            selectionConfiguration: selectionConfiguration,
            scrollConfiguration: scrollConfiguration,
            refreshConfiguration: refreshConfiguration,
            diagnosticsMode: diagnosticsMode,
            sections: sections,
            style: style,
            updateEngine: updateEngine
        )
        #else
        self
        #endif
    }

    private func replacing(diagnosticsMode: LKListKitDiagnosticsMode) -> Self {
        #if canImport(UIKit)
        Self(
            model: model,
            events: events,
            selectionConfiguration: selectionConfiguration,
            scrollConfiguration: scrollConfiguration,
            refreshConfiguration: refreshConfiguration,
            diagnosticsMode: diagnosticsMode,
            sections: sections,
            style: style,
            updateEngine: updateEngine
        )
        #else
        self
        #endif
    }
}
#endif
