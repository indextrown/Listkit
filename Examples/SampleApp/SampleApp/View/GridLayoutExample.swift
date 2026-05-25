import SwiftUI
import ListKit

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

#Preview {
    GridLayoutExample()
}
