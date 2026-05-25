//
//  ContentView.swift
//  SampleApp
//
//  Created by 김동현 on 5/25/26.
//

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

enum SampleExample: String, CaseIterable, Identifiable, Hashable {
    case basic
    case sectioned
    case selection
    case refresh
    case search
    case displayLifecycle
    case contextMenu
    case grid
    case diffable
    case differenceKit
    case largeData

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic:
            "Basic List"
        case .sectioned:
            "Sections"
        case .selection:
            "Selection"
        case .refresh:
            "Refresh"
        case .search:
            "Search"
        case .displayLifecycle:
            "Display Lifecycle"
        case .contextMenu:
            "Context Menu"
        case .grid:
            "Grid Layout"
        case .diffable:
            "Diffable Engine"
        case .differenceKit:
            "DifferenceKit Engine"
        case .largeData:
            "Large Data"
        }
    }

    var subtitle: String {
        switch self {
        case .basic:
            "Plain list, selection callback, display lifecycle, refresh, diffable updates."
        case .sectioned:
            "Multiple sections with headers and footers."
        case .selection:
            "Multiple selection with a should-select rule."
        case .refresh:
            "Async refresh control integration."
        case .search:
            "SwiftUI searchable composed with LKList."
        case .displayLifecycle:
            "willDisplay and didEndDisplaying hooks."
        case .contextMenu:
            "SwiftUI row context menu."
        case .grid:
            "Section-level grid layout."
        case .diffable:
            "UICollectionViewDiffableDataSource update engine."
        case .differenceKit:
            "DifferenceKit staged update engine."
        case .largeData:
            "1,000 rows with diffable updates."
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List(SampleExample.allCases) { example in
                NavigationLink(value: example) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(example.title)
                            .font(.headline)
                        Text(example.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("ListKit Examples")
            .navigationDestination(for: SampleExample.self) { example in
                destination(for: example)
                    .navigationTitle(example.title)
            }
        }
    }

    @ViewBuilder
    private func destination(for example: SampleExample) -> some View {
        switch example {
        case .basic:
            BasicListExample()
        case .sectioned:
            SectionedHeaderFooterExample()
        case .selection:
            SelectionExample()
        case .refresh:
            RefreshExample()
        case .search:
            SearchExample()
        case .displayLifecycle:
            DisplayLifecycleExample()
        case .contextMenu:
            ContextMenuExample()
        case .grid:
            GridLayoutExample()
        case .diffable:
            DiffableEngineExample()
        case .differenceKit:
            DifferenceKitEngineExample()
        case .largeData:
            LargeDataExample()
        }
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

    var body: some View {
        LKList(messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .refreshable {
            await Task.yield()
            messages = ListKitExampleData.messages
        }
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
        LKList(filteredMessages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .searchable(text: $query)
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
            ContentView()
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
