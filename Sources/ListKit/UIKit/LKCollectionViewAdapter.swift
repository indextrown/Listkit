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

struct LKSupplementarySizeKey: Hashable {
    let kind: String
    let indexPath: IndexPath
}

@MainActor
final class LKCollectionViewAdapter: NSObject {
    private weak var collectionView: UICollectionView?
    private(set) var currentModel: LKListModel
    private(set) var registeredCellKeys = Set<LKCellRegistrationKey>()
    private(set) var registeredHeaderKeys = Set<LKSupplementaryRegistrationKey>()
    private(set) var registeredFooterKeys = Set<LKSupplementaryRegistrationKey>()
    private(set) var itemSizeStorage = [IndexPath: CGSize]()
    private(set) var supplementarySizeStorage = [LKSupplementarySizeKey: CGSize]()
    private var isUpdating = false
    private var queuedUpdate: LKListModel?
    private let updateCoordinator: LKUpdateCoordinator
    var reloadDataHandler: (() -> Void)?
    var focusRestorationHandler: (() -> Void)? {
        get { updateCoordinator.focusRestorationHandler }
        set { updateCoordinator.focusRestorationHandler = newValue }
    }

    init(
        collectionView: UICollectionView,
        model: LKListModel = .empty,
        updateEngine: LKUpdateEngine = .reloadData
    ) {
        self.collectionView = collectionView
        self.currentModel = model
        self.updateCoordinator = LKUpdateCoordinator(engine: updateEngine)
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
        updateCoordinator.apply(
            model,
            currentModel: currentModel,
            collectionView: collectionView,
            registerReuseIdentifiers: registerReuseIdentifiersIfNeeded(from:),
            updateCurrentModel: { [weak self] model in
                self?.currentModel = model
            },
            reloadData: { [weak self] in
                guard let self else { return }
                if let reloadDataHandler {
                    reloadDataHandler()
                } else {
                    collectionView?.reloadData()
                }
            }
        )
        isUpdating = false

        if let queuedUpdate {
            self.queuedUpdate = nil
            apply(queuedUpdate)
        }
    }

    func recordItemSize(_ size: CGSize, at indexPath: IndexPath) {
        itemSizeStorage[indexPath] = size
    }

    func recordSupplementarySize(_ size: CGSize, kind: String, at indexPath: IndexPath) {
        let key = LKSupplementarySizeKey(kind: kind, indexPath: indexPath)
        supplementarySizeStorage[key] = size
    }

    func registerReuseIdentifiersIfNeeded(from model: LKListModel) {
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

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: item.reuseIdentifier,
            for: indexPath
        )
        (cell as? LKHostingCollectionViewCell)?.render(item: item) { [weak self] size in
            self?.recordItemSize(size, at: indexPath)
        }
        return cell
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

        let view = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: supplementary.reuseIdentifier,
            for: indexPath
        )
        (view as? LKHostingSupplementaryView)?.render(supplementary: supplementary) { [weak self] size in
            self?.recordSupplementarySize(size, kind: kind, at: indexPath)
        }
        return view
    }
}

extension LKCollectionViewAdapter: UICollectionViewDelegate {}
#endif
