#if canImport(SwiftUI)
import SwiftUI
import XCTest
@testable import ListKit
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class LKSwiftUIAPITests: XCTestCase {
    private struct Message: Identifiable {
        let id: Int
        let title: String
    }

    func testDataInitializerBuildsSingleSectionModel() {
        let messages = [
            Message(id: 1, title: "First"),
            Message(id: 2, title: "Second"),
        ]

        let list = LKList(messages, id: \.id) { message in
            Text(message.title)
        }

        XCTAssertEqual(list.model.sections.count, 1)
        XCTAssertEqual(list.model.sections[0].id, AnyHashable("ListKit.default-section"))
        XCTAssertEqual(list.model.sections[0].items.map(\.id), [AnyHashable(1), AnyHashable(2)])
    }

    func testSectionDSLBuildsModelWithRowsHeaderAndFooter() {
        let messages = [
            Message(id: 1, title: "First"),
            Message(id: 2, title: "Second"),
        ]

        let list = LKList {
            LKSection(id: "inbox") {
                for message in messages {
                    LKRow(message, id: \.id) {
                        Text(message.title)
                    }
                    .equatableToken(message.title)
                }
            } header: {
                Text("Inbox")
            } footer: {
                Text("2 messages")
            }
        }

        XCTAssertEqual(list.model.sections.count, 1)
        XCTAssertEqual(list.model.sections[0].id, AnyHashable("inbox"))
        XCTAssertEqual(list.model.sections[0].items.count, 2)
        XCTAssertEqual(list.model.sections[0].items[0].contentToken, AnyHashable("First"))
        XCTAssertEqual(list.model.sections[0].header?.kind, .header)
        XCTAssertEqual(list.model.sections[0].footer?.kind, .footer)
    }

    func testStaticRowsCompileInSectionDSL() {
        let list = LKList {
            LKSection(id: "static") {
                LKRow(id: "one") {
                    Text("One")
                }

                LKRow(id: "two") {
                    Text("Two")
                }
            }
        }

        XCTAssertEqual(list.model.sections[0].items.map(\.id), [
            AnyHashable("one"),
            AnyHashable("two"),
        ])
    }

    func testListKitEnvironmentValuesDefaultAndSetBehavior() {
        var values = EnvironmentValues()

        XCTAssertFalse(values.listKitIsSelected)
        XCTAssertFalse(values.listKitIsHighlighted)
        XCTAssertFalse(values.listKitIsFocused)
        XCTAssertNil(values.listKitIndexPath)
        XCTAssertNil(values.listKitSectionID)
        XCTAssertNil(values.listKitItemID)

        values.listKitIsSelected = true
        values.listKitIsHighlighted = true
        values.listKitIsFocused = true
        values.listKitIndexPath = IndexPath.lkIndexPath(item: 1, section: 2)
        values.listKitSectionID = AnyHashable("section")
        values.listKitItemID = AnyHashable("item")

        XCTAssertEqual(
            values.lkCellState,
            LKCellState(isSelected: true, isHighlighted: true, isFocused: true)
        )
        XCTAssertEqual(values.listKitIndexPath, IndexPath.lkIndexPath(item: 1, section: 2))
        XCTAssertEqual(values.listKitSectionID, AnyHashable("section"))
        XCTAssertEqual(values.listKitItemID, AnyHashable("item"))
    }

    #if canImport(UIKit)
    func testListStyleModifierStoresStyle() {
        let list = LKList {
            LKSection(id: "section") {
                LKRow(id: "item") {
                    Text("Item")
                }
            }
        }
        .listKitStyle(.insetGrouped)

        XCTAssertEqual(list.style, .insetGrouped)
    }

    func testSectionLayoutModifierStoresLayoutInModel() {
        let list = LKList {
            LKSection(id: "section") {
                LKRow(id: "item") {
                    Text("Item")
                }
            }
            .sectionLayout(.grid(columns: 2, spacing: 8))
        }

        XCTAssertEqual(list.model.sections[0].layout, .grid(columns: 2, spacing: 8))
    }

    func testSectionSupplementaryDisplayModifiersStoreHandlersInModel() {
        let list = LKList {
            LKSection(id: "section") {
                LKRow(id: "item") {
                    Text("Item")
                }
            } header: {
                Text("Header")
            } footer: {
                Text("Footer")
            }
            .onWillDisplayHeader { _ in }
            .onDidEndDisplayingHeader { _ in }
            .onWillDisplayFooter { _ in }
            .onDidEndDisplayingFooter { _ in }
        }

        XCTAssertNotNil(list.model.sections[0].headerEvents.willDisplay)
        XCTAssertNotNil(list.model.sections[0].headerEvents.didEndDisplaying)
        XCTAssertNotNil(list.model.sections[0].footerEvents.willDisplay)
        XCTAssertNotNil(list.model.sections[0].footerEvents.didEndDisplaying)
    }

    func testSelectionModifiersStoreSelectionConfiguration() {
        var selectedID: Int?
        var selectedIDs = Set<Int>()

        let singleSelection = Binding<Int?>(
            get: { selectedID },
            set: { selectedID = $0 }
        )
        let multipleSelection = Binding<Set<Int>>(
            get: { selectedIDs },
            set: { selectedIDs = $0 }
        )

        let singleList = LKList([Message(id: 1, title: "One")], id: \.id) { message in
            Text(message.title)
        }
        .selection(singleSelection)
        let multipleList = LKList([Message(id: 1, title: "One")], id: \.id) { message in
            Text(message.title)
        }
        .selection(multipleSelection)
        .selectionMode(.none)

        XCTAssertEqual(singleList.selectionConfiguration.mode, .single)
        XCTAssertEqual(multipleList.selectionConfiguration.mode, .none)
    }

    func testScrollModifiersStoreEventsAndConfiguration() {
        let list = LKList([Message(id: 1, title: "One")], id: \.id) { message in
            Text(message.title)
        }
        .onScroll { _ in }
        .onWillBeginDragging { _ in }
        .onWillEndDragging { _ in }
        .onDidEndDragging { _ in }
        .onWillBeginDecelerating { _ in }
        .onDidEndDecelerating { _ in }
        .onShouldScrollToTop { _ in false }
        .onDidScrollToTop { _ in }
        .onReachEnd(threshold: .points(120)) {}
        .scrollIndicators(.hidden)
        .keyboardDismissMode(.onDrag)
        .contentInsets(LKEdgeInsets(top: 1, left: 2, bottom: 3, right: 4))

        XCTAssertNotNil(list.events.didScroll)
        XCTAssertNotNil(list.events.willBeginDragging)
        XCTAssertNotNil(list.events.willEndDragging)
        XCTAssertNotNil(list.events.didEndDragging)
        XCTAssertNotNil(list.events.willBeginDecelerating)
        XCTAssertNotNil(list.events.didEndDecelerating)
        XCTAssertNotNil(list.events.shouldScrollToTop)
        XCTAssertNotNil(list.events.didScrollToTop)
        XCTAssertNotNil(list.events.didReachEnd)
        XCTAssertEqual(list.scrollConfiguration.indicatorVisibility, .hidden)
        XCTAssertEqual(list.scrollConfiguration.keyboardDismissMode, UIScrollView.KeyboardDismissMode.onDrag.rawValue)
        XCTAssertEqual(list.scrollConfiguration.contentInsets, LKEdgeInsets(top: 1, left: 2, bottom: 3, right: 4))
        XCTAssertEqual(list.scrollConfiguration.reachEndThreshold, .points(120))
    }

    func testPrefetchModifiersStoreEvents() {
        let list = LKList([Message(id: 1, title: "One")], id: \.id) { message in
            Text(message.title)
        }
        .onPrefetch { _ in }
        .onCancelPrefetch { _ in }

        XCTAssertNotNil(list.events.didPrefetch)
        XCTAssertNotNil(list.events.didCancelPrefetch)
    }

    func testDiagnosticsModifiersStoreModeAndWarningHandler() {
        let list = LKList([Message(id: 1, title: "One")], id: \.id) { message in
            Text(message.title)
        }
        .listKitDiagnostics(.enabled)
        .onListKitWarning { _ in }

        XCTAssertEqual(list.diagnosticsMode, .enabled)
        XCTAssertNotNil(list.events.didEmitWarning)
    }

    func testModifierMergePreservesPreviouslyStoredConfiguration() {
        var selectedIDs = Set<Int>()
        let selection = Binding<Set<Int>>(
            get: { selectedIDs },
            set: { selectedIDs = $0 }
        )

        let list = LKList([Message(id: 1, title: "One")], id: \.id) { message in
            Text(message.title)
        }
        .selection(selection)
        .selectionMode(.multiple)
        .onSelect { _ in }
        .onScroll { _ in }
        .onReachEnd(threshold: .points(42)) {}
        .refreshable {}
        .listKitDiagnostics(.enabled)
        .onListKitWarning { _ in }
        .listKitStyle(.grouped)
        .updateEngine(.diffableDataSource)

        XCTAssertEqual(list.selectionConfiguration.mode, .multiple)
        XCTAssertNotNil(list.events.didSelect)
        XCTAssertNotNil(list.events.didScroll)
        XCTAssertNotNil(list.events.didReachEnd)
        XCTAssertEqual(list.scrollConfiguration.reachEndThreshold, .points(42))
        XCTAssertTrue(list.refreshConfiguration.isEnabled)
        XCTAssertEqual(list.diagnosticsMode, .enabled)
        XCTAssertNotNil(list.events.didEmitWarning)
        XCTAssertEqual(list.style, .grouped)
        XCTAssertEqual(list.updateEngine, .diffableDataSource)
    }

    func testAdvancedDelegateModifiersStoreEvents() {
        let list = LKList([Message(id: 1, title: "One")], id: \.id) { message in
            Text(message.title)
        }
        .uiContextMenuConfiguration { _, _ in nil }
        .onPreviewCommit { _, _ in }
        .previewForHighlightingContextMenu { _ in nil }
        .previewForDismissingContextMenu { _ in nil }
        .onCanPerformPrimaryAction { _ in true }
        .onPrimaryAction { _ in }
        .onShouldBeginMultipleSelectionInteraction { _ in true }
        .onBeginMultipleSelectionInteraction { _ in }
        .onEndMultipleSelectionInteraction {}
        .onCanFocus { _ in true }
        .onShouldUpdateFocus { _ in true }
        .onDidUpdateFocus { _, _ in }
        .preferredFocusedItem(id: 1)
        .onShouldShowEditMenu { _ in true }
        .onCanPerformMenuAction { _, _, _ in true }
        .onPerformMenuAction { _, _, _ in }
        .onShouldSpringLoad { _, _ in true }

        XCTAssertNotNil(list.events.uiContextMenuConfiguration)
        XCTAssertNotNil(list.events.uiWillPerformPreviewAction)
        XCTAssertNotNil(list.events.uiPreviewForHighlightingContextMenu)
        XCTAssertNotNil(list.events.uiPreviewForDismissingContextMenu)
        XCTAssertNotNil(list.events.canPerformPrimaryAction)
        XCTAssertNotNil(list.events.didPerformPrimaryAction)
        XCTAssertNotNil(list.events.shouldBeginMultipleSelectionInteraction)
        XCTAssertNotNil(list.events.didBeginMultipleSelectionInteraction)
        XCTAssertNotNil(list.events.didEndMultipleSelectionInteraction)
        XCTAssertNotNil(list.events.canFocus)
        XCTAssertNotNil(list.events.shouldUpdateFocus)
        XCTAssertNotNil(list.events.didUpdateFocus)
        XCTAssertEqual(list.events.preferredFocusedItemID, AnyHashable(1))
        XCTAssertNotNil(list.events.shouldShowEditMenu)
        XCTAssertNotNil(list.events.canPerformMenuAction)
        XCTAssertNotNil(list.events.performMenuAction)
        XCTAssertNotNil(list.events.shouldSpringLoad)
    }

    func testRefreshModifiersStoreConfiguration() {
        let list = LKList([Message(id: 1, title: "One")], id: \.id) { message in
            Text(message.title)
        }
        .refreshable {}
        .refreshControlTint(.systemBlue)

        XCTAssertTrue(list.refreshConfiguration.isEnabled)
        XCTAssertEqual(list.refreshConfiguration.tintColor, .systemBlue)
    }

    func testSwiftUISearchableComposesWithList() {
        var query = ""
        let queryBinding = Binding<String>(
            get: { query },
            set: { query = $0 }
        )

        let view = LKList([Message(id: 1, title: "One")], id: \.id) { message in
            Text(message.title)
        }
        .searchable(text: queryBinding)

        _ = view
        XCTAssertEqual(query, "")
    }
    #endif
}
#endif
