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

struct ExampleNavigationRow<Destination: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
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
        ExampleMessage(id: 4, title: "Archived note", subtitle: "Selection is disabled for this row", isArchived: true),
    ]

    static let pinned = [
        ExampleMessage(id: 101, title: "Pinned: Launch checklist", subtitle: "Three items remaining"),
    ]

    static let largeMessages = (0..<1_000).map {
        ExampleMessage(id: $0, title: "Message \($0)", subtitle: "Large data row")
    }

    static let shuffleMessages = (0..<20).map {
        ExampleMessage(id: $0, title: "Shuffle row \($0)", subtitle: "Tap the toolbar button to reorder")
    }

    static let prefetchMessages = (0..<120).map {
        ExampleMessage(id: $0, title: "Prefetch row \($0)", subtitle: "Scroll to trigger prefetch callbacks")
    }
}
