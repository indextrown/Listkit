import Foundation
import XCTest
@testable import ListKit

final class LKListModelTests: XCTestCase {
    func testSectionLookupReturnsSectionByIndex() {
        let model = LKListModel(
            sections: [
                LKSectionModel(id: "first"),
                LKSectionModel(id: "second"),
            ]
        )

        XCTAssertEqual(model.section(at: 0)?.id, AnyHashable("first"))
        XCTAssertEqual(model.section(at: 1)?.id, AnyHashable("second"))
        XCTAssertNil(model.section(at: 2))
    }

    func testItemLookupUsesSectionAndItemIndexes() {
        let firstItem = LKItemModel(id: "a")
        let secondItem = LKItemModel(id: "b")
        let model = LKListModel(
            sections: [
                LKSectionModel(id: "first", items: [firstItem]),
                LKSectionModel(id: "second", items: [secondItem]),
            ]
        )

        XCTAssertEqual(
            model.item(at: .lkIndexPath(item: 0, section: 1)),
            secondItem
        )
        XCTAssertNil(model.item(at: .lkIndexPath(item: 4, section: 1)))
        XCTAssertNil(model.item(at: .lkIndexPath(item: 0, section: 4)))
    }

    func testSupplementaryLookupReturnsHeaderFooterAndCustomSupplementary() {
        let header = LKSupplementaryModel(id: "header", kind: .header)
        let footer = LKSupplementaryModel(id: "footer", kind: .footer)
        let badge = LKSupplementaryModel(id: "badge", kind: .custom("badge"))
        let model = LKListModel(
            sections: [
                LKSectionModel(
                    id: "section",
                    header: header,
                    footer: footer,
                    supplementaries: [badge]
                ),
            ]
        )

        let indexPath = IndexPath.lkIndexPath(item: 0, section: 0)

        XCTAssertEqual(model.supplementary(kind: .header, at: indexPath), header)
        XCTAssertEqual(model.supplementary(kind: .footer, at: indexPath), footer)
        XCTAssertEqual(model.supplementary(kind: .custom("badge"), at: indexPath), badge)
        XCTAssertNil(model.supplementary(kind: .custom("missing"), at: indexPath))
    }

    func testValidationWarningsReportDuplicateSectionIDs() {
        let model = LKListModel(
            sections: [
                LKSectionModel(id: "section"),
                LKSectionModel(id: "section"),
            ]
        )

        XCTAssertEqual(model.validationWarnings(), [.duplicateSectionID("section")])
    }

    func testValidationWarningsReportDuplicateItemIDsWithinSection() {
        let model = LKListModel(
            sections: [
                LKSectionModel(
                    id: "section",
                    items: [
                        LKItemModel(id: "item"),
                        LKItemModel(id: "item"),
                    ]
                ),
            ]
        )

        XCTAssertEqual(
            model.validationWarnings(),
            [.duplicateItemID(sectionID: "section", itemID: "item")]
        )
    }

    func testIdentityAndContentEqualityAreSeparateInputs() {
        let original = LKItemModel(id: "item", contentToken: "old")
        let changedContent = LKItemModel(id: "item", contentToken: "new")
        let changedIdentity = LKItemModel(id: "other", contentToken: "old")

        XCTAssertEqual(original.id, changedContent.id)
        XCTAssertNotEqual(original, changedContent)
        XCTAssertNotEqual(original.id, changedIdentity.id)
    }
}
