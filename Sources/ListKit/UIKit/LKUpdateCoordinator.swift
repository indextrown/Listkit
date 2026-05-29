#if canImport(UIKit) && canImport(SwiftUI)
import UIKit

@MainActor
final class LKUpdateCoordinator {
    let engine: LKUpdateEngine
    var focusRestorationHandler: (() -> Void)?

    init(engine: LKUpdateEngine = .differenceKit) {
        self.engine = engine
    }

    func apply(
        _ model: LKListModel,
        currentModel: LKListModel,
        collectionView: UICollectionView?,
        registerReuseIdentifiers: (LKListModel) -> Void,
        updateCurrentModel: (LKListModel) -> Void,
        reloadData: () -> Void
    ) {
        switch engine {
        case .reloadData:
            applyReloadData(
                model,
                currentModel: currentModel,
                collectionView: collectionView,
                registerReuseIdentifiers: registerReuseIdentifiers,
                updateCurrentModel: updateCurrentModel,
                reloadData: reloadData
            )
        case .diffableDataSource, .differenceKit:
            applyReloadData(
                model,
                currentModel: currentModel,
                collectionView: collectionView,
                registerReuseIdentifiers: registerReuseIdentifiers,
                updateCurrentModel: updateCurrentModel,
                reloadData: reloadData
            )
        }
    }

    private func applyReloadData(
        _ model: LKListModel,
        currentModel: LKListModel,
        collectionView: UICollectionView?,
        registerReuseIdentifiers: (LKListModel) -> Void,
        updateCurrentModel: (LKListModel) -> Void,
        reloadData: () -> Void
    ) {
        model.validateForApply()
        let selectedItemIDs = selectedItemIDs(in: collectionView, model: currentModel)

        registerReuseIdentifiers(model)
        updateCurrentModel(model)
        reloadData()
        restoreSelection(selectedItemIDs, in: collectionView, model: model)
        restoreFocus(in: collectionView)
    }

    private func selectedItemIDs(
        in collectionView: UICollectionView?,
        model: LKListModel
    ) -> [AnyHashable] {
        collectionView?.indexPathsForSelectedItems?.compactMap { indexPath in
            model.item(at: indexPath)?.id
        } ?? []
    }

    private func restoreSelection(
        _ selectedItemIDs: [AnyHashable],
        in collectionView: UICollectionView?,
        model: LKListModel
    ) {
        guard let collectionView, selectedItemIDs.isEmpty == false else {
            return
        }

        let modelIndex = LKListModelIndex(model: model)
        for itemID in selectedItemIDs {
            guard let indexPath = modelIndex.indexPath(forItemID: itemID) else {
                continue
            }
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
    }

    private func restoreFocus(in collectionView: UICollectionView?) {
        guard focusRestorationHandler != nil else {
            return
        }

        collectionView?.setNeedsFocusUpdate()
        focusRestorationHandler?()
    }

}
#endif
