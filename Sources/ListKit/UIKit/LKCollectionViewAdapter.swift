#if canImport(UIKit) && canImport(SwiftUI)
import UIKit

@MainActor
final class LKCollectionViewAdapter: NSObject {
    private weak var collectionView: UICollectionView?
    private(set) var currentModel: LKListModel

    init(collectionView: UICollectionView, model: LKListModel = .empty) {
        self.collectionView = collectionView
        self.currentModel = model
        super.init()
        collectionView.delegate = self
        collectionView.dataSource = self
    }

    func apply(_ model: LKListModel) {
        currentModel = model
        collectionView?.reloadData()
    }
}

extension LKCollectionViewAdapter: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        currentModel.sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        currentModel.section(at: section)?.items.count ?? 0
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        UICollectionViewCell()
    }
}

extension LKCollectionViewAdapter: UICollectionViewDelegate {}
#endif
