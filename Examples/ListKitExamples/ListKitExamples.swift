#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import ListKit

struct ExampleMessage: Identifiable, Hashable {
    let id: Int
    var title: String
    var subtitle: String
    var isArchived = false
}

struct ExampleMessageRow: View {
    let message: ExampleMessage

    @Environment(\.listKitIsSelected) private var isSelected
    @Environment(\.listKitIsHighlighted) private var isHighlighted

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.25))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(message.title)
                    .font(.headline)
                Text(message.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .opacity(isHighlighted ? 0.7 : 1)
    }
}

enum ExampleImagePipeline {
    static func resume(for id: AnyHashable) {}
    static func pause(for id: AnyHashable) {}
}

enum ListKitExampleData {
    static let messages = [
        ExampleMessage(id: 1, title: "Design review", subtitle: "Confirm the new inbox layout"),
        ExampleMessage(id: 2, title: "Build finished", subtitle: "iOS simulator tests passed"),
        ExampleMessage(id: 3, title: "Archived note", subtitle: "Selection is disabled for this row", isArchived: true),
    ]

    static let pinned = [
        ExampleMessage(id: 101, title: "Pinned: Launch checklist", subtitle: "Three items remaining"),
    ]

    static let largeMessages = (0..<1_000).map {
        ExampleMessage(id: $0, title: "Message \($0)", subtitle: "Large data row")
    }
}

struct BasicListExample: View {
    var body: some View {
        LKList(ListKitExampleData.messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .listKitStyle(.plain)
        .onSelect { context in
            print("Selected", context.id)
        }
        .onWillDisplay { context in
            ExampleImagePipeline.resume(for: context.id)
        }
        .onDidEndDisplaying { context in
            ExampleImagePipeline.pause(for: context.id)
        }
        .refreshable {
            await Task.yield()
        }
        .updateEngine(.diffableDataSource)
    }
}

struct SectionedHeaderFooterExample: View {
    var body: some View {
        LKList {
            LKSection(id: "pinned") {
                for message in ListKitExampleData.pinned {
                    LKRow(message, id: \.id) {
                        ExampleMessageRow(message: message)
                    }
                }
            } header: {
                Text("Pinned")
            }

            LKSection(id: "all") {
                for message in ListKitExampleData.messages {
                    LKRow(message, id: \.id) {
                        ExampleMessageRow(message: message)
                    }
                }
            } header: {
                Text("All")
            } footer: {
                Text("\(ListKitExampleData.messages.count) messages")
            }
        }
        .listKitStyle(.insetGrouped)
    }
}

struct SelectionExample: View {
    @State private var selection = Set<ExampleMessage.ID>()

    var body: some View {
        LKList(ListKitExampleData.messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .selection($selection)
        .selectionMode(.multiple)
        .onShouldSelect { context in
            guard let message = context.item as? ExampleMessage else { return true }
            return !message.isArchived
        }
    }
}

struct RefreshExample: View {
    @State private var messages = ListKitExampleData.messages
    @State private var refreshCount = 0

    var body: some View {
        LKList(messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .listKitStyle(.plain)
        .refreshable {
            try? await Task.sleep(nanoseconds: 800_000_000)
            refreshCount += 1
            messages.insert(
                ExampleMessage(
                    id: 10_000 + refreshCount,
                    title: "Refreshed message \(refreshCount)",
                    subtitle: "Inserted by pull to refresh"
                ),
                at: 0
            )
        }
        .updateEngine(.diffableDataSource)
    }
}

struct SearchExample: View {
    @State private var query = ""

    private var filteredMessages: [ExampleMessage] {
        guard !query.isEmpty else { return ListKitExampleData.messages }
        return ListKitExampleData.messages.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            LKList(filteredMessages, id: \.id) { message in
                ExampleMessageRow(message: message)
            }
            .searchable(text: $query)
            .navigationTitle("Search")
        }
    }
}

struct DisplayLifecycleExample: View {
    var body: some View {
        LKList(ListKitExampleData.messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .onWillDisplay { context in
            ExampleImagePipeline.resume(for: context.id)
        }
        .onDidEndDisplaying { context in
            ExampleImagePipeline.pause(for: context.id)
        }
    }
}

struct ContextMenuExample: View {
    var body: some View {
        LKList(ListKitExampleData.messages, id: \.id) { message in
            ExampleMessageRow(message: message)
                .contextMenu {
                    Button("Archive") {
                        archive(message)
                    }
                }
        }
    }

    private func archive(_ message: ExampleMessage) {}
}

struct GridLayoutExample: View {
    var body: some View {
        LKList {
            LKSection(id: "grid") {
                for message in ListKitExampleData.messages {
                    LKRow(message, id: \.id) {
                        ExampleMessageRow(message: message)
                    }
                }
            }
            .sectionLayout(.grid(columns: 2, spacing: 8))
        }
    }
}

struct DiffableEngineExample: View {
    var body: some View {
        LKList(ListKitExampleData.messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .updateEngine(.diffableDataSource)
    }
}

struct DifferenceKitEngineExample: View {
    var body: some View {
        LKList(ListKitExampleData.messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .updateEngine(.differenceKit)
    }
}

struct LargeDataExample: View {
    var body: some View {
        LKList(ListKitExampleData.largeMessages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .updateEngine(.diffableDataSource)
    }
}

struct ListKitExamplesPreview: PreviewProvider {
    static var previews: some View {
        Group {
            BasicListExample()
            SectionedHeaderFooterExample()
            SelectionExample()
            RefreshExample()
            SearchExample()
            DisplayLifecycleExample()
            ContextMenuExample()
            GridLayoutExample()
            DiffableEngineExample()
            DifferenceKitEngineExample()
            LargeDataExample()
        }
    }
}
#endif
