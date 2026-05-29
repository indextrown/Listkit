#if canImport(UIKit) && canImport(SwiftUI)
import XCTest
import UIKit
import SwiftUI
@testable import ListKit

@MainActor
final class LKCollectionViewAdapterTests: XCTestCase {
    private struct EnvironmentProbeView: View {
        @Environment(\.listKitIsSelected) private var isSelected
        @Environment(\.listKitIsHighlighted) private var isHighlighted
        @Environment(\.listKitIsFocused) private var isFocused
        @Environment(\.listKitIndexPath) private var indexPath
        @Environment(\.listKitSectionID) private var sectionID
        @Environment(\.listKitItemID) private var itemID

        let onRead: (
            Bool,
            Bool,
            Bool,
            IndexPath?,
            AnyHashable?,
            AnyHashable?
        ) -> Void

        var body: some View {
            onRead(isSelected, isHighlighted, isFocused, indexPath, sectionID, itemID)
            return Text("Probe")
        }
    }

    func testRegistrationKeysAreNotDuplicatedAcrossApplies() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        let model = makeModel()

        adapter.apply(model)
        adapter.apply(model)

        XCTAssertEqual(adapter.registeredCellKeys.count, 1)
        XCTAssertEqual(adapter.registeredHeaderKeys.count, 1)
        XCTAssertEqual(adapter.registeredFooterKeys.count, 1)
    }

    func testIdenticalModelApplyDoesNotReloadDataAgain() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView, updateEngine: .reloadData)
        let model = makeModel()
        var reloadCount = 0

        adapter.reloadDataHandler = {
            reloadCount += 1
        }

        adapter.apply(model)
        adapter.apply(model)

        XCTAssertEqual(reloadCount, 1)
    }

    func testQueuedUpdateKeepsLastUpdateWhileApplyIsRunning() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView, updateEngine: .reloadData)
        let first = makeModel(sectionID: "first", itemID: "first-item")
        let second = makeModel(sectionID: "second", itemID: "second-item")
        let third = makeModel(sectionID: "third", itemID: "third-item")
        var didReenter = false

        adapter.reloadDataHandler = {
            guard didReenter == false else { return }
            didReenter = true
            adapter.apply(second)
            adapter.apply(third)
        }

        adapter.apply(first)

        XCTAssertEqual(adapter.currentModel.sections.first?.id, AnyHashable("third"))
        XCTAssertEqual(adapter.currentModel.sections.first?.items.first?.id, AnyHashable("third-item"))
    }

    func testSnapshotReflectsCurrentModelAfterApply() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        let model = makeModel(sectionID: "snapshot", itemID: "item")

        adapter.apply(model)

        XCTAssertEqual(adapter.currentModel, model)
        XCTAssertEqual(adapter.numberOfSections(in: collectionView), 1)
        XCTAssertEqual(adapter.collectionView(collectionView, numberOfItemsInSection: 0), 1)
    }

    func testReloadDataApplyReflectsAppendRemoveAndUpdate() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView, updateEngine: .reloadData)
        let oneItem = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [LKItemModel(id: "one")]),
            ]
        )
        let twoItems = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "one"),
                    LKItemModel(id: "two"),
                ]),
            ]
        )
        let noItems = LKListModel(sections: [LKSectionModel(id: "section")])

        adapter.apply(oneItem)
        XCTAssertEqual(adapter.collectionView(collectionView, numberOfItemsInSection: 0), 1)

        adapter.apply(twoItems)
        XCTAssertEqual(adapter.collectionView(collectionView, numberOfItemsInSection: 0), 2)

        adapter.apply(noItems)
        XCTAssertEqual(adapter.collectionView(collectionView, numberOfItemsInSection: 0), 0)
    }

    func testReloadDataRegistersReuseIdentifiersBeforeReload() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView, updateEngine: .reloadData)
        let item = LKItemModel(id: "item", reuseIdentifier: "custom-cell")
        let model = LKListModel(sections: [LKSectionModel(id: "section", items: [item])])
        var didRegisterBeforeReload = false

        adapter.reloadDataHandler = {
            didRegisterBeforeReload = adapter.registeredCellKeys.contains(
                LKCellRegistrationKey(
                    reuseIdentifier: "custom-cell",
                    hostingStrategy: .hostingConfiguration
                )
            )
        }

        adapter.apply(model)

        XCTAssertTrue(didRegisterBeforeReload)
    }

    func testReloadDataDequeuedCellUsesLatestModelAfterUpdate() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView, updateEngine: .reloadData)
        let first = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [LKItemModel(id: "first")]),
            ]
        )
        let latest = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [LKItemModel(id: "latest")]),
            ]
        )

        adapter.apply(first)
        adapter.apply(latest)

        let cell = adapter.collectionView(
            collectionView,
            cellForItemAt: IndexPath.lkIndexPath(item: 0, section: 0)
        ) as? LKHostingCollectionViewCell

        XCTAssertEqual(cell?.renderedItemID, AnyHashable("latest"))
    }

    func testDequeuedCellReceivesListKitEnvironmentMetadata() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        let indexPath = IndexPath.lkIndexPath(item: 1, section: 0)
        let model = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "one"),
                    LKItemModel(id: "two"),
                ]),
            ]
        )

        adapter.apply(model)
        let cell = adapter.collectionView(collectionView, cellForItemAt: indexPath) as? LKHostingCollectionViewCell

        XCTAssertEqual(cell?.renderedItemID, AnyHashable("two"))
        XCTAssertEqual(cell?.renderedIndexPath, indexPath)
        XCTAssertEqual(cell?.renderedSectionID, AnyHashable("section"))
    }

    func testReloadDataRestoresSelectionByItemIdentity() {
        let collectionView = makeCollectionView()
        collectionView.allowsSelection = true
        let adapter = LKCollectionViewAdapter(collectionView: collectionView, updateEngine: .reloadData)
        let original = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "selected"),
                    LKItemModel(id: "other"),
                ]),
            ]
        )
        let reordered = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "other"),
                    LKItemModel(id: "selected"),
                ]),
            ]
        )

        adapter.apply(original)
        collectionView.selectItem(
            at: IndexPath.lkIndexPath(item: 0, section: 0),
            animated: false,
            scrollPosition: []
        )
        adapter.apply(reordered)

        XCTAssertEqual(collectionView.indexPathsForSelectedItems, [
            IndexPath.lkIndexPath(item: 1, section: 0),
        ])
    }

    func testReloadDataCallsFocusRestorationHook() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView, updateEngine: .reloadData)
        let model = makeModel()
        var didCallFocusHook = false

        adapter.focusRestorationHandler = {
            didCallFocusHook = true
        }

        adapter.apply(model)

        XCTAssertTrue(didCallFocusHook)
    }

    func testEventRoutingUsesRowHandlerBeforeSectionAndListHandlers() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        var item = LKItemModel(id: "item", base: "row")
        var rowDidRun = false
        var sectionDidRun = false
        var listDidRun = false
        item.events.shouldSelect = { context in
            rowDidRun = context.item as? String == "row"
            return false
        }
        var section = LKSectionModel(id: "section", items: [item])
        section.events.shouldSelect = { _ in
            sectionDidRun = true
            return true
        }
        var listEvents = LKListEvents()
        listEvents.shouldSelect = { _ in
            listDidRun = true
            return true
        }

        adapter.apply(LKListModel(sections: [section]), listEvents: listEvents)
        let shouldSelect = adapter.collectionView(
            collectionView,
            shouldSelectItemAt: IndexPath.lkIndexPath(item: 0, section: 0)
        )

        XCTAssertFalse(shouldSelect)
        XCTAssertTrue(rowDidRun)
        XCTAssertFalse(sectionDidRun)
        XCTAssertFalse(listDidRun)
    }

    func testEventRoutingFallsBackFromSectionToListToDefaultBehavior() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        var item = LKItemModel(id: "item")
        var section = LKSectionModel(id: "section", items: [item])
        var didUseSection = false
        section.events.shouldHighlight = { _ in
            didUseSection = true
            return false
        }
        var listEvents = LKListEvents()
        var didUseList = false
        listEvents.shouldDeselect = { _ in
            didUseList = true
            return false
        }

        adapter.apply(LKListModel(sections: [section]), listEvents: listEvents)

        XCTAssertFalse(
            adapter.collectionView(
                collectionView,
                shouldHighlightItemAt: IndexPath.lkIndexPath(item: 0, section: 0)
            )
        )
        XCTAssertTrue(didUseSection)
        XCTAssertFalse(
            adapter.collectionView(
                collectionView,
                shouldDeselectItemAt: IndexPath.lkIndexPath(item: 0, section: 0)
            )
        )
        XCTAssertTrue(didUseList)

        item.events = LKRowEvents()
        adapter.apply(LKListModel(sections: [LKSectionModel(id: "section", items: [item])]))
        XCTAssertTrue(
            adapter.collectionView(
                collectionView,
                shouldSelectItemAt: IndexPath.lkIndexPath(item: 0, section: 0)
            )
        )
    }

    func testEventContextUsesLatestSnapshotIdentifiers() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        var listEvents = LKListEvents()
        var receivedContext: LKAnyItemContext?
        listEvents.didSelect = { context in
            receivedContext = context
        }
        let first = LKListModel(
            sections: [
                LKSectionModel(id: "old", items: [LKItemModel(id: "old-item", base: "old")]),
            ]
        )
        let latest = LKListModel(
            sections: [
                LKSectionModel(id: "new", items: [LKItemModel(id: "new-item", base: "new")]),
            ]
        )

        adapter.apply(first, listEvents: listEvents)
        adapter.apply(latest)
        adapter.collectionView(
            collectionView,
            didSelectItemAt: IndexPath.lkIndexPath(item: 0, section: 0)
        )

        XCTAssertEqual(receivedContext?.id, AnyHashable("new-item"))
        XCTAssertEqual(receivedContext?.sectionID, AnyHashable("new"))
        XCTAssertEqual(receivedContext?.item as? String, "new")
        XCTAssertEqual(receivedContext?.indexPath, IndexPath.lkIndexPath(item: 0, section: 0))
    }

    func testDelegateCallbacksRouteItemHandlersWithContext() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        let indexPath = IndexPath.lkIndexPath(item: 0, section: 0)
        var item = LKItemModel(id: "item", base: "payload")
        var routedEvents = [String]()
        var receivedContext: LKAnyItemContext?

        item.events.didSelect = { context in
            routedEvents.append("select")
            receivedContext = context
        }
        item.events.didDeselect = { _ in routedEvents.append("deselect") }
        item.events.didHighlight = { _ in routedEvents.append("highlight") }
        item.events.didUnhighlight = { _ in routedEvents.append("unhighlight") }
        item.events.willDisplay = { _ in routedEvents.append("willDisplay") }
        item.events.didEndDisplaying = { _ in routedEvents.append("didEndDisplaying") }

        adapter.apply(LKListModel(sections: [LKSectionModel(id: "section", items: [item])]))
        adapter.collectionView(collectionView, didSelectItemAt: indexPath)
        adapter.collectionView(collectionView, didDeselectItemAt: indexPath)
        adapter.collectionView(collectionView, didHighlightItemAt: indexPath)
        adapter.collectionView(collectionView, didUnhighlightItemAt: indexPath)
        adapter.collectionView(collectionView, willDisplay: UICollectionViewCell(), forItemAt: indexPath)
        adapter.collectionView(collectionView, didEndDisplaying: UICollectionViewCell(), forItemAt: indexPath)

        XCTAssertEqual(routedEvents, [
            "select",
            "deselect",
            "highlight",
            "unhighlight",
            "willDisplay",
            "didEndDisplaying",
        ])
        XCTAssertEqual(receivedContext?.id, AnyHashable("item"))
        XCTAssertEqual(receivedContext?.sectionID, AnyHashable("section"))
        XCTAssertEqual(receivedContext?.indexPath, indexPath)
    }

    func testSupplementaryDisplayCallbacksRouteHeaderAndFooterHandlers() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        let indexPath = IndexPath.lkIndexPath(item: 0, section: 0)
        var section = LKSectionModel(
            id: "section",
            header: LKSupplementaryModel(id: "header", kind: .header),
            footer: LKSupplementaryModel(id: "footer", kind: .footer)
        )
        var contexts = [LKSupplementaryContext]()
        var routedEvents = [String]()

        section.headerEvents.willDisplay = { context in
            routedEvents.append("headerWillDisplay")
            contexts.append(context)
        }
        section.headerEvents.didEndDisplaying = { _ in routedEvents.append("headerDidEndDisplaying") }
        section.footerEvents.willDisplay = { context in
            routedEvents.append("footerWillDisplay")
            contexts.append(context)
        }
        section.footerEvents.didEndDisplaying = { _ in routedEvents.append("footerDidEndDisplaying") }

        adapter.apply(LKListModel(sections: [section]))
        adapter.collectionView(
            collectionView,
            willDisplaySupplementaryView: UICollectionReusableView(),
            forElementKind: UICollectionView.elementKindSectionHeader,
            at: indexPath
        )
        adapter.collectionView(
            collectionView,
            didEndDisplayingSupplementaryView: UICollectionReusableView(),
            forElementOfKind: UICollectionView.elementKindSectionHeader,
            at: indexPath
        )
        adapter.collectionView(
            collectionView,
            willDisplaySupplementaryView: UICollectionReusableView(),
            forElementKind: UICollectionView.elementKindSectionFooter,
            at: indexPath
        )
        adapter.collectionView(
            collectionView,
            didEndDisplayingSupplementaryView: UICollectionReusableView(),
            forElementOfKind: UICollectionView.elementKindSectionFooter,
            at: indexPath
        )

        XCTAssertEqual(routedEvents, [
            "headerWillDisplay",
            "headerDidEndDisplaying",
            "footerWillDisplay",
            "footerDidEndDisplaying",
        ])
        XCTAssertEqual(contexts.map(\.id), [AnyHashable("header"), AnyHashable("footer")])
        XCTAssertEqual(contexts.map(\.sectionID), [AnyHashable("section"), AnyHashable("section")])
        XCTAssertEqual(contexts.map(\.indexPath), [indexPath, indexPath])
    }

    func testSingleSelectionBindingSynchronizesExternalAndUserSelection() {
        let collectionView = makeCollectionView()
        var selectedID: String? = "two"
        let selection = LKSelectionConfiguration(
            selection: Binding<String?>(
                get: { selectedID },
                set: { selectedID = $0 }
            )
        )
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            selectionConfiguration: selection
        )
        let model = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "one"),
                    LKItemModel(id: "two"),
                ]),
            ]
        )

        adapter.apply(model, selectionConfiguration: selection)

        XCTAssertTrue(collectionView.allowsSelection)
        XCTAssertFalse(collectionView.allowsMultipleSelection)
        XCTAssertEqual(collectionView.indexPathsForSelectedItems, [
            IndexPath.lkIndexPath(item: 1, section: 0),
        ])

        adapter.collectionView(
            collectionView,
            didSelectItemAt: IndexPath.lkIndexPath(item: 0, section: 0)
        )

        XCTAssertEqual(selectedID, "one")
    }

    func testMultipleSelectionBindingSynchronizesAndPrunesRemovedIDs() {
        let collectionView = makeCollectionView()
        var selectedIDs: Set<String> = ["one", "missing"]
        let selection = LKSelectionConfiguration(
            selection: Binding<Set<String>>(
                get: { selectedIDs },
                set: { selectedIDs = $0 }
            )
        )
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            selectionConfiguration: selection
        )
        let model = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "one"),
                    LKItemModel(id: "two"),
                ]),
            ]
        )

        adapter.apply(model, selectionConfiguration: selection)

        XCTAssertTrue(collectionView.allowsMultipleSelection)
        XCTAssertEqual(selectedIDs, ["one"])
        XCTAssertEqual(collectionView.indexPathsForSelectedItems, [
            IndexPath.lkIndexPath(item: 0, section: 0),
        ])

        adapter.collectionView(
            collectionView,
            didSelectItemAt: IndexPath.lkIndexPath(item: 1, section: 0)
        )
        XCTAssertEqual(selectedIDs, ["one", "two"])

        adapter.apply(
            LKListModel(sections: [LKSectionModel(id: "section")]),
            selectionConfiguration: selection
        )
        XCTAssertTrue(selectedIDs.isEmpty)
        XCTAssertTrue(collectionView.indexPathsForSelectedItems?.isEmpty ?? true)
    }

    func testSelectionBindingPruningCanBeDeferredDuringRepresentableUpdate() async {
        let collectionView = makeCollectionView()
        var selectedIDs: Set<String> = ["one", "missing"]
        let selection = LKSelectionConfiguration(
            selection: Binding<Set<String>>(
                get: { selectedIDs },
                set: { selectedIDs = $0 }
            )
        )
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            selectionConfiguration: selection
        )
        let model = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "one"),
                    LKItemModel(id: "two"),
                ]),
            ]
        )

        adapter.apply(
            model,
            selectionConfiguration: selection,
            deferSelectionBindingUpdates: true
        )

        XCTAssertEqual(selectedIDs, ["one", "missing"])

        await Task.yield()

        XCTAssertEqual(selectedIDs, ["one"])
    }

    func testDeferredSelectionPruningDoesNotOverwriteNewerSelection() async {
        let collectionView = makeCollectionView()
        var selectedIDs: Set<String> = ["one", "missing"]
        let selection = LKSelectionConfiguration(
            selection: Binding<Set<String>>(
                get: { selectedIDs },
                set: { selectedIDs = $0 }
            )
        )
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            selectionConfiguration: selection
        )
        let model = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "one"),
                    LKItemModel(id: "two"),
                ]),
            ]
        )

        adapter.apply(
            model,
            selectionConfiguration: selection,
            deferSelectionBindingUpdates: true
        )
        selectedIDs = ["two"]

        await Task.yield()

        XCTAssertEqual(selectedIDs, ["two"])
    }

    func testSelectionModeNoneDisablesSelectionAndClearsBinding() {
        let collectionView = makeCollectionView()
        var selectedID: String? = "one"
        let selection = LKSelectionConfiguration(
            selection: Binding<String?>(
                get: { selectedID },
                set: { selectedID = $0 }
            )
        )
        .replacing(mode: .none)
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            selectionConfiguration: selection
        )

        adapter.apply(
            LKListModel(
                sections: [
                    LKSectionModel(id: "section", items: [LKItemModel(id: "one")]),
                ]
            ),
            selectionConfiguration: selection
        )

        XCTAssertFalse(collectionView.allowsSelection)
        XCTAssertFalse(collectionView.allowsMultipleSelection)
        XCTAssertNil(selectedID)
    }

    func testRejectedSelectionDoesNotMutateSelectionBinding() {
        let collectionView = makeCollectionView()
        var selectedID: String?
        var item = LKItemModel(id: "blocked")
        item.events.shouldSelect = { _ in false }
        let selection = LKSelectionConfiguration(
            selection: Binding<String?>(
                get: { selectedID },
                set: { selectedID = $0 }
            )
        )
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            selectionConfiguration: selection
        )

        adapter.apply(
            LKListModel(sections: [LKSectionModel(id: "section", items: [item])]),
            selectionConfiguration: selection
        )

        XCTAssertFalse(
            adapter.collectionView(
                collectionView,
                shouldSelectItemAt: IndexPath.lkIndexPath(item: 0, section: 0)
            )
        )
        XCTAssertNil(selectedID)
    }

    func testScrollConfigurationAppliesToCollectionView() {
        let collectionView = makeCollectionView()
        var scrollConfiguration = LKScrollConfiguration()
        scrollConfiguration.indicatorVisibility = .hidden
        scrollConfiguration.keyboardDismissMode = UIScrollView.KeyboardDismissMode.onDrag.rawValue
        scrollConfiguration.contentInsets = LKEdgeInsets(top: 8, left: 7, bottom: 6, right: 5)

        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            scrollConfiguration: scrollConfiguration
        )
        adapter.apply(makeModel(), scrollConfiguration: scrollConfiguration)

        XCTAssertFalse(collectionView.showsVerticalScrollIndicator)
        XCTAssertFalse(collectionView.showsHorizontalScrollIndicator)
        XCTAssertEqual(collectionView.keyboardDismissMode, .onDrag)
        XCTAssertEqual(collectionView.contentInset, UIEdgeInsets(top: 8, left: 7, bottom: 6, right: 5))
    }

    func testScrollDelegateCallbacksRouteScrollContext() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        var events = LKListEvents()
        var routedEvents = [String]()
        var receivedContext: LKScrollContext?

        collectionView.contentSize = CGSize(width: 320, height: 1_000)
        collectionView.contentOffset = CGPoint(x: 0, y: 120)
        events.didScroll = { context in
            routedEvents.append("didScroll")
            receivedContext = context
        }
        events.willBeginDragging = { _ in routedEvents.append("willBeginDragging") }
        events.willEndDragging = { _ in routedEvents.append("willEndDragging") }
        events.didEndDragging = { _ in routedEvents.append("didEndDragging") }
        events.willBeginDecelerating = { _ in routedEvents.append("willBeginDecelerating") }
        events.didEndDecelerating = { _ in routedEvents.append("didEndDecelerating") }
        events.didScrollToTop = { _ in routedEvents.append("didScrollToTop") }

        adapter.apply(makeModel(), listEvents: events)
        adapter.scrollViewDidScroll(collectionView)
        adapter.scrollViewWillBeginDragging(collectionView)
        var targetContentOffset = CGPoint.zero
        withUnsafeMutablePointer(to: &targetContentOffset) { pointer in
            adapter.scrollViewWillEndDragging(
                collectionView,
                withVelocity: CGPoint(x: 0, y: 1),
                targetContentOffset: pointer
            )
        }
        adapter.scrollViewDidEndDragging(collectionView, willDecelerate: true)
        adapter.scrollViewWillBeginDecelerating(collectionView)
        adapter.scrollViewDidEndDecelerating(collectionView)
        adapter.scrollViewDidScrollToTop(collectionView)

        XCTAssertEqual(routedEvents, [
            "didScroll",
            "willBeginDragging",
            "willEndDragging",
            "didEndDragging",
            "willBeginDecelerating",
            "didEndDecelerating",
            "didScrollToTop",
        ])
        XCTAssertEqual(receivedContext?.contentOffset, CGPoint(x: 0, y: 120))
        XCTAssertEqual(receivedContext?.contentSize, CGSize(width: 320, height: 1_000))
        XCTAssertEqual(receivedContext?.boundsSize, collectionView.bounds.size)
    }

    func testScrollViewShouldScrollToTopUsesHandlerOrDefault() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        var events = LKListEvents()
        events.shouldScrollToTop = { _ in false }

        adapter.apply(makeModel(), listEvents: events)
        XCTAssertFalse(adapter.scrollViewShouldScrollToTop(collectionView))

        adapter.apply(makeModel(), listEvents: LKListEvents())
        XCTAssertTrue(adapter.scrollViewShouldScrollToTop(collectionView))
    }

    func testListProxyScrollToTopUsesAdjustedContentInset() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        collectionView.contentInset = UIEdgeInsets(top: 24, left: 0, bottom: 0, right: 0)
        collectionView.contentOffset = CGPoint(x: 8, y: 300)

        adapter.scrollToTop(animated: false)

        XCTAssertEqual(collectionView.contentOffset, CGPoint(x: 8, y: -collectionView.adjustedContentInset.top))
    }

    func testListProxyScrollToOffsetUsesRequestedOffset() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        let targetOffset = CGPoint(x: 12, y: 240)

        adapter.scrollToOffset(targetOffset, animated: false)

        XCTAssertEqual(collectionView.contentOffset, targetOffset)
    }

    func testListProxyScrollToItemAndSectionResolveCurrentModelIDs() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        let model = LKListModel(
            sections: [
                LKSectionModel(
                    id: "first-section",
                    items: [
                        LKItemModel(id: "first"),
                    ]
                ),
                LKSectionModel(
                    id: "second-section",
                    items: [
                        LKItemModel(id: "second"),
                    ]
                ),
            ]
        )
        adapter.apply(model)

        XCTAssertTrue(adapter.scrollToItem(id: "second", sectionID: "second-section", position: .top, animated: false))
        XCTAssertTrue(adapter.scrollToSection(id: "second-section", position: .top, animated: false))
        XCTAssertFalse(adapter.scrollToItem(id: "missing", sectionID: nil, position: .top, animated: false))
        XCTAssertFalse(adapter.scrollToSection(id: "missing-section", position: .top, animated: false))
    }

    func testReachEndFiresAtThresholdAndRearmsAfterMovingAway() {
        let collectionView = makeCollectionView()
        collectionView.contentSize = CGSize(width: 320, height: 1_000)
        var events = LKListEvents()
        var reachEndCount = 0
        events.didReachEnd = {
            reachEndCount += 1
        }
        var scrollConfiguration = LKScrollConfiguration()
        scrollConfiguration.reachEndThreshold = .points(80)
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            listEvents: events,
            scrollConfiguration: scrollConfiguration
        )

        collectionView.contentOffset = CGPoint(x: 0, y: 400)
        adapter.scrollViewDidScroll(collectionView)
        XCTAssertEqual(reachEndCount, 0)

        collectionView.contentOffset = CGPoint(x: 0, y: 540)
        adapter.scrollViewDidScroll(collectionView)
        adapter.scrollViewDidScroll(collectionView)
        XCTAssertEqual(reachEndCount, 1)

        collectionView.contentOffset = CGPoint(x: 0, y: 100)
        adapter.scrollViewDidScroll(collectionView)
        collectionView.contentOffset = CGPoint(x: 0, y: 540)
        adapter.scrollViewDidScroll(collectionView)
        XCTAssertEqual(reachEndCount, 2)

        collectionView.contentSize = CGSize(width: 320, height: 1_200)
        collectionView.contentOffset = CGPoint(x: 0, y: 740)
        adapter.scrollViewDidScroll(collectionView)
        XCTAssertEqual(reachEndCount, 3)
    }

    func testRefreshControlIsInstalledAndUsesTint() {
        let collectionView = makeCollectionView()
        var refreshConfiguration = LKRefreshConfiguration()
        refreshConfiguration.action = {}
        refreshConfiguration.tintColor = .systemBlue

        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            refreshConfiguration: refreshConfiguration
        )

        XCTAssertNotNil(collectionView.refreshControl)
        XCTAssertEqual(collectionView.refreshControl?.tintColor, .systemBlue)
        XCTAssertTrue(collectionView.bounces)
        XCTAssertTrue(collectionView.alwaysBounceVertical)

        adapter.apply(makeModel(), refreshConfiguration: LKRefreshConfiguration())
        XCTAssertNil(collectionView.refreshControl)
    }

    func testRefreshControlRunsAsyncActionAndEndsRefreshing() async {
        let collectionView = makeCollectionView()
        var refreshConfiguration = LKRefreshConfiguration()
        let didRefresh = expectation(description: "runs refresh action")
        refreshConfiguration.action = {
            didRefresh.fulfill()
        }
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            refreshConfiguration: refreshConfiguration
        )

        collectionView.refreshControl?.beginRefreshing()
        if let refreshControl = collectionView.refreshControl {
            adapter.refreshControlValueChanged(refreshControl)
        }

        await fulfillment(of: [didRefresh], timeout: 2.0)
        await Task.yield()

        XCTAssertFalse(collectionView.refreshControl?.isRefreshing ?? true)
    }

    func testRefreshControlIgnoresDuplicateTriggersWhileRunning() async {
        let collectionView = makeCollectionView()
        var refreshConfiguration = LKRefreshConfiguration()
        var continuation: CheckedContinuation<Void, Never>?
        var refreshCount = 0
        refreshConfiguration.action = {
            refreshCount += 1
            await withCheckedContinuation { continuation = $0 }
        }
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            refreshConfiguration: refreshConfiguration
        )

        if let refreshControl = collectionView.refreshControl {
            adapter.refreshControlValueChanged(refreshControl)
            adapter.refreshControlValueChanged(refreshControl)
        }
        await Task.yield()

        XCTAssertEqual(refreshCount, 1)
        continuation?.resume()
        await Task.yield()
    }

    func testDiffableDataSourceApplyReflectsInsertDeleteAndMove() async {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            updateEngine: .diffableDataSource
        )
        let oneItem = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [LKItemModel(id: "one")]),
            ]
        )
        let twoItems = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "two"),
                    LKItemModel(id: "one"),
                ]),
            ]
        )
        let noItems = LKListModel(sections: [LKSectionModel(id: "section")])

        await applyDiffable(oneItem, to: adapter)
        XCTAssertEqual(collectionView.numberOfItems(inSection: 0), 1)

        await applyDiffable(twoItems, to: adapter)
        XCTAssertEqual(collectionView.numberOfItems(inSection: 0), 2)
        XCTAssertEqual(adapter.currentModel.sections.first?.items.first?.id, AnyHashable("two"))

        await applyDiffable(noItems, to: adapter)
        XCTAssertEqual(collectionView.numberOfItems(inSection: 0), 0)
    }

    func testDiffableDataSourceAppliesInitialModelEvenWhenItMatchesCurrentModel() async {
        let collectionView = makeCollectionView()
        let model = makeModel(sectionID: "initial", itemID: "item")
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            model: model,
            updateEngine: .diffableDataSource
        )

        await applyDiffable(model, to: adapter)

        XCTAssertEqual(collectionView.numberOfSections, 1)
        XCTAssertEqual(collectionView.numberOfItems(inSection: 0), 1)
        XCTAssertEqual(adapter.currentModel, model)
    }

    func testDiffableDataSourceRegistersSupplementaryProviderAndCellProvider() async {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            updateEngine: .diffableDataSource
        )
        let model = makeModel(sectionID: "diffable", itemID: "item")

        await applyDiffable(model, to: adapter)

        let cell = collectionView.dataSource?.collectionView(
            collectionView,
            cellForItemAt: IndexPath.lkIndexPath(item: 0, section: 0)
        ) as? LKHostingCollectionViewCell
        let headerView = collectionView.dataSource?.collectionView?(
            collectionView,
            viewForSupplementaryElementOfKind: UICollectionView.elementKindSectionHeader,
            at: IndexPath.lkIndexPath(item: 0, section: 0)
        ) as? LKHostingSupplementaryView

        XCTAssertEqual(cell?.renderedItemID, AnyHashable("item"))
        XCTAssertEqual(headerView?.renderedSupplementaryID, AnyHashable("diffable-header"))
    }

    func testDiffableDataSourceReconfiguresItemsWhenContentTokenChanges() async {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            updateEngine: .diffableDataSource
        )
        let first = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "item", contentToken: "old"),
                ]),
            ]
        )
        let changed = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "item", contentToken: "new"),
                ]),
            ]
        )

        await applyDiffable(first, to: adapter)
        await applyDiffable(changed, to: adapter)

        XCTAssertEqual(
            adapter.lastReconfiguredItemIdentifiers,
            [LKItemIdentifier(sectionID: "section", itemID: "item")]
        )
    }

    func testDiffableDataSourceRestoresSelectionByItemIdentity() async {
        let collectionView = makeCollectionView()
        collectionView.allowsSelection = true
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            updateEngine: .diffableDataSource
        )
        let original = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "selected"),
                    LKItemModel(id: "other"),
                ]),
            ]
        )
        let reordered = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "other"),
                    LKItemModel(id: "selected"),
                ]),
            ]
        )

        await applyDiffable(original, to: adapter)
        collectionView.selectItem(
            at: IndexPath.lkIndexPath(item: 0, section: 0),
            animated: false,
            scrollPosition: []
        )
        await applyDiffable(reordered, to: adapter)

        XCTAssertEqual(collectionView.indexPathsForSelectedItems, [
            IndexPath.lkIndexPath(item: 1, section: 0),
        ])
    }

    func testDiffableDataSourceQueuedUpdateKeepsLastUpdateUntilCompletion() async {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            updateEngine: .diffableDataSource
        )
        let first = makeModel(sectionID: "first", itemID: "first-item")
        let second = makeModel(sectionID: "second", itemID: "second-item")
        let third = makeModel(sectionID: "third", itemID: "third-item")
        var didReenter = false
        let didApplyQueuedUpdate = expectation(description: "applies queued diffable update")

        adapter.diffableApplyCompletionHandler = {
            if didReenter == false {
                didReenter = true
                adapter.apply(second)
                adapter.apply(third)
            } else if adapter.currentModel.sections.first?.id == AnyHashable("third") {
                didApplyQueuedUpdate.fulfill()
            }
        }

        adapter.apply(first)
        await fulfillment(of: [didApplyQueuedUpdate], timeout: 2.0)

        XCTAssertEqual(adapter.currentModel.sections.first?.id, AnyHashable("third"))
        XCTAssertEqual(adapter.currentModel.sections.first?.items.first?.id, AnyHashable("third-item"))
    }

    func testDifferenceKitApplyReflectsInsertDeleteAndMove() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            updateEngine: .differenceKit
        )
        let oneItem = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [LKItemModel(id: "one")]),
            ]
        )
        let twoItems = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "two"),
                    LKItemModel(id: "one"),
                ]),
            ]
        )
        let noItems = LKListModel(sections: [LKSectionModel(id: "section")])

        adapter.apply(oneItem)
        XCTAssertEqual(adapter.collectionView(collectionView, numberOfItemsInSection: 0), 1)

        adapter.apply(twoItems)
        XCTAssertEqual(adapter.collectionView(collectionView, numberOfItemsInSection: 0), 2)
        XCTAssertEqual(adapter.currentModel.sections.first?.items.first?.id, AnyHashable("two"))
        XCTAssertGreaterThan(adapter.lastDifferenceKitChangesetCount, 0)

        adapter.apply(noItems)
        XCTAssertEqual(adapter.collectionView(collectionView, numberOfItemsInSection: 0), 0)
    }

    func testDifferenceKitUsesContentTokenForRowUpdates() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            updateEngine: .differenceKit
        )
        let first = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "item", contentToken: "old"),
                ]),
            ]
        )
        let changed = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "item", contentToken: "new"),
                ]),
            ]
        )

        adapter.apply(first)
        adapter.apply(changed)

        XCTAssertEqual(adapter.currentModel.sections.first?.items.first?.contentToken, AnyHashable("new"))
        XCTAssertGreaterThan(adapter.lastDifferenceKitChangesetCount, 0)
    }

    func testDifferenceKitInitialLoadUsesReloadWithoutFallbackFlag() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            updateEngine: .differenceKit
        )
        let model = LKListModel(
            sections: [
                LKSectionModel(
                    id: "section",
                    items: (0..<100).map { LKItemModel(id: $0) }
                ),
            ]
        )

        adapter.apply(model)

        XCTAssertFalse(adapter.didFallbackFromDifferenceKit)
        XCTAssertEqual(adapter.lastDifferenceKitChangesetCount, 0)
        XCTAssertEqual(adapter.currentModel.sections.first?.items.count, 100)
    }

    func testDifferenceKitRestoresSelectionByItemIdentity() {
        let collectionView = makeCollectionView()
        collectionView.allowsSelection = true
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            updateEngine: .differenceKit
        )
        let original = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "selected"),
                    LKItemModel(id: "other"),
                ]),
            ]
        )
        let reordered = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "other"),
                    LKItemModel(id: "selected"),
                ]),
            ]
        )

        adapter.apply(original)
        collectionView.selectItem(
            at: IndexPath.lkIndexPath(item: 0, section: 0),
            animated: false,
            scrollPosition: []
        )
        adapter.apply(reordered)

        XCTAssertEqual(collectionView.indexPathsForSelectedItems, [
            IndexPath.lkIndexPath(item: 1, section: 0),
        ])
    }

    func testDifferenceKitQueuedUpdateKeepsLastUpdateWhileApplyIsRunning() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            updateEngine: .differenceKit
        )
        let first = makeModel(sectionID: "first", itemID: "first-item")
        let second = makeModel(sectionID: "second", itemID: "second-item")
        let third = makeModel(sectionID: "third", itemID: "third-item")
        var didReenter = false

        adapter.differenceKitApplyCompletionHandler = {
            guard didReenter == false else { return }
            didReenter = true
            adapter.apply(second)
            adapter.apply(third)
        }

        adapter.apply(first)

        XCTAssertEqual(adapter.currentModel.sections.first?.id, AnyHashable("third"))
        XCTAssertEqual(adapter.currentModel.sections.first?.items.first?.id, AnyHashable("third-item"))
    }

    func testDifferenceKitFallsBackToReloadDataForLargeChangeset() {
        let collectionView = makeCollectionView()
        let window = makeVisibleWindow(for: collectionView)
        var events = LKListEvents()
        var warnings = [LKListKitWarning]()
        events.didEmitWarning = { warning in
            warnings.append(warning)
        }
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            listEvents: events,
            diagnosticsMode: .enabled,
            updateEngine: .differenceKit
        )
        let original = LKListModel(
            sections: [
                LKSectionModel(
                    id: "section",
                    items: (0..<10).map { LKItemModel(id: "old-\($0)") }
                ),
            ]
        )
        let large = LKListModel(
            sections: [
                LKSectionModel(
                    id: "section",
                    items: (0..<800).map { LKItemModel(id: "new-\($0)") }
                ),
            ]
        )

        adapter.apply(original)
        adapter.apply(large)

        XCTAssertTrue(adapter.didFallbackFromDifferenceKit)
        XCTAssertTrue(
            warnings.contains(
                .diffFailure(
                    engine: .differenceKit,
                    reason: "DifferenceKit changeset exceeded the animated update threshold and fell back to reload data."
                )
            )
        )
        XCTAssertEqual(adapter.currentModel.sections.first?.items.count, 800)
        _ = window
    }

    func testDiagnosticsMapsDuplicateValidationWarnings() {
        XCTAssertEqual(
            LKListKitWarning(.duplicateSectionID("section")),
            .duplicateSectionID("section")
        )
        XCTAssertEqual(
            LKListKitWarning(.duplicateItemID(sectionID: "section", itemID: "item")),
            .duplicateItemID(sectionID: "section", itemID: "item")
        )
    }

    func testDiagnosticsEmitInvalidLookupAndUnsupportedLayoutWarnings() {
        let collectionView = makeCollectionView()
        var events = LKListEvents()
        var warnings = [LKListKitWarning]()
        events.didEmitWarning = { warning in
            warnings.append(warning)
        }
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            listEvents: events,
            diagnosticsMode: .enabled
        )
        let unsupportedModel = LKListModel(
            sections: [
                LKSectionModel(
                    id: "section",
                    items: [
                        LKItemModel(id: "item"),
                    ],
                    layout: .grid(columns: 0, spacing: 8)
                )
            ]
        )

        adapter.apply(unsupportedModel)
        _ = adapter.collectionView(
            collectionView,
            shouldSelectItemAt: IndexPath.lkIndexPath(item: 0, section: 99)
        )
        _ = adapter.collectionView(
            collectionView,
            shouldSelectItemAt: IndexPath.lkIndexPath(item: 99, section: 0)
        )
        adapter.collectionView(
            collectionView,
            willDisplaySupplementaryView: UICollectionReusableView(),
            forElementKind: UICollectionView.elementKindSectionHeader,
            at: IndexPath.lkIndexPath(item: 0, section: 0)
        )

        XCTAssertTrue(
            warnings.contains(
                .unsupportedLayout(
                    sectionID: "section",
                    reason: "Grid layout requires at least one column. ListKit will clamp the column count to 1."
                )
            )
        )
        XCTAssertTrue(
            warnings.contains(
                .invalidLookup(kind: .section, indexPath: IndexPath.lkIndexPath(item: 0, section: 99))
            )
        )
        XCTAssertTrue(
            warnings.contains(
                .invalidLookup(kind: .item, indexPath: IndexPath.lkIndexPath(item: 99, section: 0))
            )
        )
        XCTAssertTrue(
            warnings.contains(
                .invalidLookup(kind: .supplementary, indexPath: IndexPath.lkIndexPath(item: 0, section: 0))
            )
        )
    }

    func testDiagnosticsDisabledSuppressesRuntimeWarningsWhileFallbackStillWorks() {
        let collectionView = makeCollectionView()
        var events = LKListEvents()
        var warnings = [LKListKitWarning]()
        events.didEmitWarning = { warning in
            warnings.append(warning)
        }
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
            listEvents: events,
            diagnosticsMode: .disabled
        )
        let model = LKListModel(
            sections: [
                LKSectionModel(
                    id: "section",
                    items: [LKItemModel(id: "item")],
                    layout: .grid(columns: 0, spacing: 8)
                ),
            ]
        )

        adapter.apply(model)

        XCTAssertTrue(warnings.isEmpty)
        XCTAssertEqual(adapter.currentModel.sections.first?.items.count, 1)
    }

    func testDequeuedCellRendersSwiftUIContentConfiguration() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        let item = LKItemModel(id: "item") {
            AnyView(Text("Row"))
        }
        let model = LKListModel(sections: [LKSectionModel(id: "section", items: [item])])

        adapter.apply(model)

        let cell = adapter.collectionView(
            collectionView,
            cellForItemAt: IndexPath.lkIndexPath(item: 0, section: 0)
        ) as? LKHostingCollectionViewCell

        XCTAssertEqual(cell?.renderedItemID, AnyHashable("item"))
        XCTAssertNotNil(cell?.contentConfiguration)
        XCTAssertEqual(cell?.renderedState, .inactive)
    }

    func testDequeuedSupplementaryViewsRenderSwiftUIConfigurations() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        var header = LKSupplementaryModel(id: "header", kind: .header) {
            AnyView(Text("Header"))
        }
        header.backgroundColor = .systemBackground
        let footer = LKSupplementaryModel(id: "footer", kind: .footer) {
            AnyView(Text("Footer"))
        }
        let model = LKListModel(
            sections: [
                LKSectionModel(id: "section", header: header, footer: footer),
            ]
        )

        adapter.apply(model)
        collectionView.layoutIfNeeded()

        let headerView = adapter.collectionView(
            collectionView,
            viewForSupplementaryElementOfKind: UICollectionView.elementKindSectionHeader,
            at: IndexPath.lkIndexPath(item: 0, section: 0)
        ) as? LKHostingSupplementaryView
        let footerView = adapter.collectionView(
            collectionView,
            viewForSupplementaryElementOfKind: UICollectionView.elementKindSectionFooter,
            at: IndexPath.lkIndexPath(item: 0, section: 0)
        ) as? LKHostingSupplementaryView

        XCTAssertEqual(headerView?.renderedSupplementaryID, AnyHashable("header"))
        XCTAssertEqual(footerView?.renderedSupplementaryID, AnyHashable("footer"))
        XCTAssertNotNil(headerView?.hostedContentView)
        XCTAssertNotNil(footerView?.hostedContentView)
        XCTAssertEqual(headerView?.backgroundColor, .systemBackground)
        XCTAssertEqual(headerView?.hostedContentView?.backgroundColor, .systemBackground)
        XCTAssertTrue(headerView?.isOpaque == true)
        XCTAssertNil(footerView?.backgroundColor)
    }

    func testCellConfigurationStateIsRenderedIntoSwiftUIEnvironmentState() {
        let cell = LKHostingCollectionViewCell(frame: .zero)
        let item = LKItemModel(id: "item") {
            AnyView(Text("Row"))
        }

        cell.render(item: item)
        cell.isSelected = true
        cell.isHighlighted = true
        cell.setNeedsUpdateConfiguration()
        cell.updateConfiguration(using: cell.configurationState)

        XCTAssertEqual(
            cell.renderedState,
            LKCellState(isSelected: true, isHighlighted: true, isFocused: false)
        )
    }

    func testCellStateChangeUpdatesContentConfigurationWithoutReload() {
        let cell = LKHostingCollectionViewCell(frame: .zero)
        let item = LKItemModel(id: "item") {
            AnyView(Text("Row"))
        }

        cell.render(item: item)
        let initialConfiguration = cell.contentConfiguration

        cell.isSelected = true
        cell.setNeedsUpdateConfiguration()
        cell.updateConfiguration(using: cell.configurationState)

        XCTAssertNotNil(initialConfiguration)
        XCTAssertNotNil(cell.contentConfiguration)
        XCTAssertEqual(cell.renderedState, LKCellState(isSelected: true))
    }

    func testRowContentCanReadListKitEnvironmentValues() {
        let cell = LKHostingCollectionViewCell(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        let viewController = UIViewController()
        var reads = [(
            Bool,
            Bool,
            Bool,
            IndexPath?,
            AnyHashable?,
            AnyHashable?
        )]()
        let item = LKItemModel(id: "item") {
            AnyView(EnvironmentProbeView { isSelected, isHighlighted, isFocused, indexPath, sectionID, itemID in
                reads.append((isSelected, isHighlighted, isFocused, indexPath, sectionID, itemID))
            })
        }

        viewController.view.addSubview(cell)
        window.rootViewController = viewController
        window.makeKeyAndVisible()

        cell.isSelected = true
        cell.isHighlighted = true
        cell.render(
            item: item,
            indexPath: IndexPath.lkIndexPath(item: 3, section: 4),
            sectionID: AnyHashable("section")
        )
        cell.layoutIfNeeded()
        _ = window

        XCTAssertTrue(reads.contains { read in
            read.0 == true
                && read.1 == true
                && read.2 == false
                && read.3 == IndexPath.lkIndexPath(item: 3, section: 4)
                && read.4 == AnyHashable("section")
                && read.5 == AnyHashable("item")
        })
    }

    func testHostingCellReuseUpdatesRenderedItemID() {
        let cell = LKHostingCollectionViewCell(frame: .zero)
        let first = LKItemModel(id: "first") {
            AnyView(Text("First"))
        }
        let second = LKItemModel(id: "second") {
            AnyView(Text("Second"))
        }

        cell.render(item: first)
        cell.render(item: second)

        XCTAssertEqual(cell.renderedItemID, AnyHashable("second"))
        XCTAssertNotNil(cell.contentConfiguration)
    }

    func testHostingCellReuseUpdatesEnvironmentMetadataAndState() {
        let cell = LKHostingCollectionViewCell(frame: .zero)
        let first = LKItemModel(id: "first") {
            AnyView(Text("First"))
        }
        let second = LKItemModel(id: "second") {
            AnyView(Text("Second"))
        }

        cell.render(
            item: first,
            indexPath: IndexPath.lkIndexPath(item: 0, section: 0),
            sectionID: AnyHashable("old")
        )
        cell.isSelected = true
        cell.isHighlighted = true
        cell.setNeedsUpdateConfiguration()
        cell.updateConfiguration(using: cell.configurationState)

        cell.isSelected = false
        cell.isHighlighted = false
        cell.render(
            item: second,
            indexPath: IndexPath.lkIndexPath(item: 1, section: 2),
            sectionID: AnyHashable("new")
        )

        XCTAssertEqual(cell.renderedItemID, AnyHashable("second"))
        XCTAssertEqual(cell.renderedIndexPath, IndexPath.lkIndexPath(item: 1, section: 2))
        XCTAssertEqual(cell.renderedSectionID, AnyHashable("new"))
        XCTAssertEqual(cell.renderedState, .inactive)
    }

    func testHostingSupplementaryReuseReplacesHostedContentView() {
        let supplementaryView = LKHostingSupplementaryView(frame: .zero)
        let first = LKSupplementaryModel(id: "first", kind: .header) {
            AnyView(Text("First"))
        }
        let second = LKSupplementaryModel(id: "second", kind: .header) {
            AnyView(Text("Second"))
        }

        supplementaryView.render(supplementary: first)
        let firstHostedContentView = supplementaryView.hostedContentView
        supplementaryView.render(supplementary: second)

        XCTAssertEqual(supplementaryView.renderedSupplementaryID, AnyHashable("second"))
        XCTAssertNotNil(supplementaryView.hostedContentView)
        XCTAssertFalse(supplementaryView.hostedContentView === firstHostedContentView)
        XCTAssertNil(firstHostedContentView?.superview)
    }

    func testAdapterStoresCellAndSupplementarySizeCallbacks() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        let item = LKItemModel(id: "item", contentToken: "row-v1")
        let header = LKSupplementaryModel(id: "header", kind: .header, contentToken: "header-v1")
        let sectionID = AnyHashable("section")
        let itemSize = CGSize(width: 320, height: 44)
        let supplementarySize = CGSize(width: 320, height: 28)

        adapter.recordItemSize(itemSize, item: item, sectionID: sectionID)
        adapter.recordSupplementarySize(
            supplementarySize,
            kind: UICollectionView.elementKindSectionHeader,
            supplementary: header,
            sectionID: sectionID
        )

        XCTAssertEqual(
            adapter.itemSizeStorage[
                LKItemSizeKey(
                    sectionID: sectionID,
                    itemID: AnyHashable("item"),
                    contentToken: AnyHashable("row-v1")
                )
            ],
            itemSize
        )
        XCTAssertEqual(
            adapter.supplementarySizeStorage[
                LKSupplementarySizeKey(
                    kind: UICollectionView.elementKindSectionHeader,
                    sectionID: sectionID,
                    supplementaryID: AnyHashable("header"),
                    contentToken: AnyHashable("header-v1")
                )
            ],
            supplementarySize
        )
    }

    func testHostingViewsInvokeSizeChangeCallbacks() {
        let indexPath = IndexPath.lkIndexPath(item: 0, section: 0)
        let cell = LKHostingCollectionViewCell(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        let supplementaryView = LKHostingSupplementaryView(frame: CGRect(x: 0, y: 0, width: 320, height: 28))
        let item = LKItemModel(id: "item") {
            AnyView(Text("Row"))
        }
        let header = LKSupplementaryModel(id: "header", kind: .header) {
            AnyView(Text("Header"))
        }
        var itemSize: CGSize?
        var supplementarySize: CGSize?

        cell.render(item: item) { size in
            itemSize = size
        }
        supplementaryView.render(supplementary: header) { size in
            supplementarySize = size
        }

        _ = cell.preferredLayoutAttributesFitting(UICollectionViewLayoutAttributes(forCellWith: indexPath))
        _ = supplementaryView.preferredLayoutAttributesFitting(
            UICollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                with: indexPath
            )
        )

        XCTAssertNotNil(itemSize)
        XCTAssertNotNil(supplementarySize)
    }

    func testDynamicHeightRowRecordsPreferredFittingSize() {
        let indexPath = IndexPath.lkIndexPath(item: 0, section: 0)
        let cell = LKHostingCollectionViewCell(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        let item = LKItemModel(id: "dynamic") {
            AnyView(
                Text("A dynamic height row that should be measured through preferred fitting.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            )
        }
        var measuredSize: CGSize?

        cell.render(item: item) { size in
            measuredSize = size
        }
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.size = CGSize(width: 320, height: 44)
        let fittedAttributes = cell.preferredLayoutAttributesFitting(attributes)

        XCTAssertNotNil(measuredSize)
        XCTAssertGreaterThan(fittedAttributes.size.height, 0)
    }

    func testLargeDataReloadApplyPerformance() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        let model = LKListModel(
            sections: [
                LKSectionModel(
                    id: "large",
                    items: (0..<2_000).map { LKItemModel(id: $0) }
                ),
            ]
        )

        measure(metrics: [XCTClockMetric()]) {
            adapter.apply(model)
        }
    }

    func testAdapterActsAsPrefetchDataSourceAndRoutesLatestContexts() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        var events = LKListEvents()
        var prefetchedContexts = [LKAnyItemContext]()
        var cancelledContexts = [LKAnyItemContext]()
        let model = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "one", base: "first"),
                    LKItemModel(id: "two", base: "second"),
                ]),
            ]
        )

        events.didPrefetch = { contexts in
            prefetchedContexts = contexts
        }
        events.didCancelPrefetch = { contexts in
            cancelledContexts = contexts
        }

        adapter.apply(model, listEvents: events)
        XCTAssertTrue(collectionView.prefetchDataSource === adapter)

        adapter.collectionView(
            collectionView,
            prefetchItemsAt: [
                IndexPath.lkIndexPath(item: 0, section: 0),
                IndexPath.lkIndexPath(item: 99, section: 0),
                IndexPath.lkIndexPath(item: 1, section: 0),
            ]
        )
        adapter.collectionView(
            collectionView,
            cancelPrefetchingForItemsAt: [
                IndexPath.lkIndexPath(item: 1, section: 0),
                IndexPath.lkIndexPath(item: 0, section: 99),
            ]
        )

        XCTAssertEqual(prefetchedContexts.map(\.id), [AnyHashable("one"), AnyHashable("two")])
        XCTAssertEqual(prefetchedContexts.map(\.sectionID), [AnyHashable("section"), AnyHashable("section")])
        XCTAssertEqual(prefetchedContexts.compactMap { $0.item as? String }, ["first", "second"])
        XCTAssertEqual(cancelledContexts.map(\.id), [AnyHashable("two")])
        XCTAssertEqual(adapter.prefetchedItemIDs, [AnyHashable("one")])
    }

    func testPrefetchCachePrunesRemovedItemsAfterApply() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        let original = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "one"),
                    LKItemModel(id: "two"),
                ]),
            ]
        )
        let updated = LKListModel(
            sections: [
                LKSectionModel(id: "section", items: [
                    LKItemModel(id: "two"),
                ]),
            ]
        )

        adapter.apply(original)
        adapter.collectionView(
            collectionView,
            prefetchItemsAt: [
                IndexPath.lkIndexPath(item: 0, section: 0),
                IndexPath.lkIndexPath(item: 1, section: 0),
            ]
        )
        adapter.apply(updated)

        XCTAssertEqual(adapter.prefetchedItemIDs, [AnyHashable("two")])
    }

    func testAdvancedDelegateCallbacksRouteListHandlersWithContext() {
        let collectionView = makeCollectionView()
        let window = makeVisibleWindow(for: collectionView)
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        let indexPath = IndexPath.lkIndexPath(item: 0, section: 0)
        let menuConfiguration = UIContextMenuConfiguration(identifier: "menu" as NSString)
        let highlightPreview = UITargetedPreview(view: collectionView)
        let dismissPreview = UITargetedPreview(view: collectionView)
        let action = #selector(UIResponderStandardEditActions.copy(_:))
        var events = LKListEvents()
        var routedEvents = [String]()
        var contextMenuPoint: CGPoint?
        var primaryActionContext: LKAnyItemContext?
        _ = window

        events.uiContextMenuConfiguration = { context, point in
            routedEvents.append("contextMenu:\(context.id)")
            contextMenuPoint = point
            return menuConfiguration
        }
        events.uiPreviewForHighlightingContextMenu = { configuration in
            routedEvents.append("previewHighlight:\(configuration.identifier as? String ?? "")")
            return highlightPreview
        }
        events.uiPreviewForDismissingContextMenu = { configuration in
            routedEvents.append("previewDismiss:\(configuration.identifier as? String ?? "")")
            return dismissPreview
        }
        events.canPerformPrimaryAction = { context in
            routedEvents.append("canPrimary:\(context.id)")
            return false
        }
        events.didPerformPrimaryAction = { context in
            routedEvents.append("primary:\(context.id)")
            primaryActionContext = context
        }
        events.shouldBeginMultipleSelectionInteraction = { context in
            routedEvents.append("shouldMultiple:\(context.id)")
            return true
        }
        events.didBeginMultipleSelectionInteraction = { context in
            routedEvents.append("beginMultiple:\(context.id)")
        }
        events.didEndMultipleSelectionInteraction = {
            routedEvents.append("endMultiple")
        }
        events.canFocus = { context in
            routedEvents.append("canFocus:\(context.id)")
            return false
        }
        events.preferredFocusedItemID = AnyHashable("item")
        events.shouldShowEditMenu = { context in
            routedEvents.append("shouldMenu:\(context.id)")
            return true
        }
        events.canPerformMenuAction = { context, receivedAction, sender in
            routedEvents.append("canMenu:\(context.id):\(receivedAction == action):\(sender as? String ?? "")")
            return true
        }
        events.performMenuAction = { context, receivedAction, sender in
            routedEvents.append("performMenu:\(context.id):\(receivedAction == action):\(sender as? String ?? "")")
        }

        adapter.apply(makeModel(itemID: "item"), listEvents: events)

        XCTAssertTrue(
            adapter.collectionView(
                collectionView,
                contextMenuConfigurationForItemAt: indexPath,
                point: CGPoint(x: 4, y: 5)
            ) === menuConfiguration
        )
        XCTAssertTrue(
            adapter.collectionView(
                collectionView,
                previewForHighlightingContextMenuWithConfiguration: menuConfiguration
            ) === highlightPreview
        )
        XCTAssertTrue(
            adapter.collectionView(
                collectionView,
                previewForDismissingContextMenuWithConfiguration: menuConfiguration
            ) === dismissPreview
        )
        XCTAssertFalse(adapter.collectionView(collectionView, canPerformPrimaryActionForItemAt: indexPath))
        adapter.collectionView(collectionView, performPrimaryActionForItemAt: indexPath)
        XCTAssertTrue(
            adapter.collectionView(
                collectionView,
                shouldBeginMultipleSelectionInteractionAt: indexPath
            )
        )
        adapter.collectionView(collectionView, didBeginMultipleSelectionInteractionAt: indexPath)
        adapter.collectionViewDidEndMultipleSelectionInteraction(collectionView)
        XCTAssertFalse(adapter.collectionView(collectionView, canFocusItemAt: indexPath))
        XCTAssertEqual(adapter.indexPathForPreferredFocusedView(in: collectionView), indexPath)
        XCTAssertTrue(adapter.collectionView(collectionView, shouldShowMenuForItemAt: indexPath))
        XCTAssertTrue(
            adapter.collectionView(
                collectionView,
                canPerformAction: action,
                forItemAt: indexPath,
                withSender: "sender"
            )
        )
        adapter.collectionView(
            collectionView,
            performAction: action,
            forItemAt: indexPath,
            withSender: "sender"
        )

        XCTAssertEqual(contextMenuPoint, CGPoint(x: 4, y: 5))
        XCTAssertEqual(primaryActionContext?.id, AnyHashable("item"))
        XCTAssertEqual(routedEvents, [
            "contextMenu:item",
            "previewHighlight:menu",
            "previewDismiss:menu",
            "canPrimary:item",
            "primary:item",
            "shouldMultiple:item",
            "beginMultiple:item",
            "endMultiple",
            "canFocus:item",
            "shouldMenu:item",
            "canMenu:item:true:sender",
            "performMenu:item:true:sender",
        ])
    }

    func testSwipeActionsRouteByEdgeAndHandlerPriority() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        let indexPath = IndexPath.lkIndexPath(item: 0, section: 0)
        var routedEvents = [String]()
        var listEvents = LKListEvents()
        var sectionEvents = LKSectionEvents()
        var rowEvents = LKRowEvents()

        listEvents.leadingSwipeActions = { context in
            routedEvents.append("list-leading:\(context.id)")
            return LKSwipeActions(
                actions: [
                    LKSwipeAction(title: "List Leading") { _, completion in
                        completion(true)
                    },
                ],
                allowsFullSwipe: true
            )
        }
        listEvents.trailingSwipeActions = { context in
            routedEvents.append("list-trailing:\(context.id)")
            return LKSwipeActions(
                actions: [
                    LKSwipeAction(title: "List Trailing") { _, completion in
                        completion(true)
                    },
                ],
                allowsFullSwipe: true
            )
        }
        sectionEvents.trailingSwipeActions = { context in
            routedEvents.append("section-trailing:\(context.id)")
            return LKSwipeActions(
                actions: [
                    LKSwipeAction(title: "Section Trailing") { _, completion in
                        completion(true)
                    },
                ],
                allowsFullSwipe: true
            )
        }
        rowEvents.trailingSwipeActions = { context in
            routedEvents.append("row-trailing:\(context.id)")
            return LKSwipeActions(
                actions: [
                    LKSwipeAction(
                        style: .destructive,
                        title: "Delete",
                        backgroundColor: .systemRed
                    ) { _, completion in
                        completion(true)
                    },
                ],
                allowsFullSwipe: false
            )
        }

        var item = LKItemModel(id: "item")
        item.events = rowEvents
        var section = LKSectionModel(id: "section", items: [item])
        section.events = sectionEvents

        adapter.apply(LKListModel(sections: [section]), listEvents: listEvents)

        let leadingConfiguration = adapter.collectionView(
            collectionView,
            leadingSwipeActionsConfigurationForItemAt: indexPath
        )
        let trailingConfiguration = adapter.collectionView(
            collectionView,
            trailingSwipeActionsConfigurationForItemAt: indexPath
        )

        XCTAssertEqual(leadingConfiguration?.actions.map(\.title), ["List Leading"])
        XCTAssertTrue(leadingConfiguration?.performsFirstActionWithFullSwipe == true)
        XCTAssertEqual(trailingConfiguration?.actions.map(\.title), ["Delete"])
        XCTAssertFalse(trailingConfiguration?.performsFirstActionWithFullSwipe ?? true)
        XCTAssertEqual(trailingConfiguration?.actions.first?.style, .destructive)
        XCTAssertEqual(trailingConfiguration?.actions.first?.backgroundColor, .systemRed)
        XCTAssertEqual(routedEvents, [
            "list-leading:item",
            "row-trailing:item",
        ])
    }

    private func makeCollectionView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.headerReferenceSize = CGSize(width: 320, height: 44)
        layout.footerReferenceSize = CGSize(width: 320, height: 44)
        return UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480),
            collectionViewLayout: layout
        )
    }

    private func makeVisibleWindow(for collectionView: UICollectionView) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let viewController = UIViewController()
        viewController.view = collectionView
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        collectionView.layoutIfNeeded()
        return window
    }

    private func makeModel(
        sectionID: String = "section",
        itemID: String = "item"
    ) -> LKListModel {
        LKListModel(
            sections: [
                LKSectionModel(
                    id: sectionID,
                    items: [
                        LKItemModel(id: itemID),
                    ],
                    header: LKSupplementaryModel(id: "\(sectionID)-header", kind: .header),
                    footer: LKSupplementaryModel(id: "\(sectionID)-footer", kind: .footer)
                ),
            ]
        )
    }

    private func applyDiffable(
        _ model: LKListModel,
        to adapter: LKCollectionViewAdapter,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let didApply = expectation(description: "applies diffable snapshot")
        adapter.diffableApplyCompletionHandler = {
            didApply.fulfill()
        }
        adapter.apply(model)
        await fulfillment(of: [didApply], timeout: 2.0)
        adapter.diffableApplyCompletionHandler = nil
    }
}
#endif
