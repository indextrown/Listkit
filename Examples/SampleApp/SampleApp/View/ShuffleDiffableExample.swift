import SwiftUI
import ListKit

struct ShuffleDiffableExample: View {
    @State private var messages = ListKitExampleData.shuffleMessages

    var body: some View {
        LKList(messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .updateEngine(.diffableDataSource)
        .navigationTitle("Shuffle Diffable")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    messages.shuffle()
                } label: {
                    Image(systemName: "shuffle")
                }
                .accessibilityLabel("Shuffle")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ShuffleDiffableExample()
    }
}
