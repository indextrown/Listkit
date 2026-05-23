#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit

public struct LKCollectionViewRepresentable: UIViewRepresentable {
    let model: LKListModel
    let style: LKListStyle

    init(model: LKListModel, style: LKListStyle = .plain) {
        self.model = model
        self.style = style
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(model: model, style: style)
    }

    public func makeUIView(context: Context) -> UICollectionView {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: LKCollectionLayoutProvider.makeLayout(
                model: model,
                defaultStyle: style
            )
        )
        collectionView.backgroundColor = .clear
        context.coordinator.installIfNeeded(on: collectionView)
        return collectionView
    }

    public func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.installIfNeeded(on: collectionView)
        context.coordinator.apply(model, style: style, to: collectionView)
    }

    public final class Coordinator {
        private var adapter: LKCollectionViewAdapter?
        private var pendingModel: LKListModel
        private var pendingStyle: LKListStyle
        private var layoutSignature: String

        init(model: LKListModel, style: LKListStyle) {
            self.pendingModel = model
            self.pendingStyle = style
            self.layoutSignature = ""
        }

        @MainActor
        func installIfNeeded(on collectionView: UICollectionView) {
            guard adapter == nil else {
                return
            }
            adapter = LKCollectionViewAdapter(collectionView: collectionView, model: pendingModel)
        }

        @MainActor
        func apply(_ model: LKListModel, style: LKListStyle, to collectionView: UICollectionView) {
            pendingModel = model
            pendingStyle = style
            updateLayoutIfNeeded(model: model, style: style, collectionView: collectionView)
            adapter?.apply(model)
        }

        @MainActor
        private func updateLayoutIfNeeded(
            model: LKListModel,
            style: LKListStyle,
            collectionView: UICollectionView
        ) {
            let newSignature = LKCollectionLayoutProvider.signature(model: model, defaultStyle: style)
            guard newSignature != layoutSignature else {
                return
            }

            layoutSignature = newSignature
            collectionView.setCollectionViewLayout(
                LKCollectionLayoutProvider.makeLayout(model: model, defaultStyle: style),
                animated: false
            )
        }
    }
}
#endif
