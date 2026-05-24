#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit

public struct LKCollectionViewRepresentable: UIViewRepresentable {
    let model: LKListModel
    let listEvents: LKListEvents
    let selectionConfiguration: LKSelectionConfiguration
    let scrollConfiguration: LKScrollConfiguration
    let style: LKListStyle
    let updateEngine: LKUpdateEngine

    init(
        model: LKListModel,
        listEvents: LKListEvents = LKListEvents(),
        selectionConfiguration: LKSelectionConfiguration = LKSelectionConfiguration(),
        scrollConfiguration: LKScrollConfiguration = LKScrollConfiguration(),
        style: LKListStyle = .plain,
        updateEngine: LKUpdateEngine = .reloadData
    ) {
        self.model = model
        self.listEvents = listEvents
        self.selectionConfiguration = selectionConfiguration
        self.scrollConfiguration = scrollConfiguration
        self.style = style
        self.updateEngine = updateEngine
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            model: model,
            listEvents: listEvents,
            selectionConfiguration: selectionConfiguration,
            scrollConfiguration: scrollConfiguration,
            style: style,
            updateEngine: updateEngine
        )
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
        context.coordinator.apply(
            model,
            listEvents: listEvents,
            selectionConfiguration: selectionConfiguration,
            scrollConfiguration: scrollConfiguration,
            style: style,
            updateEngine: updateEngine,
            to: collectionView
        )
    }

    public final class Coordinator {
        private var adapter: LKCollectionViewAdapter?
        private var pendingModel: LKListModel
        private var pendingListEvents: LKListEvents
        private var pendingSelectionConfiguration: LKSelectionConfiguration
        private var pendingScrollConfiguration: LKScrollConfiguration
        private var pendingStyle: LKListStyle
        private var pendingUpdateEngine: LKUpdateEngine
        private var layoutSignature: String

        init(
            model: LKListModel,
            listEvents: LKListEvents,
            selectionConfiguration: LKSelectionConfiguration,
            scrollConfiguration: LKScrollConfiguration,
            style: LKListStyle,
            updateEngine: LKUpdateEngine
        ) {
            self.pendingModel = model
            self.pendingListEvents = listEvents
            self.pendingSelectionConfiguration = selectionConfiguration
            self.pendingScrollConfiguration = scrollConfiguration
            self.pendingStyle = style
            self.pendingUpdateEngine = updateEngine
            self.layoutSignature = ""
        }

        @MainActor
        func installIfNeeded(on collectionView: UICollectionView) {
            guard adapter == nil else {
                return
            }
            adapter = LKCollectionViewAdapter(
                collectionView: collectionView,
                model: pendingModel,
                listEvents: pendingListEvents,
                selectionConfiguration: pendingSelectionConfiguration,
                scrollConfiguration: pendingScrollConfiguration,
                updateEngine: pendingUpdateEngine
            )
        }

        @MainActor
        func apply(
            _ model: LKListModel,
            listEvents: LKListEvents,
            selectionConfiguration: LKSelectionConfiguration,
            scrollConfiguration: LKScrollConfiguration,
            style: LKListStyle,
            updateEngine: LKUpdateEngine,
            to collectionView: UICollectionView
        ) {
            pendingModel = model
            pendingListEvents = listEvents
            pendingSelectionConfiguration = selectionConfiguration
            pendingScrollConfiguration = scrollConfiguration
            pendingStyle = style
            pendingUpdateEngine = updateEngine
            updateLayoutIfNeeded(model: model, style: style, collectionView: collectionView)
            adapter?.apply(
                model,
                listEvents: listEvents,
                selectionConfiguration: selectionConfiguration,
                scrollConfiguration: scrollConfiguration
            )
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
