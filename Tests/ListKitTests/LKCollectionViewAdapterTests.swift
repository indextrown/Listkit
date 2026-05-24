#if canImport(UIKit) && canImport(SwiftUI)
import XCTest
import UIKit
import SwiftUI
@testable import ListKit

@MainActor
final class LKCollectionViewAdapterTests: XCTestCase {
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

    func testQueuedUpdateKeepsLastUpdateWhileApplyIsRunning() {
        let collectionView = makeCollectionView()
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
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
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
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
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
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
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
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

    func testReloadDataRestoresSelectionByItemIdentity() {
        let collectionView = makeCollectionView()
        collectionView.allowsSelection = true
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
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
        let adapter = LKCollectionViewAdapter(collectionView: collectionView)
        let model = makeModel()
        var didCallFocusHook = false

        adapter.focusRestorationHandler = {
            didCallFocusHook = true
        }

        adapter.apply(model)

        XCTAssertTrue(didCallFocusHook)
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
        let adapter = LKCollectionViewAdapter(
            collectionView: collectionView,
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
        XCTAssertEqual(adapter.currentModel.sections.first?.items.count, 800)
        _ = window
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
        let header = LKSupplementaryModel(id: "header", kind: .header) {
            AnyView(Text("Header"))
        }
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
        let indexPath = IndexPath.lkIndexPath(item: 0, section: 0)
        let itemSize = CGSize(width: 320, height: 44)
        let supplementarySize = CGSize(width: 320, height: 28)

        adapter.recordItemSize(itemSize, at: indexPath)
        adapter.recordSupplementarySize(
            supplementarySize,
            kind: UICollectionView.elementKindSectionHeader,
            at: indexPath
        )

        XCTAssertEqual(adapter.itemSizeStorage[indexPath], itemSize)
        XCTAssertEqual(
            adapter.supplementarySizeStorage[
                LKSupplementarySizeKey(kind: UICollectionView.elementKindSectionHeader, indexPath: indexPath)
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
