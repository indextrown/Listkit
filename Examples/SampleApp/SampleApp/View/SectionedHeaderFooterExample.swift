import SwiftUI
import ListKit

struct SectionedHeaderFooterExample: View {
    var body: some View {
        LKList {
            LKSection(id: "pinned") {
                for message in ListKitExampleData.pinned {
                    LKRow(message, id: \.id) {
                        ExampleMessageRow(message: message)
                    }
                }
            } header: {
                Text("Pinned")
            }

            LKSection(id: "all") {
                for message in ListKitExampleData.messages {
                    LKRow(message, id: \.id) {
                        ExampleMessageRow(message: message)
                    }
                }
            } header: {
                Text("All")
            } footer: {
                Text("\(ListKitExampleData.messages.count) messages")
            }
        }
        .listKitStyle(.insetGrouped)
    }
}

#Preview {
    SectionedHeaderFooterExample()
}
