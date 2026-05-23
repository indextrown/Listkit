#if canImport(UIKit) && canImport(SwiftUI)
import UIKit

struct LKCellRegistrationKey: Hashable {
    let reuseIdentifier: String
    let hostingStrategy: LKHostingStrategy
}

struct LKSupplementaryRegistrationKey: Hashable {
    let kind: String
    let reuseIdentifier: String
    let hostingStrategy: LKHostingStrategy
}

@MainActor
final class LKCollectionViewAdapter: NSObject {
    private weak var collectionView: UICollectionView?
    private(set) var currentModel: LKListModel
    private(set) var registeredCellKeys = Set<LKCellRegistrationKey>()
    private(set) var registeredHeaderKeys = Set<LKSupplementaryRegistrationKey>()
    private(set) var registeredFooterKeys = Set<LKSupplementaryRegistrationKey>()
    private var isUpdating = false
    private var queuedUpdate: LKListModel?
    var reloadDataHandler: (() -> Void)?

    init(collectionView: UICollectionView, model: LKListModel = .empty) {
        self.collectionView = collectionView
        self.currentModel = model
        super.init()
        collectionView.delegate = self
        collectionView.dataSource = self
        registerReuseIdentifiersIfNeeded(from: model)
    }

    func apply(_ model: LKListModel) {
        guard isUpdating == false else {
            queuedUpdate = model
            return
        }

        isUpdating = true
        model.validateForApply()
        registerReuseIdentifiersIfNeeded(from: model)
        currentModel = model
        if let reloadDataHandler {
            reloadDataHandler()
        } else {
            collectionView?.reloadData()
        }
        isUpdating = false

        if let queuedUpdate {
            self.queuedUpdate = nil
            apply(queuedUpdate)
        }
    }

    private func registerReuseIdentifiersIfNeeded(from model: LKListModel) {
        for section in model.sections {
            for item in section.items {
                registerCellIfNeeded(item)
            }

            if let header = section.header {
                registerHeaderIfNeeded(header)
            }

            if let footer = section.footer {
                registerFooterIfNeeded(footer)
            }
        }
    }

    private func registerCellIfNeeded(_ item: LKItemModel) {
        guard let collectionView else {
            return
        }

        let key = LKCellRegistrationKey(
            reuseIdentifier: item.reuseIdentifier,
            hostingStrategy: item.hostingStrategy
        )

        guard registeredCellKeys.insert(key).inserted else {
            return
        }

        collectionView.register(
            LKHostingCollectionViewCell.self,
            forCellWithReuseIdentifier: key.reuseIdentifier
        )
    }

    private func registerHeaderIfNeeded(_ header: LKSupplementaryModel) {
        registerSupplementaryIfNeeded(
            header,
            kind: UICollectionView.elementKindSectionHeader,
            keyStore: &registeredHeaderKeys
        )
    }

    private func registerFooterIfNeeded(_ footer: LKSupplementaryModel) {
        registerSupplementaryIfNeeded(
            footer,
            kind: UICollectionView.elementKindSectionFooter,
            keyStore: &registeredFooterKeys
        )
    }

    private func registerSupplementaryIfNeeded(
        _ supplementary: LKSupplementaryModel,
        kind: String,
        keyStore: inout Set<LKSupplementaryRegistrationKey>
    ) {
        guard let collectionView else {
            return
        }

        let key = LKSupplementaryRegistrationKey(
            kind: kind,
            reuseIdentifier: supplementary.reuseIdentifier,
            hostingStrategy: supplementary.hostingStrategy
        )

        guard keyStore.insert(key).inserted else {
            return
        }

        collectionView.register(
            LKHostingSupplementaryView.self,
            forSupplementaryViewOfKind: kind,
            withReuseIdentifier: key.reuseIdentifier
        )
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
        guard let item = currentModel.item(at: indexPath) else {
            return UICollectionViewCell()
        }

        return collectionView.dequeueReusableCell(
            withReuseIdentifier: item.reuseIdentifier,
            for: indexPath
        )
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let supplementaryKind: LKSupplementaryKind

        switch kind {
        case UICollectionView.elementKindSectionHeader:
            supplementaryKind = .header
        case UICollectionView.elementKindSectionFooter:
            supplementaryKind = .footer
        default:
            supplementaryKind = .custom(kind)
        }

        guard let supplementary = currentModel.supplementary(kind: supplementaryKind, at: indexPath) else {
            return UICollectionReusableView()
        }

        return collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: supplementary.reuseIdentifier,
            for: indexPath
        )
    }
}

extension LKCollectionViewAdapter: UICollectionViewDelegate {}
#endif
