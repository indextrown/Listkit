#if canImport(SwiftUI)
import SwiftUI
import XCTest
@testable import ListKit

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
}
#endif
