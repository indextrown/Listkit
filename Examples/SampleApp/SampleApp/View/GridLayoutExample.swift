import SwiftUI
import ListKit

struct GridLayoutExample: View {
    var body: some View {
        LKList {
            LKSection(id: "featured") {
                for message in ListKitExampleData.messages.prefix(6) {
                    LKRow(message, id: \.id) {
                        ExampleMessageRow(message: message)
                            .frame(width: 220)
                    }
                }
            } header: {
                Text("Horizontal section")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            .scrollAxis(.horizontal)
            .itemSpacing(12)
            .pinnedHeader()

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
        }
    }
}

#Preview {
    GridLayoutExample()
}
