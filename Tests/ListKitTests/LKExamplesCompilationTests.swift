#if canImport(SwiftUI)
import SwiftUI
import XCTest
@testable import ListKit
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class LKExamplesCompilationTests: XCTestCase {
    private struct ExampleMessage: Identifiable, Hashable {
        let id: Int
        let title: String
        let subtitle: String
        var isArchived = false
    }

    private struct ExampleMessageRow: View {
        let message: ExampleMessage

        var body: some View {
            VStack(alignment: .leading) {
                Text(message.title)
                Text(message.subtitle)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private struct ReadmeMessage: Identifiable, Hashable {
        let id: Int
        var title: String
        var subtitle: String
        var isArchived = false
    }

    private struct ReadmeMessageRow: View {
        let message: ReadmeMessage

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(message.title)
                    .font(.headline)
                Text(message.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }

    private enum ReadmeImagePipeline {
        static func resume(for id: AnyHashable) {}
        static func pause(for id: AnyHashable) {}
    }

    #if canImport(UIKit)
    private struct ReadmeInboxView: View {
        let messages: [ReadmeMessage]

        var body: some View {
            LKList(messages, id: \.id) { message in
                ReadmeMessageRow(message: message)
            }
            .listKitStyle(.plain)
            .onSelect { context in
                print("Selected", context.id)
            }
            .onWillDisplay { context in
                ReadmeImagePipeline.resume(for: context.id)
            }
            .onDidEndDisplaying { context in
                ReadmeImagePipeline.pause(for: context.id)
            }
            .refreshable {
                await reload()
            }
            .updateEngine(.diffableDataSource)
        }

        private func reload() async {}
    }
    #endif

    private let messages = [
        ExampleMessage(id: 1, title: "Design review", subtitle: "Confirm the new inbox layout"),
        ExampleMessage(id: 2, title: "Build finished", subtitle: "iOS simulator tests passed"),
        ExampleMessage(id: 3, title: "Archived note", subtitle: "Selection is disabled", isArchived: true),
    ]

    func testSingleSectionBasicExampleShape() {
        let list = LKList(messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }

        XCTAssertEqual(list.model.sections.count, 1)
        XCTAssertEqual(list.model.sections[0].items.map(\.id), [
            AnyHashable(1),
            AnyHashable(2),
            AnyHashable(3),
        ])
    }

    func testSectionedHeaderFooterExampleShape() {
        let allMessages = messages

        let list = LKList {
            LKSection(id: "pinned") {
                LKRow(allMessages[0], id: \.id) {
                    ExampleMessageRow(message: allMessages[0])
                }
            } header: {
                Text("Pinned")
            }

            LKSection(id: "all") {
                for message in allMessages {
                    LKRow(message, id: \.id) {
                        ExampleMessageRow(message: message)
                    }
                }
            } header: {
                Text("All")
            } footer: {
                Text("\(allMessages.count) messages")
            }
        }

        XCTAssertEqual(list.model.sections.map(\.id), [AnyHashable("pinned"), AnyHashable("all")])
        XCTAssertNotNil(list.model.sections[0].header)
        XCTAssertNotNil(list.model.sections[1].header)
        XCTAssertNotNil(list.model.sections[1].footer)
    }

    func testRefreshAndSearchExamplesCompose() {
        let refreshList = LKList(messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .refreshable {
            await Task.yield()
        }

        var query = ""
        let searchText = Binding<String>(
            get: { query },
            set: { query = $0 }
        )
        let searchList = LKList(messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .searchable(text: searchText)

        _ = refreshList
        _ = searchList
    }

    #if canImport(UIKit)
    func testReadmeQuickStartExampleCompiles() {
        let readmeMessages = messages.map {
            ReadmeMessage(id: $0.id, title: $0.title, subtitle: $0.subtitle)
        }

        _ = ReadmeInboxView(messages: readmeMessages)
    }

    func testSelectionDisplayContextMenuAndEngineExamplesStoreConfiguration() {
        var selectedIDs = Set<ExampleMessage.ID>()
        let selection = Binding<Set<ExampleMessage.ID>>(
            get: { selectedIDs },
            set: { selectedIDs = $0 }
        )

        let list = LKList(messages, id: \.id) { message in
            ExampleMessageRow(message: message)
                .contextMenu {
                    Button("Archive") {}
                }
        }
        .selection(selection)
        .selectionMode(.multiple)
        .onShouldSelect { context in
            guard let message = context.item as? ExampleMessage else { return true }
            return !message.isArchived
        }
        .onSelect { _ in }
        .onWillDisplay { _ in }
        .onDidEndDisplaying { _ in }
        .refreshable {
            await Task.yield()
        }
        .updateEngine(.diffableDataSource)

        XCTAssertEqual(list.selectionConfiguration.mode, .multiple)
        XCTAssertNotNil(list.events.shouldSelect)
        XCTAssertNotNil(list.events.didSelect)
        XCTAssertNotNil(list.events.willDisplay)
        XCTAssertNotNil(list.events.didEndDisplaying)
        XCTAssertNotNil(list.refreshConfiguration.action)
        XCTAssertEqual(list.updateEngine, .diffableDataSource)
    }

    func testGridDifferenceKitAndLargeDataExamplesStoreConfiguration() {
        let gridList = LKList {
            LKSection(id: "grid") {
                for message in messages {
                    LKRow(message, id: \.id) {
                        ExampleMessageRow(message: message)
                    }
                }
            }
            .sectionLayout(.grid(columns: 2, spacing: 8))
        }

        let differenceKitList = LKList(messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .updateEngine(.differenceKit)

        let largeMessages = (0..<1_000).map {
            ExampleMessage(id: $0, title: "Message \($0)", subtitle: "Large data row")
        }
        let largeDataList = LKList(largeMessages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .updateEngine(.diffableDataSource)

        XCTAssertEqual(gridList.model.sections[0].layout, .grid(columns: 2, spacing: 8))
        XCTAssertEqual(differenceKitList.updateEngine, .differenceKit)
        XCTAssertEqual(largeDataList.model.sections[0].items.count, 1_000)
        XCTAssertEqual(largeDataList.updateEngine, .diffableDataSource)
    }
    #endif
}
#endif
