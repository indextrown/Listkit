import SwiftUI
import ListKit

struct DiffableEngineExample: View {
    var body: some View {
        LKList(ListKitExampleData.messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .updateEngine(.diffableDataSource)
    }
}

#Preview {
    DiffableEngineExample()
}
