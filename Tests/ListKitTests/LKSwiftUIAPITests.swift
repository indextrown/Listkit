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
