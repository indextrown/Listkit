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

    func testSectionHorizontalLayoutCreatesDisplayableCollectionViewLayout() {
        var section = makeModel().sections[0]
        section.layout = .horizontal(width: 300)
        section.scrollAxis = .horizontal
        section.orthogonalScrollingBehavior = .groupPagingCentered
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

    func testCustomLayoutPinnedHeaderAppliesToProviderHeaderBoundaryItem() {
        var customHeader: NSCollectionLayoutBoundarySupplementaryItem?
        var customFooter: NSCollectionLayoutBoundarySupplementaryItem?
        var section = makeModel().sections[0]
        section.pinsHeader = true
        section.layout = .custom { _, _ in
            let layoutSection = Self.makeSingleItemLayoutSection()
            let header = Self.makeBoundaryItem(
                kind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            let footer = Self.makeBoundaryItem(
                kind: UICollectionView.elementKindSectionFooter,
                alignment: .bottom
            )
            footer.pinToVisibleBounds = true
            layoutSection.boundarySupplementaryItems = [header, footer]
            customHeader = header
            customFooter = footer
            return layoutSection
        }
        let model = LKListModel(sections: [section])
        let fixture = makeCollectionView(model: model, style: .plain)

        fixture.collectionView.layoutIfNeeded()

        XCTAssertEqual(customHeader?.pinToVisibleBounds, true)
        XCTAssertEqual(customHeader?.contentInsets.top, 1)
        XCTAssertEqual(customHeader?.contentInsets.leading, 2)
        XCTAssertEqual(customHeader?.contentInsets.bottom, 3)
        XCTAssertEqual(customHeader?.contentInsets.trailing, 4)
        XCTAssertEqual(customFooter?.pinToVisibleBounds, true)
    }

    func testCustomLayoutUnpinnedHeaderAppliesToProviderHeaderBoundaryItem() {
        var customHeader: NSCollectionLayoutBoundarySupplementaryItem?
        var customFooter: NSCollectionLayoutBoundarySupplementaryItem?
        var section = makeModel().sections[0]
        section.pinsHeader = false
        section.layout = .custom { _, _ in
            let layoutSection = Self.makeSingleItemLayoutSection()
            let header = Self.makeBoundaryItem(
                kind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            let footer = Self.makeBoundaryItem(
                kind: UICollectionView.elementKindSectionFooter,
                alignment: .bottom
            )
            header.pinToVisibleBounds = true
            footer.pinToVisibleBounds = true
            layoutSection.boundarySupplementaryItems = [header, footer]
            customHeader = header
            customFooter = footer
            return layoutSection
        }
        let model = LKListModel(sections: [section])
        let fixture = makeCollectionView(model: model, style: .plain)

        fixture.collectionView.layoutIfNeeded()

        XCTAssertEqual(customHeader?.pinToVisibleBounds, false)
        XCTAssertEqual(customHeader?.contentInsets.top, 1)
        XCTAssertEqual(customHeader?.contentInsets.leading, 2)
        XCTAssertEqual(customHeader?.contentInsets.bottom, 3)
        XCTAssertEqual(customHeader?.contentInsets.trailing, 4)
        XCTAssertEqual(customFooter?.pinToVisibleBounds, true)
    }

    func testPinnedHeaderListAndGridLayoutsCreateDisplayableCollectionViewLayouts() {
        for layout in [LKSectionLayout.list(appearance: .plain), .grid(columns: 2, spacing: 8)] {
            var section = makeModel().sections[0]
            section.layout = layout
            section.pinsHeader = true
            let model = LKListModel(sections: [section])
            let fixture = makeCollectionView(model: model, style: .plain)

            fixture.collectionView.layoutIfNeeded()

            XCTAssertTrue(fixture.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
        }
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

    func testLayoutSignatureChangesWhenSectionScrollAxisChanges() {
        let originalModel = makeModel()
        var changedSection = originalModel.sections[0]
        changedSection.scrollAxis = .horizontal
        let changedModel = LKListModel(sections: [changedSection])

        XCTAssertNotEqual(
            LKCollectionLayoutProvider.signature(model: originalModel, defaultStyle: .plain),
            LKCollectionLayoutProvider.signature(model: changedModel, defaultStyle: .plain)
        )
    }

    func testLayoutSignatureChangesWhenSectionOrthogonalScrollingBehaviorChanges() {
        let originalModel = makeModel()
        var changedSection = originalModel.sections[0]
        changedSection.scrollAxis = .horizontal
        changedSection.orthogonalScrollingBehavior = .groupPagingCentered
        let changedModel = LKListModel(sections: [changedSection])

        XCTAssertNotEqual(
            LKCollectionLayoutProvider.signature(model: originalModel, defaultStyle: .plain),
            LKCollectionLayoutProvider.signature(model: changedModel, defaultStyle: .plain)
        )
    }

    func testHorizontalCustomLayoutAppliesOrthogonalScrollingBehavior() {
        var customSection: NSCollectionLayoutSection?
        var section = makeModel().sections[0]
        section.scrollAxis = .horizontal
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.layout = .custom { _, _ in
            let layoutSection = Self.makeSingleItemLayoutSection()
            customSection = layoutSection
            return layoutSection
        }
        let model = LKListModel(sections: [section])
        let fixture = makeCollectionView(model: model, style: .plain)

        fixture.collectionView.layoutIfNeeded()

        XCTAssertEqual(customSection?.orthogonalScrollingBehavior, .groupPagingCentered)
    }

    func testLayoutSignatureChangesWhenSectionItemSpacingChanges() {
        let originalModel = makeModel()
        var changedSection = originalModel.sections[0]
        changedSection.itemSpacing = 12
        let changedModel = LKListModel(sections: [changedSection])

        XCTAssertNotEqual(
            LKCollectionLayoutProvider.signature(model: originalModel, defaultStyle: .plain),
            LKCollectionLayoutProvider.signature(model: changedModel, defaultStyle: .plain)
        )
    }

    func testLayoutSignatureChangesWhenSectionHeaderPinningChanges() {
        let originalModel = makeModel()
        var changedSection = originalModel.sections[0]
        changedSection.pinsHeader = true
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

    private static func makeSingleItemLayoutSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(44)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(44)
        )
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: groupSize,
            subitems: [item]
        )
        return NSCollectionLayoutSection(group: group)
    }

    private static func makeBoundaryItem(
        kind: String,
        alignment: NSRectAlignment
    ) -> NSCollectionLayoutBoundarySupplementaryItem {
        let size = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .absolute(44)
        )
        let item = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: size,
            elementKind: kind,
            alignment: alignment
        )
        item.contentInsets = NSDirectionalEdgeInsets(
            top: 1,
            leading: 2,
            bottom: 3,
            trailing: 4
        )
        return item
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
