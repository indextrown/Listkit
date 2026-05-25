import SwiftUI
import ListKit

struct DifferenceKitEngineExample: View {
    var body: some View {
        LKList(ListKitExampleData.messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .updateEngine(.differenceKit)
    }
}

#Preview {
    DifferenceKitEngineExample()
}
