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
    private(set) var lastReconfiguredItemIdentifiers = [LKItemIdentifier]()
    private var isUpdating = false
    private var queuedUpdate: LKListModel?
    private let updateEngine: LKUpdateEngine
    private let updateCoordinator: LKUpdateCoordinator
    private var diffableDataSource: UICollectionViewDiffableDataSource<LKSectionIdentifier, LKItemIdentifier>?
    var reloadDataHandler: (() -> Void)?
    var diffableApplyCompletionHandler: (() -> Void)?
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
        self.updateEngine = updateEngine
        self.updateCoordinator = LKUpdateCoordinator(engine: updateEngine)
        super.init()
        collectionView.delegate = self
        if updateEngine == .diffableDataSource {
            configureDiffableDataSource(on: collectionView)
        } else {
            collectionView.dataSource = self
        }
        registerReuseIdentifiersIfNeeded(from: model)
    }

    func apply(_ model: LKListModel) {
        guard isUpdating == false else {
            queuedUpdate = model
            return
        }

        isUpdating = true

        switch updateEngine {
        case .diffableDataSource:
            applyDiffableDataSource(model)
        case .reloadData, .differenceKit:
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
            finishApply()
        }
    }

    private func finishApply() {
        isUpdating = false

        if let queuedUpdate {
            self.queuedUpdate = nil
            if updateEngine == .diffableDataSource {
                Task { @MainActor [weak self] in
                    self?.apply(queuedUpdate)
                }
            } else {
                apply(queuedUpdate)
            }
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

    private func configureDiffableDataSource(on collectionView: UICollectionView) {
        diffableDataSource = UICollectionViewDiffableDataSource<LKSectionIdentifier, LKItemIdentifier>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, _ in
            self?.makeCell(collectionView, at: indexPath) ?? UICollectionViewCell()
        }

        diffableDataSource?.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            self?.makeSupplementaryView(collectionView, kind: kind, at: indexPath) ?? UICollectionReusableView()
        }
    }

    private func applyDiffableDataSource(_ model: LKListModel) {
        model.validateForApply()
        let previousModel = currentModel
        let selectedItemIDs = selectedItemIDs(in: collectionView, model: previousModel)
        let changedItems = changedContentItemIdentifiers(from: previousModel, to: model)

        registerReuseIdentifiersIfNeeded(from: model)
        currentModel = model

        var snapshot = NSDiffableDataSourceSnapshot<LKSectionIdentifier, LKItemIdentifier>()
        for section in model.sections {
            let sectionIdentifier = LKSectionIdentifier(section)
            snapshot.appendSections([sectionIdentifier])
            snapshot.appendItems(
                section.items.map { LKItemIdentifier(section: section, item: $0) },
                toSection: sectionIdentifier
            )
        }
        lastReconfiguredItemIdentifiers = changedItems
        if changedItems.isEmpty == false {
            snapshot.reloadItems(changedItems)
        }

        let shouldAnimate = collectionView?.window != nil
        diffableDataSource?.apply(snapshot, animatingDifferences: shouldAnimate) { [weak self] in
            guard let self else { return }
            self.restoreSelection(selectedItemIDs, in: self.collectionView, model: model)
            self.restoreFocus(in: self.collectionView)
            self.diffableApplyCompletionHandler?()
            self.finishApply()
        }
    }

    private func makeCell(
        _ collectionView: UICollectionView,
        at indexPath: IndexPath
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

    private func makeSupplementaryView(
        _ collectionView: UICollectionView,
        kind: String,
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

    private func changedContentItemIdentifiers(
        from oldModel: LKListModel,
        to newModel: LKListModel
    ) -> [LKItemIdentifier] {
        var oldItems = [LKItemIdentifier: LKItemModel]()

        for section in oldModel.sections {
            for item in section.items {
                oldItems[LKItemIdentifier(section: section, item: item)] = item
            }
        }

        return newModel.sections.flatMap { section in
            section.items.compactMap { item in
                let identifier = LKItemIdentifier(section: section, item: item)
                guard
                    let oldItem = oldItems[identifier],
                    oldItem.contentToken != item.contentToken
                else {
                    return nil
                }
                return identifier
            }
        }
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

        for itemID in selectedItemIDs {
            guard let indexPath = indexPath(forItemID: itemID, in: model) else {
                continue
            }
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
    }

    private func restoreFocus(in collectionView: UICollectionView?) {
        collectionView?.setNeedsFocusUpdate()
        focusRestorationHandler?()
    }

    private func indexPath(forItemID itemID: AnyHashable, in model: LKListModel) -> IndexPath? {
        for sectionIndex in model.sections.indices {
            let section = model.sections[sectionIndex]
            guard let itemIndex = section.items.firstIndex(where: { $0.id == itemID }) else {
                continue
            }
            return IndexPath.lkIndexPath(item: itemIndex, section: sectionIndex)
        }
        return nil
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
        makeCell(collectionView, at: indexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        makeSupplementaryView(collectionView, kind: kind, at: indexPath)
    }
}

extension LKCollectionViewAdapter: UICollectionViewDelegate {}
#endif
