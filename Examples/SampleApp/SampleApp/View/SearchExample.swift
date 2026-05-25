import SwiftUI
import ListKit

struct SearchExample: View {
    @State private var query = ""

    private var filteredMessages: [ExampleMessage] {
        guard !query.isEmpty else { return ListKitExampleData.messages }
        return ListKitExampleData.messages.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        LKList(filteredMessages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .searchable(text: $query)
    }
}

#Preview {
    NavigationStack {
        SearchExample()
    }
}
