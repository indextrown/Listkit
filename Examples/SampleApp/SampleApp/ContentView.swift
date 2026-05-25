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
    static func resume(for id: AnyHashable) {
        print("resume")
    }
    static func pause(for id: AnyHashable) {
        print("pause")
    }
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

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    BasicListExample()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Basic List")
                            .font(.headline)
                        Text("Plain list, selection callback, display lifecycle, refresh, diffable updates.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    SectionedHeaderFooterExample()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sections")
                            .font(.headline)
                        Text("Multiple sections with headers and footers.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    SelectionExample()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selection")
                            .font(.headline)
                        Text("Multiple selection with a should-select rule.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    RefreshExample()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Refresh")
                            .font(.headline)
                        Text("Async refresh control integration.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    SearchExample()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Search")
                            .font(.headline)
                        Text("SwiftUI searchable composed with LKList.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    DisplayLifecycleExample()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Display Lifecycle")
                            .font(.headline)
                        Text("willDisplay and didEndDisplaying hooks.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    ContextMenuExample()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Context Menu")
                            .font(.headline)
                        Text("SwiftUI row context menu.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    GridLayoutExample()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Grid Layout")
                            .font(.headline)
                        Text("Section-level grid layout.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    DiffableEngineExample()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Diffable Engine")
                            .font(.headline)
                        Text("UICollectionViewDiffableDataSource update engine.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    DifferenceKitEngineExample()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DifferenceKit Engine")
                            .font(.headline)
                        Text("DifferenceKit staged update engine.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    LargeDataExample()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Large Data")
                            .font(.headline)
                        Text("1,000 rows with diffable updates.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("ListKit Examples")
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
