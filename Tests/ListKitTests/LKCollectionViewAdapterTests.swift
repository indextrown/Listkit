#if canImport(UIKit) && canImport(SwiftUI)
import XCTest
import UIKit
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

    private func makeCollectionView() -> UICollectionView {
        UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
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
