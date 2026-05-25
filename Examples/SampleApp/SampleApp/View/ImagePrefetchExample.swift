import Combine
import Foundation
import SwiftUI
import UIKit
import ListKit

struct ImagePrefetchExample: View {
    @StateObject private var imageStore = ImagePrefetchStore()

    private let items = (0..<80).map {
        ImagePrefetchItem(
            id: $0,
            title: "Image row \($0)",
            subtitle: "Prefetch image before the row appears",
            imageURL: URL(string: "https://picsum.photos/seed/listkit-\($0)/160/120")!
        )
    }

    var body: some View {
        LKList(items, id: \.id) { item in
            ImagePrefetchRow(item: item, imageStore: imageStore)
        }
        .listKitStyle(.plain)
        .onPrefetch { contexts in
            let items = contexts.compactMap { $0.item as? ImagePrefetchItem }
            imageStore.prefetch(items)
            print("이미지 프리패치: \(items.map(\.id))")
        }
        .onCancelPrefetch { contexts in
            let items = contexts.compactMap { $0.item as? ImagePrefetchItem }
            imageStore.cancelPrefetch(items)
            print("이미지 프리패치 취소: \(items.map(\.id))")
        }
        .navigationTitle("Image Prefetch")
        .onDisappear {
            imageStore.cancelAll()
        }
    }
}

private struct ImagePrefetchItem: Identifiable, Hashable {
    let id: Int
    let title: String
    let subtitle: String
    let imageURL: URL
}

private struct ImagePrefetchRow: View {
    let item: ImagePrefetchItem
    @ObservedObject var imageStore: ImagePrefetchStore

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image = imageStore.image(for: item.id) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.18))
                        .overlay {
                            ProgressView()
                        }
                }
            }
            .frame(width: 80, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(item.imageURL.absoluteString)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .onAppear {
            imageStore.load(item)
        }
    }
}

@MainActor
private final class ImagePrefetchStore: ObservableObject {
    @Published private var images = [Int: UIImage]()

    private var tasks = [Int: Task<Void, Never>]()

    func image(for id: Int) -> UIImage? {
        images[id]
    }

    func prefetch(_ items: [ImagePrefetchItem]) {
        for item in items {
            load(item)
        }
    }

    func load(_ item: ImagePrefetchItem) {
        guard images[item.id] == nil, tasks[item.id] == nil else {
            return
        }

        let id = item.id
        let url = item.imageURL

        tasks[id] = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard Task.isCancelled == false, let image = UIImage(data: data) else {
                    self?.clearTask(id: id)
                    return
                }

                self?.store(image, for: id)
            } catch {
                self?.clearTask(id: id)
            }
        }
    }

    func cancelPrefetch(_ items: [ImagePrefetchItem]) {
        for item in items where images[item.id] == nil {
            tasks[item.id]?.cancel()
            tasks[item.id] = nil
        }
    }

    func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
    }

    private func store(_ image: UIImage, for id: Int) {
        images[id] = image
        tasks[id] = nil
    }

    private func clearTask(id: Int) {
        tasks[id] = nil
    }
}

#Preview {
    NavigationStack {
        ImagePrefetchExample()
    }
}
