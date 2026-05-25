import SwiftUI
import ListKit

struct DisplayLifecycleExample: View {
    var body: some View {
        LKList(ListKitExampleData.messages, id: \.id) { message in
            ExampleMessageRow(message: message)
        }
        .onWillDisplay { context in
            ExampleImagePipeline.resume(for: context.id)
        }
        .onDidEndDisplaying { context in
            ExampleImagePipeline.pause(for: context.id)
        }
    }
}

#Preview {
    DisplayLifecycleExample()
}
