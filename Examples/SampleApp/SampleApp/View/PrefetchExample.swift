import SwiftUI
import ListKit

struct PrefetchExample: View {
    private enum Const {
        static let pageSize = 100
        static let maximumMessageCount = 10_000
    }

    @State private var messages = [ExampleMessage]()
    @State private var page = 0

    var body: some View {
        LKList {
            LKSection(id: "Section") {
                for message in messages {
                    LKRow(message, id: \.id) {
                        PrefetchPaginationRow(message: message)
                    }
                    .onWillDisplay { context in
                        guard let message = context.item as? ExampleMessage else { return }
                        print("표시직전: \(message.title)")
                    }
                    .onDidEndDisplaying { context in
                        guard let message = context.item as? ExampleMessage else { return }
                        print("사라짐: \(message.title)")
                    }
                    .onHighlight { context in
                        guard let message = context.item as? ExampleMessage else { return }
                        print("눌림: \(message.title)")
                    }
                    .onUnhighlight { context in
                        guard let message = context.item as? ExampleMessage else { return }
                        print("눌림취소: \(message.title)")
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("헤더 타이틀")
                        .font(.headline)
                    Text("헤더 서브 타이틀")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(messages.count) / \(Const.maximumMessageCount)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            .sectionLayout(.list(appearance: .plain))
        }
        .listKitStyle(.plain)
        .refreshable {
            resetMessages()
            print("새로고침!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
        }
        .onReachEnd(threshold: .points(600)) {
            appendMessages()
        }
        .onDidEndDecelerating { _ in
            print("스크롤 감속 종료")
        }
        .updateEngine(.diffableDataSource)
        .navigationTitle("Prefetch")
        .onAppear {
            guard messages.isEmpty else { return }
            resetMessages()
        }
    }

    private func resetMessages() {
        page = 0
        messages = makeMessages(page: page, count: Const.pageSize)
    }

    private func appendMessages() {
        guard messages.count < Const.maximumMessageCount else { return }

        let remainingCount = Const.maximumMessageCount - messages.count
        let nextCount = min(Const.pageSize, remainingCount)
        guard nextCount > 0 else { return }

        page += 1
        messages.append(contentsOf: makeMessages(page: page, count: nextCount))
    }

    private func makeMessages(page: Int, count: Int) -> [ExampleMessage] {
        let startID = page * Const.pageSize
        return (0..<count).map { offset in
            let id = startID + offset
            return ExampleMessage(
                id: id,
                title: "Prefetch item \(id)",
                subtitle: randomSubtitle()
            )
        }
    }

    private func randomSubtitle() -> String {
        [
            "끝에 가까워지면 다음 페이지를 미리 추가합니다.",
            "onReachEnd로 pageSize만큼 append합니다.",
            "willDisplay와 didEndDisplaying 로그를 확인하세요.",
            "refresh하면 첫 페이지로 초기화됩니다.",
        ].randomElement() ?? "Prefetch row"
    }
}

private struct PrefetchPaginationRow: View {
    let message: ExampleMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.title)
                .font(.headline)
            Text(message.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("id: \(message.id)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

#Preview {
    NavigationStack {
        PrefetchExample()
    }
}
