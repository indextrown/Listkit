import SwiftUI
import ListKit

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

#Preview {
    ContextMenuExample()
}
