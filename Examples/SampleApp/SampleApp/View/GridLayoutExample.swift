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
            } header: {
                Text("Vertical grid")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            .sectionLayout(.grid(columns: 2, spacing: 0))
            .itemSpacing(8)
            .pinnedHeader()
        }
    }
}

#Preview {
    GridLayoutExample()
}
