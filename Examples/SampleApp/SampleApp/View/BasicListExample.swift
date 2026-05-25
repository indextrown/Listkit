import SwiftUI
import ListKit

struct BasicListExample: View {
    var body: some View {
        LKList(ListKitExampleData.messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .listKitStyle(.plain)
        .onSelect { context in
            print("Selected", context.id)
        }
        .onWillDisplay { context in
            ExampleImagePipeline.resume(for: context.id)
        }
        .onDidEndDisplaying { context in
            ExampleImagePipeline.pause(for: context.id)
        }
        .refreshable {
            await Task.yield()
        }
        .updateEngine(.diffableDataSource)
    }
}

#Preview {
    BasicListExample()
}
