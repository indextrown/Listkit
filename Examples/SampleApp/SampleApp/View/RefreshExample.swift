import SwiftUI
import ListKit

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

#Preview {
    RefreshExample()
}
