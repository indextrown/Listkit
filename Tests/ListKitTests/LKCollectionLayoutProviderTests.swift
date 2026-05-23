#if canImport(UIKit) && canImport(SwiftUI)
import XCTest
import UIKit
@testable import ListKit

@MainActor
final class LKCollectionLayoutProviderTests: XCTestCase {
    func testListStylesCreateDisplayableCollectionViewLayouts() {
        for style in [LKListStyle.plain, .grouped, .insetGrouped] {
            let fixture = makeCollectionView(
                model: makeModel(),
                style: style
            )
            fixture.collectionView.layoutIfNeeded()

            XCTAssertTrue(fixture.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
            XCTAssertEqual(fixture.adapter.currentModel.sections.count, 1)
        }
    }

    func testSectionGridLayoutCreatesDisplayableCollectionViewLayout() {
        var section = makeModel().sections[0]
        section.layout = .grid(columns: 2, spacing: 8)
        let model = LKListModel(sections: [section])
        let fixture = makeCollectionView(model: model, style: .plain)

        fixture.collectionView.layoutIfNeeded()

        XCTAssertTrue(fixture.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
    }

    func testSectionCustomLayoutProviderIsUsed() {
        var didCallProvider = false
        var section = makeModel().sections[0]
        section.layout = .custom { _, environment in
            didCallProvider = true
            var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
            configuration.headerMode = .supplementary
            return NSCollectionLayoutSection.list(
                using: configuration,
                layoutEnvironment: environment
            )
        }
        let model = LKListModel(sections: [section])
        let fixture = makeCollectionView(model: model, style: .plain)

        fixture.collectionView.layoutIfNeeded()

        XCTAssertTrue(didCallProvider)
    }

    func testLayoutSignatureChangesWhenSectionLayoutChanges() {
        let originalModel = makeModel()
        var changedSection = originalModel.sections[0]
        changedSection.layout = .grid(columns: 3, spacing: 12)
        let changedModel = LKListModel(sections: [changedSection])

        XCTAssertNotEqual(
            LKCollectionLayoutProvider.signature(model: originalModel, defaultStyle: .plain),
            LKCollectionLayoutProvider.signature(model: changedModel, defaultStyle: .plain)
        )
    }

    private func makeCollectionView(
        model: LKListModel,
        style: LKListStyle
    ) -> (collectionView: UICollectionView, adapter: LKCollectionViewAdapter) {
        let collectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480),
            collectionViewLayout: LKCollectionLayoutProvider.makeLayout(
                model: model,
                defaultStyle: style
            )
        )
        let adapter = LKCollectionViewAdapter(collectionView: collectionView, model: model)
        collectionView.reloadData()
        return (collectionView, adapter)
    }

    private func makeModel() -> LKListModel {
        LKListModel(
            sections: [
                LKSectionModel(
                    id: "section",
                    items: [
                        LKItemModel(id: "first"),
                        LKItemModel(id: "second"),
                    ],
                    header: LKSupplementaryModel(id: "header", kind: .header),
                    footer: LKSupplementaryModel(id: "footer", kind: .footer)
                ),
            ]
        )
    }
}
#endif
