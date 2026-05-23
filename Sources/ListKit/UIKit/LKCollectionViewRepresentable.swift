#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit

public struct LKCollectionViewRepresentable: UIViewRepresentable {
    let model: LKListModel

    init(model: LKListModel) {
        self.model = model
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    public func makeUIView(context: Context) -> UICollectionView {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: Self.makeDefaultLayout()
        )
        collectionView.backgroundColor = .clear
        context.coordinator.installIfNeeded(on: collectionView)
        return collectionView
    }

    public func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.installIfNeeded(on: collectionView)
        context.coordinator.apply(model)
    }

    private static func makeDefaultLayout() -> UICollectionViewLayout {
        var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
        configuration.showsSeparators = true
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }

    public final class Coordinator {
        private var adapter: LKCollectionViewAdapter?
        private var pendingModel: LKListModel

        init(model: LKListModel) {
            self.pendingModel = model
        }

        @MainActor
        func installIfNeeded(on collectionView: UICollectionView) {
            guard adapter == nil else {
                return
            }
            adapter = LKCollectionViewAdapter(collectionView: collectionView, model: pendingModel)
        }

        @MainActor
        func apply(_ model: LKListModel) {
            pendingModel = model
            adapter?.apply(model)
        }
    }
}
#endif
