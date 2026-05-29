#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit

struct LKCollectionViewRepresentable: UIViewRepresentable {
    let model: LKListModel
    let listEvents: LKListEvents
    let selectionConfiguration: LKSelectionConfiguration
    let scrollConfiguration: LKScrollConfiguration
    let refreshConfiguration: LKRefreshConfiguration
    let diagnosticsMode: LKListKitDiagnosticsMode
    let style: LKListStyle
    let updateEngine: LKUpdateEngine
    let listProxy: LKListProxy?

    init(
        model: LKListModel,
        listEvents: LKListEvents = LKListEvents(),
        selectionConfiguration: LKSelectionConfiguration = LKSelectionConfiguration(),
        scrollConfiguration: LKScrollConfiguration = LKScrollConfiguration(),
        refreshConfiguration: LKRefreshConfiguration = LKRefreshConfiguration(),
        diagnosticsMode: LKListKitDiagnosticsMode = .disabled,
        style: LKListStyle = .plain,
        updateEngine: LKUpdateEngine = .differenceKit,
        listProxy: LKListProxy? = nil
    ) {
        self.model = model
        self.listEvents = listEvents
        self.selectionConfiguration = selectionConfiguration
        self.scrollConfiguration = scrollConfiguration
        self.refreshConfiguration = refreshConfiguration
        self.diagnosticsMode = diagnosticsMode
        self.style = style
        self.updateEngine = updateEngine
        self.listProxy = listProxy
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            model: model,
            listEvents: listEvents,
            selectionConfiguration: selectionConfiguration,
            scrollConfiguration: scrollConfiguration,
            refreshConfiguration: refreshConfiguration,
            diagnosticsMode: diagnosticsMode,
            style: style,
            updateEngine: updateEngine,
            listProxy: listProxy
        )
    }

    func makeUIView(context: Context) -> UICollectionView {
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

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.installIfNeeded(on: collectionView)
        context.coordinator.apply(
            model,
            listEvents: listEvents,
            selectionConfiguration: selectionConfiguration,
            scrollConfiguration: scrollConfiguration,
            refreshConfiguration: refreshConfiguration,
            diagnosticsMode: diagnosticsMode,
            style: style,
            updateEngine: updateEngine,
            listProxy: listProxy,
            to: collectionView
        )
    }

    final class Coordinator {
        private var adapter: LKCollectionViewAdapter?
        private var pendingModel: LKListModel
        private var pendingListEvents: LKListEvents
        private var pendingSelectionConfiguration: LKSelectionConfiguration
        private var pendingScrollConfiguration: LKScrollConfiguration
        private var pendingRefreshConfiguration: LKRefreshConfiguration
        private var pendingDiagnosticsMode: LKListKitDiagnosticsMode
        private var pendingStyle: LKListStyle
        private var pendingUpdateEngine: LKUpdateEngine
        private weak var pendingListProxy: LKListProxy?
        private weak var attachedListProxy: LKListProxy?
        private var layoutSignature: String

        init(
            model: LKListModel,
            listEvents: LKListEvents,
            selectionConfiguration: LKSelectionConfiguration,
            scrollConfiguration: LKScrollConfiguration,
            refreshConfiguration: LKRefreshConfiguration,
            diagnosticsMode: LKListKitDiagnosticsMode,
            style: LKListStyle,
            updateEngine: LKUpdateEngine,
            listProxy: LKListProxy?
        ) {
            self.pendingModel = model
            self.pendingListEvents = listEvents
            self.pendingSelectionConfiguration = selectionConfiguration
            self.pendingScrollConfiguration = scrollConfiguration
            self.pendingRefreshConfiguration = refreshConfiguration
            self.pendingDiagnosticsMode = diagnosticsMode
            self.pendingStyle = style
            self.pendingUpdateEngine = updateEngine
            self.pendingListProxy = listProxy
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
                refreshConfiguration: pendingRefreshConfiguration,
                diagnosticsMode: pendingDiagnosticsMode,
                updateEngine: pendingUpdateEngine
            )
            attachProxyIfNeeded()
        }

        @MainActor
        func apply(
            _ model: LKListModel,
            listEvents: LKListEvents,
            selectionConfiguration: LKSelectionConfiguration,
            scrollConfiguration: LKScrollConfiguration,
            refreshConfiguration: LKRefreshConfiguration,
            diagnosticsMode: LKListKitDiagnosticsMode,
            style: LKListStyle,
            updateEngine: LKUpdateEngine,
            listProxy: LKListProxy?,
            to collectionView: UICollectionView
        ) {
            pendingModel = model
            pendingListEvents = listEvents
            pendingSelectionConfiguration = selectionConfiguration
            pendingScrollConfiguration = scrollConfiguration
            pendingRefreshConfiguration = refreshConfiguration
            pendingDiagnosticsMode = diagnosticsMode
            pendingStyle = style
            pendingUpdateEngine = updateEngine
            pendingListProxy = listProxy
            updateLayoutIfNeeded(model: model, style: style, collectionView: collectionView)
            adapter?.apply(
                model,
                listEvents: listEvents,
                selectionConfiguration: selectionConfiguration,
                scrollConfiguration: scrollConfiguration,
                refreshConfiguration: refreshConfiguration,
                diagnosticsMode: diagnosticsMode,
                deferSelectionBindingUpdates: true
            )
            attachProxyIfNeeded()
        }

        @MainActor
        private func attachProxyIfNeeded() {
            guard let adapter else {
                return
            }

            if attachedListProxy !== pendingListProxy {
                attachedListProxy?.detach(adapter)
                pendingListProxy?.attach(adapter)
                attachedListProxy = pendingListProxy
            }
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
