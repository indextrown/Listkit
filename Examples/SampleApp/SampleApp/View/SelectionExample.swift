import SwiftUI
import ListKit

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

#Preview {
    SelectionExample()
}
