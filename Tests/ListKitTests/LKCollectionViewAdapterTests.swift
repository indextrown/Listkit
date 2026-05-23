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
}
#endif
