import SwiftUI
import ListKit

struct LargeDataExample: View {
    var body: some View {
        LKList(ListKitExampleData.largeMessages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .updateEngine(.diffableDataSource)
    }
}

#Preview {
    LargeDataExample()
}
