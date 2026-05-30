#if canImport(UIKit) && canImport(SwiftUI)
import DifferenceKit
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

private struct LKCellRegistrationDescriptor: Hashable {
    let reuseIdentifier: String
    let hostingStrategy: LKHostingStrategy
}

private struct LKSupplementaryRegistrationDescriptor: Hashable {
    let kind: LKSupplementaryKind
    let reuseIdentifier: String
    let hostingStrategy: LKHostingStrategy
}

private struct LKRegistrationSummary {
    var cellDescriptors = Set<LKCellRegistrationDescriptor>()
    var headerDescriptors = Set<LKSupplementaryRegistrationDescriptor>()
    var footerDescriptors = Set<LKSupplementaryRegistrationDescriptor>()

    init(model: LKListModel) {
        for section in model.sections {
            for item in section.items {
                cellDescriptors.insert(
                    LKCellRegistrationDescriptor(
                        reuseIdentifier: item.reuseIdentifier,
                        hostingStrategy: item.hostingStrategy
                    )
                )
            }

            if let header = section.header {
                headerDescriptors.insert(
                    LKSupplementaryRegistrationDescriptor(
                        kind: header.kind,
                        reuseIdentifier: header.reuseIdentifier,
                        hostingStrategy: header.hostingStrategy
                    )
                )
            }

            if let footer = section.footer {
                footerDescriptors.insert(
                    LKSupplementaryRegistrationDescriptor(
                        kind: footer.kind,
                        reuseIdentifier: footer.reuseIdentifier,
                        hostingStrategy: footer.hostingStrategy
                    )
                )
            }
        }
    }
}

struct LKItemSizeKey: Hashable {
    let sectionID: AnyHashable
    let itemID: AnyHashable
    let contentToken: AnyHashable?
}

struct LKSupplementarySizeKey: Hashable {
    let kind: String
    let sectionID: AnyHashable
    let supplementaryID: AnyHashable
    let contentToken: AnyHashable?
}

private struct LKAppendOnlyUpdate {
    let insertedIndexPaths: [IndexPath]
}

private let lkEmptySupplementaryReuseIdentifier = "ListKit.EmptySupplementaryView"

@MainActor
final class LKCollectionViewAdapter: NSObject {
    private weak var collectionView: UICollectionView?
    private(set) var currentModel: LKListModel {
        didSet {
            currentModelIndex = nil
        }
    }
    private var currentModelIndex: LKListModelIndex?
    private var listEvents: LKListEvents
    private var selectionConfiguration: LKSelectionConfiguration
    private var scrollConfiguration: LKScrollConfiguration
    private var refreshConfiguration: LKRefreshConfiguration
    private var diagnosticsMode: LKListKitDiagnosticsMode
    private var isReachEndArmed = true
    private var lastReachEndContentSize: CGSize?
    private var isRefreshActionRunning = false
    private(set) var prefetchedItemIDs = Set<AnyHashable>()
    private(set) var registeredCellKeys = Set<LKCellRegistrationKey>()
    private(set) var registeredHeaderKeys = Set<LKSupplementaryRegistrationKey>()
    private(set) var registeredFooterKeys = Set<LKSupplementaryRegistrationKey>()
    private(set) var itemSizeStorage = [LKItemSizeKey: CGSize]()
    private(set) var supplementarySizeStorage = [LKSupplementarySizeKey: CGSize]()
    private(set) var lastReconfiguredItemIdentifiers = [LKItemIdentifier]()
    private(set) var lastDifferenceKitChangesetCount = 0
    private(set) var didFallbackFromDifferenceKit = false
    private var hasAppliedCurrentModel = false
    private var isUpdating = false
    private var queuedUpdate: LKListModel?
    private var defersSelectionBindingUpdatesForApply = false
    private let updateEngine: LKUpdateEngine
    private let updateCoordinator: LKUpdateCoordinator
    private var diffableDataSource: UICollectionViewDiffableDataSource<LKSectionIdentifier, LKItemIdentifier>?
    var reloadDataHandler: (() -> Void)?
    var diffableApplyCompletionHandler: (() -> Void)?
    var differenceKitApplyCompletionHandler: (() -> Void)?
    var focusRestorationHandler: (() -> Void)? {
        get { updateCoordinator.focusRestorationHandler }
        set { updateCoordinator.focusRestorationHandler = newValue }
    }

    init(
        collectionView: UICollectionView,
        model: LKListModel = .empty,
        listEvents: LKListEvents = LKListEvents(),
        selectionConfiguration: LKSelectionConfiguration = LKSelectionConfiguration(),
        scrollConfiguration: LKScrollConfiguration = LKScrollConfiguration(),
        refreshConfiguration: LKRefreshConfiguration = LKRefreshConfiguration(),
        diagnosticsMode: LKListKitDiagnosticsMode = .disabled,
        updateEngine: LKUpdateEngine = .differenceKit
    ) {
        self.collectionView = collectionView
        self.currentModel = model
        self.currentModelIndex = nil
        self.listEvents = listEvents
        self.selectionConfiguration = selectionConfiguration
        self.scrollConfiguration = scrollConfiguration
        self.refreshConfiguration = refreshConfiguration
        self.diagnosticsMode = diagnosticsMode
        self.updateEngine = updateEngine
        self.updateCoordinator = LKUpdateCoordinator(engine: updateEngine)
        super.init()
        collectionView.delegate = self
        configurePrefetchBehavior(on: collectionView)
        configureSelectionBehavior(on: collectionView)
        configureScrollBehavior(on: collectionView)
        configureRefreshControl(on: collectionView)
        if updateEngine == .diffableDataSource {
            configureDiffableDataSource(on: collectionView)
        } else {
            collectionView.dataSource = self
        }
        registerReuseIdentifiersIfNeeded(from: model)
    }

    func apply(
        _ model: LKListModel,
        listEvents: LKListEvents? = nil,
        selectionConfiguration: LKSelectionConfiguration? = nil,
        scrollConfiguration: LKScrollConfiguration? = nil,
        refreshConfiguration: LKRefreshConfiguration? = nil,
        diagnosticsMode: LKListKitDiagnosticsMode? = nil,
        deferSelectionBindingUpdates: Bool = false
    ) {
        let previousDeferral = defersSelectionBindingUpdatesForApply
        defersSelectionBindingUpdatesForApply = deferSelectionBindingUpdates
        if let listEvents {
            self.listEvents = listEvents
        }
        if let selectionConfiguration {
            self.selectionConfiguration = selectionConfiguration
        }
        if let scrollConfiguration {
            self.scrollConfiguration = scrollConfiguration
        }
        if let refreshConfiguration {
            self.refreshConfiguration = refreshConfiguration
        }
        if let diagnosticsMode {
            self.diagnosticsMode = diagnosticsMode
        }
        configureSelectionBehavior(on: collectionView)
        configureScrollBehavior(on: collectionView)
        configureRefreshControl(on: collectionView)
        configurePrefetchBehavior(on: collectionView)
        emitApplyWarnings(for: model)

        if model == currentModel, hasAppliedCurrentModel {
            synchronizeSelectionAfterApply()
            prunePrefetchCache()
            defersSelectionBindingUpdatesForApply = false
            return
        }

        guard isUpdating == false else {
            queuedUpdate = model
            defersSelectionBindingUpdatesForApply = previousDeferral
            return
        }

        isUpdating = true

        switch updateEngine {
        case .diffableDataSource:
            applyDiffableDataSource(model)
        case .differenceKit:
            applyDifferenceKit(model)
        case .reloadData:
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
            synchronizeSelectionAfterApply()
            prunePrefetchCache()
            finishApply()
        }
    }

    private func finishApply() {
        hasAppliedCurrentModel = true
        isUpdating = false
        defersSelectionBindingUpdatesForApply = false

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

    private func emitApplyWarnings(for model: LKListModel) {
        guard diagnosticsMode == .enabled else {
            return
        }

        for warning in model.validationWarnings() {
            emitWarning(LKListKitWarning(warning))
        }

        for section in model.sections {
            let columns: Int?
            switch section.layout {
            case let .grid(gridColumns, _):
                columns = gridColumns
            case let .fixedGrid(gridColumns, _, _, _):
                columns = gridColumns
            default:
                columns = nil
            }
            guard let columns, columns < 1 else {
                continue
            }
            emitWarning(
                .unsupportedLayout(
                    sectionID: section.id,
                    reason: "Grid layout requires at least one column. ListKit will clamp the column count to 1."
                )
            )
        }
    }

    private func emitWarning(_ warning: LKListKitWarning) {
        guard diagnosticsMode == .enabled else {
            return
        }
        listEvents.didEmitWarning?(warning)
    }

    private func applyDifferenceKit(_ model: LKListModel) {
        model.validateForApply()
        let previousModel = currentModel
        let selectedItemIDs = selectedItemIDs(in: collectionView, model: previousModel)

        if previousModel.sections.isEmpty {
            applyDifferenceKitReloadData(
                model,
                selectedItemIDs: selectedItemIDs,
                didFallback: false
            )
            return
        }

        if let appendOnlyUpdate = appendOnlyUpdate(from: previousModel, to: model) {
            applyDifferenceKitAppendOnly(
                model,
                appendOnlyUpdate: appendOnlyUpdate,
                selectedItemIDs: selectedItemIDs
            )
            return
        }

        if shouldReloadForLargeReorder(from: previousModel, to: model) {
            applyDifferenceKitReloadData(
                model,
                selectedItemIDs: selectedItemIDs,
                didFallback: true
            )
            return
        }

        let source = previousModel.differenceKitSections
        let target = model.differenceKitSections
        let stagedChangeset = StagedChangeset(source: source, target: target)

        lastDifferenceKitChangesetCount = stagedChangeset.reduce(0) { count, changeset in
            count + changeset.changeCount
        }
        didFallbackFromDifferenceKit = false

        registerReuseIdentifiersIfNeeded(from: model)

        guard let collectionView, stagedChangeset.isEmpty == false else {
            currentModel = model
            collectionView?.reloadData()
            restoreSelection(selectedItemIDs, in: collectionView)
            synchronizeSelectionAfterApply()
            prunePrefetchCache()
            restoreFocus(in: collectionView)
            differenceKitApplyCompletionHandler?()
            finishApply()
            return
        }

        let interrupt: (Changeset<[LKDifferenceKitSection]>) -> Bool = { changeset in
            let visibleCapacity = max(collectionView.numberOfSections, 1)
                * max(collectionView.bounds.height > 0 ? Int(collectionView.bounds.height / 20) : 1, 1)
            return changeset.changeCount > max(visibleCapacity * 8, 500)
        }

        collectionView.lkReload(
            using: stagedChangeset,
            interrupt: { [weak self] changeset in
                let shouldInterrupt = interrupt(changeset)
                if shouldInterrupt {
                    self?.didFallbackFromDifferenceKit = true
                }
                return shouldInterrupt
            },
            setData: { [weak self] data in
                self?.currentModel = LKListModel(differenceKitSections: data)
            },
            reconfigureUpdatedItems: true
        )

        if didFallbackFromDifferenceKit {
            currentModel = model
            emitWarning(
                .diffFailure(
                    engine: .differenceKit,
                    reason: "DifferenceKit changeset exceeded the animated update threshold and fell back to reload data."
                )
            )
        }
        restoreSelection(selectedItemIDs, in: collectionView)
        synchronizeSelectionAfterApply()
        prunePrefetchCache()
        restoreFocus(in: collectionView)
        differenceKitApplyCompletionHandler?()
        finishApply()
    }

    private func applyDifferenceKitAppendOnly(
        _ model: LKListModel,
        appendOnlyUpdate: LKAppendOnlyUpdate,
        selectedItemIDs: [AnyHashable]
    ) {
        lastDifferenceKitChangesetCount = appendOnlyUpdate.insertedIndexPaths.count
        didFallbackFromDifferenceKit = false
        registerReuseIdentifiersForInsertedItems(from: model, appendOnlyUpdate: appendOnlyUpdate)

        guard let collectionView, appendOnlyUpdate.insertedIndexPaths.isEmpty == false else {
            currentModel = model
            collectionView?.reloadData()
            restoreSelection(selectedItemIDs, in: collectionView)
            synchronizeSelectionAfterApply()
            prunePrefetchCache()
            restoreFocus(in: collectionView)
            differenceKitApplyCompletionHandler?()
            finishApply()
            return
        }

        collectionView.performBatchUpdates {
            currentModel = model
            collectionView.insertItems(at: appendOnlyUpdate.insertedIndexPaths)
        } completion: { [weak self] _ in
            guard let self else { return }
            self.restoreSelection(selectedItemIDs, in: collectionView)
            self.synchronizeSelectionAfterApply()
            self.prunePrefetchCache()
            self.restoreFocus(in: collectionView)
            self.differenceKitApplyCompletionHandler?()
            self.finishApply()
        }
    }

    private func applyDifferenceKitReloadData(
        _ model: LKListModel,
        selectedItemIDs: [AnyHashable],
        didFallback: Bool
    ) {
        lastDifferenceKitChangesetCount = 0
        didFallbackFromDifferenceKit = didFallback
        registerReuseIdentifiersIfNeeded(from: model)
        currentModel = model
        collectionView?.reloadData()
        restoreSelection(selectedItemIDs, in: collectionView)
        synchronizeSelectionAfterApply()
        prunePrefetchCache()
        restoreFocus(in: collectionView)
        differenceKitApplyCompletionHandler?()
        finishApply()
    }

    func recordItemSize(_ size: CGSize, item: LKItemModel, sectionID: AnyHashable) {
        let key = LKItemSizeKey(
            sectionID: sectionID,
            itemID: item.id,
            contentToken: item.contentToken
        )
        itemSizeStorage[key] = size
    }

    func recordSupplementarySize(
        _ size: CGSize,
        kind: String,
        supplementary: LKSupplementaryModel,
        sectionID: AnyHashable
    ) {
        let key = LKSupplementarySizeKey(
            kind: kind,
            sectionID: sectionID,
            supplementaryID: supplementary.id,
            contentToken: supplementary.contentToken
        )
        supplementarySizeStorage[key] = size
    }

    func registerReuseIdentifiersIfNeeded(from model: LKListModel) {
        registerReuseIdentifiersIfNeeded(from: LKRegistrationSummary(model: model))
    }

    private func registerReuseIdentifiersIfNeeded(from summary: LKRegistrationSummary) {
        guard let collectionView else {
            return
        }

        for descriptor in summary.cellDescriptors {
            let key = LKCellRegistrationKey(
                reuseIdentifier: descriptor.reuseIdentifier,
                hostingStrategy: descriptor.hostingStrategy
            )
            guard registeredCellKeys.insert(key).inserted else { continue }
            collectionView.register(
                LKHostingCollectionViewCell.self,
                forCellWithReuseIdentifier: key.reuseIdentifier
            )
        }

        for descriptor in summary.headerDescriptors {
            let key = LKSupplementaryRegistrationKey(
                kind: supplementaryElementKind(for: descriptor.kind),
                reuseIdentifier: descriptor.reuseIdentifier,
                hostingStrategy: descriptor.hostingStrategy
            )
            guard registeredHeaderKeys.insert(key).inserted else { continue }
            collectionView.register(
                LKHostingSupplementaryView.self,
                forSupplementaryViewOfKind: key.kind,
                withReuseIdentifier: key.reuseIdentifier
            )
        }

        for descriptor in summary.footerDescriptors {
            let key = LKSupplementaryRegistrationKey(
                kind: supplementaryElementKind(for: descriptor.kind),
                reuseIdentifier: descriptor.reuseIdentifier,
                hostingStrategy: descriptor.hostingStrategy
            )
            guard registeredFooterKeys.insert(key).inserted else { continue }
            collectionView.register(
                LKHostingSupplementaryView.self,
                forSupplementaryViewOfKind: key.kind,
                withReuseIdentifier: key.reuseIdentifier
            )
        }

    }

    private func supplementaryElementKind(for kind: LKSupplementaryKind) -> String {
        switch kind {
        case .header:
            UICollectionView.elementKindSectionHeader
        case .footer:
            UICollectionView.elementKindSectionFooter
        case .custom(let kind):
            kind
        }
    }

    private func registerReuseIdentifiersForInsertedItems(
        from model: LKListModel,
        appendOnlyUpdate: LKAppendOnlyUpdate
    ) {
        guard let collectionView else {
            return
        }

        var cellKeys = Set<LKCellRegistrationKey>()
        for indexPath in appendOnlyUpdate.insertedIndexPaths {
            guard let item = model.item(at: indexPath) else {
                continue
            }
            cellKeys.insert(
                LKCellRegistrationKey(
                    reuseIdentifier: item.reuseIdentifier,
                    hostingStrategy: item.hostingStrategy
                )
            )
        }

        for key in cellKeys where registeredCellKeys.insert(key).inserted {
            collectionView.register(
                LKHostingCollectionViewCell.self,
                forCellWithReuseIdentifier: key.reuseIdentifier
            )
        }
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

        if previousModel.sections.isEmpty {
            applyDiffableReloadData(model, selectedItemIDs: selectedItemIDs)
            return
        }

        if let appendOnlyUpdate = appendOnlyUpdate(from: previousModel, to: model),
           applyDiffableAppendOnly(
                model,
                appendOnlyUpdate: appendOnlyUpdate,
                selectedItemIDs: selectedItemIDs
           ) {
            return
        }

        if shouldReloadForLargeReorder(from: previousModel, to: model) {
            applyDiffableReloadData(model, selectedItemIDs: selectedItemIDs)
            return
        }

        let changedItems = changedContentItemIdentifiers(
            from: previousModel,
            to: model
        )

        registerReuseIdentifiersIfNeeded(from: LKRegistrationSummary(model: model))
        currentModel = model

        var snapshot = makeDiffableSnapshot(for: model)
        lastReconfiguredItemIdentifiers = changedItems
        if changedItems.isEmpty == false {
            snapshot.reconfigureItems(changedItems)
        }

        let shouldAnimate = collectionView?.window != nil
        diffableDataSource?.apply(snapshot, animatingDifferences: shouldAnimate) { [weak self] in
            guard let self else { return }
            self.restoreSelection(selectedItemIDs, in: self.collectionView)
            self.synchronizeSelectionAfterApply()
            self.prunePrefetchCache()
            self.restoreFocus(in: self.collectionView)
            self.diffableApplyCompletionHandler?()
            self.finishApply()
        }
    }

    private func applyDiffableReloadData(
        _ model: LKListModel,
        selectedItemIDs: [AnyHashable]
    ) {
        guard let diffableDataSource else {
            return
        }

        registerReuseIdentifiersIfNeeded(from: model)
        currentModel = model
        lastReconfiguredItemIdentifiers = []

        let snapshot = makeDiffableSnapshot(for: model)
        diffableDataSource.applySnapshotUsingReloadData(snapshot) { [weak self] in
            guard let self else { return }
            self.restoreSelection(selectedItemIDs, in: self.collectionView)
            self.synchronizeSelectionAfterApply()
            self.prunePrefetchCache()
            self.restoreFocus(in: self.collectionView)
            self.diffableApplyCompletionHandler?()
            self.finishApply()
        }
    }

    private func makeDiffableSnapshot(
        for model: LKListModel
    ) -> NSDiffableDataSourceSnapshot<LKSectionIdentifier, LKItemIdentifier> {
        var snapshot = NSDiffableDataSourceSnapshot<LKSectionIdentifier, LKItemIdentifier>()
        for section in model.sections {
            let sectionIdentifier = LKSectionIdentifier(section)
            snapshot.appendSections([sectionIdentifier])
            snapshot.appendItems(
                section.items.map { LKItemIdentifier(section: section, item: $0) },
                toSection: sectionIdentifier
            )
        }
        return snapshot
    }

    private func applyDiffableAppendOnly(
        _ model: LKListModel,
        appendOnlyUpdate: LKAppendOnlyUpdate,
        selectedItemIDs: [AnyHashable]
    ) -> Bool {
        guard let diffableDataSource else {
            return false
        }

        var snapshot = diffableDataSource.snapshot()
        guard snapshot.sectionIdentifiers.count == model.sections.count else {
            return false
        }

        var insertedIdentifiersBySection = [(LKSectionIdentifier, [LKItemIdentifier])]()

        for indexPath in appendOnlyUpdate.insertedIndexPaths {
            guard
                let sectionIndex = indexPath.lkSection,
                let section = model.section(at: sectionIndex),
                let item = model.item(at: indexPath)
            else {
                return false
            }

            let sectionIdentifier = LKSectionIdentifier(section)
            guard snapshot.indexOfSection(sectionIdentifier) != nil else {
                return false
            }
            let itemIdentifier = LKItemIdentifier(section: section, item: item)
            if insertedIdentifiersBySection.last?.0 == sectionIdentifier {
                insertedIdentifiersBySection[insertedIdentifiersBySection.count - 1].1.append(itemIdentifier)
            } else {
                insertedIdentifiersBySection.append((sectionIdentifier, [itemIdentifier]))
            }
        }

        registerReuseIdentifiersForInsertedItems(from: model, appendOnlyUpdate: appendOnlyUpdate)
        currentModel = model
        lastReconfiguredItemIdentifiers = []

        for (sectionIdentifier, itemIdentifiers) in insertedIdentifiersBySection {
            snapshot.appendItems(itemIdentifiers, toSection: sectionIdentifier)
        }

        let shouldAnimate = shouldAnimateAppend(insertedItemCount: appendOnlyUpdate.insertedIndexPaths.count)
        diffableDataSource.apply(snapshot, animatingDifferences: shouldAnimate) { [weak self] in
            guard let self else { return }
            self.restoreSelection(selectedItemIDs, in: self.collectionView)
            self.synchronizeSelectionAfterApply()
            self.prunePrefetchCache()
            self.restoreFocus(in: self.collectionView)
            self.diffableApplyCompletionHandler?()
            self.finishApply()
        }
        return true
    }

    private func makeCell(
        _ collectionView: UICollectionView,
        at indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard
            let sectionIndex = indexPath.lkSection,
            let section = currentModel.section(at: sectionIndex),
            let item = currentModel.item(at: indexPath)
        else {
            return UICollectionViewCell()
        }

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: item.reuseIdentifier,
            for: indexPath
        )
        (cell as? LKHostingCollectionViewCell)?.render(
            item: item,
            indexPath: indexPath,
            sectionID: section.id
        ) { [weak self] size in
            self?.recordItemSize(size, item: item, sectionID: section.id)
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

        guard
            let sectionIndex = indexPath.lkSection,
            let section = currentModel.section(at: sectionIndex),
            let supplementary = currentModel.supplementary(kind: supplementaryKind, at: indexPath)
        else {
            collectionView.register(
                UICollectionReusableView.self,
                forSupplementaryViewOfKind: kind,
                withReuseIdentifier: lkEmptySupplementaryReuseIdentifier
            )
            return collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: lkEmptySupplementaryReuseIdentifier,
                for: indexPath
            )
        }

        let view = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: supplementary.reuseIdentifier,
            for: indexPath
        )
        (view as? LKHostingSupplementaryView)?.render(supplementary: supplementary) { [weak self] size in
            self?.recordSupplementarySize(
                size,
                kind: kind,
                supplementary: supplementary,
                sectionID: section.id
            )
        }
        return view
    }

    private func changedContentItemIdentifiers(
        from oldModel: LKListModel,
        to newModel: LKListModel
    ) -> [LKItemIdentifier] {
        guard oldModel.hasAnyContentToken || newModel.hasAnyContentToken else {
            return []
        }

        let oldModelIndex = LKListContentTokenIndex(model: oldModel)
        var changedItems = [LKItemIdentifier]()

        for section in newModel.sections {
            for item in section.items {
                let identity = LKModelItemIdentity(
                    sectionID: section.id,
                    itemID: item.id
                )
                guard
                    oldModelIndex.containsItem(identity),
                    oldModelIndex.contentToken(for: identity) != item.contentToken
                else {
                    continue
                }
                changedItems.append(LKItemIdentifier(sectionID: section.id, itemID: item.id))
            }
        }

        return changedItems
    }

    private func appendOnlyUpdate(from oldModel: LKListModel, to newModel: LKListModel) -> LKAppendOnlyUpdate? {
        guard oldModel.sections.count == newModel.sections.count else {
            return nil
        }

        var insertedIndexPaths = [IndexPath]()
        insertedIndexPaths.reserveCapacity(max(newModel.itemCount - oldModel.itemCount, 0))

        for sectionIndex in oldModel.sections.indices {
            let oldSection = oldModel.sections[sectionIndex]
            let newSection = newModel.sections[sectionIndex]

            guard
                oldSection.matchesAppendOnlyMetadata(of: newSection),
                oldSection.matchesAppendOnlyPrefix(of: newSection)
            else {
                return nil
            }

            for itemIndex in oldSection.items.count..<newSection.items.count {
                insertedIndexPaths.append(IndexPath.lkIndexPath(item: itemIndex, section: sectionIndex))
            }
        }

        return insertedIndexPaths.isEmpty ? nil : LKAppendOnlyUpdate(insertedIndexPaths: insertedIndexPaths)
    }

    private func shouldReloadForLargeReorder(from oldModel: LKListModel, to newModel: LKListModel) -> Bool {
        guard let movedItemCount = movedItemCountIfReorderOnly(from: oldModel, to: newModel) else {
            return false
        }
        return movedItemCount > largeUpdateThreshold()
    }

    private func movedItemCountIfReorderOnly(from oldModel: LKListModel, to newModel: LKListModel) -> Int? {
        guard oldModel.sections.count == newModel.sections.count else {
            return nil
        }

        var movedItemCount = 0

        for sectionIndex in oldModel.sections.indices {
            let oldSection = oldModel.sections[sectionIndex]
            let newSection = newModel.sections[sectionIndex]

            guard
                oldSection.matchesAppendOnlyMetadata(of: newSection),
                oldSection.items.count == newSection.items.count
            else {
                return nil
            }

            let oldIDs = oldSection.items.map(\.id)
            let newIDs = newSection.items.map(\.id)

            guard oldIDs != newIDs else {
                continue
            }

            guard Set(oldIDs) == Set(newIDs) else {
                return nil
            }

            movedItemCount += zip(oldIDs, newIDs).filter { $0 != $1 }.count
        }

        return movedItemCount == 0 ? nil : movedItemCount
    }

    private func largeUpdateThreshold() -> Int {
        guard let collectionView else {
            return 500
        }
        let visibleCapacity = max(collectionView.numberOfSections, 1)
            * max(collectionView.bounds.height > 0 ? Int(collectionView.bounds.height / 20) : 1, 1)
        return max(visibleCapacity * 8, 500)
    }

    private func animatedAppendThreshold() -> Int {
        guard let collectionView else {
            return 100
        }
        let visibleCapacity = max(collectionView.numberOfSections, 1)
            * max(collectionView.bounds.height > 0 ? Int(collectionView.bounds.height / 20) : 1, 1)
        return max(visibleCapacity * 2, 100)
    }

    private func shouldAnimateAppend(insertedItemCount: Int) -> Bool {
        collectionView?.window != nil && insertedItemCount <= animatedAppendThreshold()
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
        in collectionView: UICollectionView?
    ) {
        guard let collectionView, selectedItemIDs.isEmpty == false else {
            return
        }

        let modelIndex = modelIndexForCurrentModel()
        for itemID in selectedItemIDs {
            guard let indexPath = modelIndex.indexPath(forItemID: itemID) else {
                continue
            }
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
    }

    private func configureSelectionBehavior(on collectionView: UICollectionView?) {
        guard let collectionView else {
            return
        }

        switch selectionConfiguration.mode {
        case .none:
            collectionView.allowsSelection = false
            collectionView.allowsMultipleSelection = false
        case .single:
            collectionView.allowsSelection = true
            collectionView.allowsMultipleSelection = false
        case .multiple:
            collectionView.allowsSelection = true
            collectionView.allowsMultipleSelection = true
        }
    }

    private func synchronizeSelectionAfterApply() {
        guard let collectionView else {
            return
        }

        if selectionConfiguration.mode == .none {
            clearSelection(in: collectionView)
            if selectionConfiguration.hasBinding,
               selectionConfiguration.selectedIDs().isEmpty == false {
                updateSelectionBinding(
                    with: [],
                    deferring: defersSelectionBindingUpdatesForApply,
                    replacingCurrentIDs: selectionConfiguration.selectedIDs()
                )
            }
            return
        }

        guard selectionConfiguration.hasBinding else {
            return
        }

        let currentIDs = selectionConfiguration.selectedIDs()
        let selectedIDs = normalizedSelectionIDs(currentIDs)
        applySelection(selectedIDs, to: collectionView)
        if selectionIDs(currentIDs, areEquivalentTo: selectedIDs) == false {
            updateSelectionBinding(
                with: selectedIDs,
                deferring: defersSelectionBindingUpdatesForApply,
                replacingCurrentIDs: currentIDs
            )
        }
    }

    private func updateSelectionBindingAfterUserSelect(itemID: AnyHashable) {
        guard selectionConfiguration.hasBinding else {
            return
        }

        let currentIDs = normalizedSelectionIDs(selectionConfiguration.selectedIDs())
        let selectedIDs: [AnyHashable]
        switch selectionConfiguration.mode {
        case .none:
            selectedIDs = []
        case .single:
            selectedIDs = [itemID]
        case .multiple:
            selectedIDs = currentIDs.contains(itemID) ? currentIDs : currentIDs + [itemID]
        }
        updateSelectionBinding(with: normalizedSelectionIDs(selectedIDs), deferring: false)
    }

    private func updateSelectionBindingAfterUserDeselect(itemID: AnyHashable) {
        guard selectionConfiguration.hasBinding else {
            return
        }

        let selectedIDs = normalizedSelectionIDs(
            selectionConfiguration.selectedIDs().filter { $0 != itemID }
        )
        updateSelectionBinding(with: selectedIDs, deferring: false)
    }

    private func updateSelectionBinding(
        with selectedIDs: [AnyHashable],
        deferring: Bool,
        replacingCurrentIDs currentIDs: [AnyHashable]? = nil
    ) {
        guard selectionConfiguration.hasBinding else {
            return
        }

        if deferring {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let currentIDs,
                   self.rawSelectionIDs(
                       self.selectionConfiguration.selectedIDs(),
                       areEquivalentTo: currentIDs
                   ) == false {
                    return
                }
                self.selectionConfiguration.setSelectedIDs?(selectedIDs)
            }
        } else {
            selectionConfiguration.setSelectedIDs?(selectedIDs)
        }
    }

    private func rawSelectionIDs(
        _ lhs: [AnyHashable],
        areEquivalentTo rhs: [AnyHashable]
    ) -> Bool {
        Set(lhs) == Set(rhs)
    }

    private func selectionIDs(
        _ lhs: [AnyHashable],
        areEquivalentTo rhs: [AnyHashable]
    ) -> Bool {
        switch selectionConfiguration.mode {
        case .none:
            lhs.isEmpty && rhs.isEmpty
        case .single:
            lhs.first == rhs.first
        case .multiple:
            Set(lhs) == Set(rhs)
        }
    }

    private func normalizedSelectionIDs(_ ids: [AnyHashable]) -> [AnyHashable] {
        var seen = Set<AnyHashable>()
        var normalized = [AnyHashable]()
        let modelIndex = modelIndexForCurrentModel()

        for id in ids where seen.insert(id).inserted && modelIndex.itemIDs.contains(id) {
            normalized.append(id)
            if selectionConfiguration.mode == .single {
                break
            }
        }
        return normalized
    }

    private func prunePrefetchCache() {
        guard prefetchedItemIDs.isEmpty == false else {
            return
        }

        prefetchedItemIDs.formIntersection(modelIndexForCurrentModel().itemIDs)
    }

    private func applySelection(
        _ selectedIDs: [AnyHashable],
        to collectionView: UICollectionView
    ) {
        clearSelection(in: collectionView)
        let modelIndex = modelIndexForCurrentModel()
        for id in selectedIDs {
            guard let indexPath = modelIndex.indexPath(forItemID: id) else {
                continue
            }
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
    }

    private func clearSelection(in collectionView: UICollectionView) {
        collectionView.indexPathsForSelectedItems?.forEach {
            collectionView.deselectItem(at: $0, animated: false)
        }
    }

    private func configureScrollBehavior(on collectionView: UICollectionView?) {
        guard let collectionView else {
            return
        }

        switch scrollConfiguration.indicatorVisibility {
        case .automatic:
            collectionView.showsVerticalScrollIndicator = true
            collectionView.showsHorizontalScrollIndicator = true
        case .visible:
            collectionView.showsVerticalScrollIndicator = true
            collectionView.showsHorizontalScrollIndicator = true
        case .hidden:
            collectionView.showsVerticalScrollIndicator = false
            collectionView.showsHorizontalScrollIndicator = false
        }

        if let mode = scrollConfiguration.keyboardDismissMode,
           let keyboardDismissMode = UIScrollView.KeyboardDismissMode(rawValue: mode) {
            collectionView.keyboardDismissMode = keyboardDismissMode
        }

        if let contentInsets = scrollConfiguration.contentInsets {
            collectionView.contentInset = UIEdgeInsets(
                top: contentInsets.top,
                left: contentInsets.left,
                bottom: contentInsets.bottom,
                right: contentInsets.right
            )
        }
    }

    private func scrollContext(for scrollView: UIScrollView) -> LKScrollContext {
        let adjustedInset = scrollView.adjustedContentInset
        return LKScrollContext(
            contentOffset: scrollView.contentOffset,
            contentSize: scrollView.contentSize,
            boundsSize: scrollView.bounds.size,
            adjustedContentInset: LKEdgeInsets(
                top: adjustedInset.top,
                left: adjustedInset.left,
                bottom: adjustedInset.bottom,
                right: adjustedInset.right
            )
        )
    }

    private func evaluateReachEnd(using scrollView: UIScrollView) {
        guard
            let threshold = scrollConfiguration.reachEndThreshold,
            let didReachEnd = listEvents.didReachEnd
        else {
            return
        }

        let visibleMaxY = scrollView.contentOffset.y
            + scrollView.bounds.height
            - scrollView.adjustedContentInset.top
            - scrollView.adjustedContentInset.bottom
        let reachY = scrollView.contentSize.height - threshold.points
        let isAtEnd = visibleMaxY >= reachY
        let contentSizeChanged = lastReachEndContentSize != scrollView.contentSize

        if isAtEnd, isReachEndArmed || contentSizeChanged {
            didReachEnd()
            isReachEndArmed = false
            lastReachEndContentSize = scrollView.contentSize
        } else if isAtEnd == false {
            isReachEndArmed = true
        }
    }

    private func configureRefreshControl(on collectionView: UICollectionView?) {
        guard let collectionView else {
            return
        }

        guard refreshConfiguration.isEnabled else {
            collectionView.refreshControl = nil
            isRefreshActionRunning = false
            return
        }

        let refreshControl = collectionView.refreshControl ?? UIRefreshControl()
        refreshControl.removeTarget(self, action: #selector(refreshControlValueChanged(_:)), for: .valueChanged)
        refreshControl.addTarget(self, action: #selector(refreshControlValueChanged(_:)), for: .valueChanged)
        refreshControl.tintColor = refreshConfiguration.tintColor
        collectionView.bounces = true
        collectionView.alwaysBounceVertical = true
        collectionView.refreshControl = refreshControl
    }

    private func configurePrefetchBehavior(on collectionView: UICollectionView?) {
        guard let collectionView else {
            return
        }

        guard listEvents.hasPrefetchHandlers else {
            collectionView.prefetchDataSource = nil
            return
        }

        collectionView.prefetchDataSource = self
    }

    @objc func refreshControlValueChanged(_ refreshControl: UIRefreshControl) {
        guard
            isRefreshActionRunning == false,
            let action = refreshConfiguration.action
        else {
            return
        }

        isRefreshActionRunning = true
        Task { @MainActor [weak self, weak refreshControl] in
            await action()
            refreshControl?.endRefreshing()
            self?.isRefreshActionRunning = false
        }
    }

    private func restoreFocus(in collectionView: UICollectionView?) {
        guard focusRestorationHandler != nil || listEvents.preferredFocusedItemID != nil else {
            return
        }

        collectionView?.setNeedsFocusUpdate()
        focusRestorationHandler?()
    }

    private func modelIndexForCurrentModel() -> LKListModelIndex {
        if let currentModelIndex {
            return currentModelIndex
        }

        let modelIndex = LKListModelIndex(model: currentModel)
        currentModelIndex = modelIndex
        return modelIndex
    }

    private func itemContext(at indexPath: IndexPath) -> LKAnyItemContext? {
        guard
            let sectionIndex = indexPath.lkSection,
            let section = currentModel.section(at: sectionIndex)
        else {
            emitWarning(.invalidLookup(kind: .section, indexPath: indexPath))
            return nil
        }

        guard
            let item = currentModel.item(at: indexPath)
        else {
            emitWarning(.invalidLookup(kind: .item, indexPath: indexPath))
            return nil
        }

        return LKAnyItemContext(
            id: item.id,
            item: item.base ?? item.id,
            indexPath: indexPath,
            sectionID: section.id
        )
    }

    private func itemContexts(at indexPaths: [IndexPath]) -> [LKAnyItemContext] {
        indexPaths.compactMap { itemContext(at: $0) }
    }

    private func itemEventSources(at indexPath: IndexPath) -> (
        context: LKAnyItemContext,
        rowEvents: LKRowEvents,
        sectionEvents: LKSectionEvents
    )? {
        guard
            let context = itemContext(at: indexPath),
            let sectionIndex = indexPath.lkSection,
            let section = currentModel.section(at: sectionIndex),
            let item = currentModel.item(at: indexPath)
        else {
            return nil
        }
        return (context, item.events, section.events)
    }

    private func swipeActionsConfiguration(
        at indexPath: IndexPath,
        edge: LKSwipeActionsEdge
    ) -> UISwipeActionsConfiguration? {
        guard let sources = itemEventSources(at: indexPath) else {
            return nil
        }

        let provider: ((LKAnyItemContext) -> LKSwipeActions?)?
        switch edge {
        case .leading:
            provider = sources.rowEvents.leadingSwipeActions
                ?? sources.sectionEvents.leadingSwipeActions
                ?? listEvents.leadingSwipeActions
        case .trailing:
            provider = sources.rowEvents.trailingSwipeActions
                ?? sources.sectionEvents.trailingSwipeActions
                ?? listEvents.trailingSwipeActions
        }

        guard
            let swipeActions = provider?(sources.context),
            swipeActions.actions.isEmpty == false
        else {
            return nil
        }

        let actions = swipeActions.actions.map { action in
            let contextualAction = UIContextualAction(
                style: action.style,
                title: action.title
            ) { _, _, completion in
                action.handler(sources.context, completion)
            }
            contextualAction.image = action.image
            contextualAction.backgroundColor = action.backgroundColor
            return contextualAction
        }
        let configuration = UISwipeActionsConfiguration(actions: actions)
        configuration.performsFirstActionWithFullSwipe = swipeActions.allowsFullSwipe
        return configuration
    }

    private func supplementaryContext(kind: String, at indexPath: IndexPath) -> LKSupplementaryContext? {
        let supplementaryKind: LKSupplementaryKind

        switch kind {
        case UICollectionView.elementKindSectionHeader:
            supplementaryKind = .header
        case UICollectionView.elementKindSectionFooter:
            supplementaryKind = .footer
        default:
            supplementaryKind = .custom(kind)
        }

        guard
            let sectionIndex = indexPath.lkSection,
            let section = currentModel.section(at: sectionIndex)
        else {
            emitWarning(.invalidLookup(kind: .section, indexPath: indexPath))
            return nil
        }

        guard
            let supplementary = currentModel.supplementary(kind: supplementaryKind, at: indexPath)
        else {
            emitWarning(.invalidLookup(kind: .supplementary, indexPath: indexPath))
            return nil
        }

        return LKSupplementaryContext(
            id: supplementary.id,
            kind: supplementary.kind,
            indexPath: indexPath,
            sectionID: section.id
        )
    }
}

private extension LKListEvents {
    var hasPrefetchHandlers: Bool {
        didPrefetch != nil || didCancelPrefetch != nil
    }
}

private extension LKListModel {
    var hasAnyContentToken: Bool {
        sections.contains { section in
            section.items.contains { $0.contentToken != nil }
        }
    }
}

private extension LKListModel {
    var itemCount: Int {
        sections.reduce(0) { count, section in
            count + section.items.count
        }
    }
}

private extension LKSectionModel {
    func matchesAppendOnlyMetadata(of other: LKSectionModel) -> Bool {
        let coreMatches = id == other.id
            && header == other.header
            && footer == other.footer
            && supplementaries == other.supplementaries

        #if canImport(UIKit)
        return coreMatches
            && layout == other.layout
            && scrollAxis == other.scrollAxis
            && orthogonalScrollingBehavior == other.orthogonalScrollingBehavior
            && itemSpacing == other.itemSpacing
            && sectionContentInsets == other.sectionContentInsets
            && supplementaryContentInsetsReference == other.supplementaryContentInsetsReference
            && pinsHeader == other.pinsHeader
        #else
        return coreMatches
        #endif
    }

    func matchesAppendOnlyPrefix(of other: LKSectionModel) -> Bool {
        let oldCount = items.count
        guard oldCount <= other.items.count else {
            return false
        }

        guard oldCount > 0 else {
            return true
        }

        guard
            items[0] == other.items[0],
            items[oldCount - 1] == other.items[oldCount - 1]
        else {
            return false
        }

        if oldCount > 2 {
            for itemIndex in 1..<(oldCount - 1) where items[itemIndex] != other.items[itemIndex] {
                return false
            }
        }
        return true
    }
}

private extension UICollectionView {
    func lkReload<C>(
        using stagedChangeset: StagedChangeset<C>,
        interrupt: ((Changeset<C>) -> Bool)? = nil,
        setData: (C) -> Void,
        reconfigureUpdatedItems: Bool
    ) {
        guard stagedChangeset.isEmpty == false else {
            return
        }

        if window == nil, let data = stagedChangeset.last?.data {
            setData(data)
            reloadData()
            return
        }

        for changeset in stagedChangeset {
            if let interrupt, interrupt(changeset), let data = stagedChangeset.last?.data {
                setData(data)
                reloadData()
                return
            }

            performBatchUpdates {
                setData(changeset.data)

                if changeset.sectionDeleted.isEmpty == false {
                    deleteSections(IndexSet(changeset.sectionDeleted))
                }

                if changeset.sectionInserted.isEmpty == false {
                    insertSections(IndexSet(changeset.sectionInserted))
                }

                if changeset.sectionUpdated.isEmpty == false {
                    reloadSections(IndexSet(changeset.sectionUpdated))
                }

                for (source, target) in changeset.sectionMoved {
                    moveSection(source, toSection: target)
                }

                if changeset.elementDeleted.isEmpty == false {
                    deleteItems(
                        at: changeset.elementDeleted.map {
                            IndexPath.lkIndexPath(item: $0.element, section: $0.section)
                        }
                    )
                }

                if changeset.elementInserted.isEmpty == false {
                    insertItems(
                        at: changeset.elementInserted.map {
                            IndexPath.lkIndexPath(item: $0.element, section: $0.section)
                        }
                    )
                }

                if changeset.elementUpdated.isEmpty == false {
                    let indexPaths = changeset.elementUpdated.map {
                        IndexPath.lkIndexPath(item: $0.element, section: $0.section)
                    }
                    if reconfigureUpdatedItems {
                        reconfigureItems(at: indexPaths)
                    } else {
                        reloadItems(at: indexPaths)
                    }
                }

                for (source, target) in changeset.elementMoved {
                    moveItem(
                        at: IndexPath.lkIndexPath(item: source.element, section: source.section),
                        to: IndexPath.lkIndexPath(item: target.element, section: target.section)
                    )
                }
            }
        }
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

extension LKCollectionViewAdapter: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let contexts = itemContexts(at: indexPaths)
        guard contexts.isEmpty == false else {
            return
        }

        for context in contexts {
            prefetchedItemIDs.insert(context.id)
        }
        listEvents.didPrefetch?(contexts)
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let contexts = itemContexts(at: indexPaths)
        guard contexts.isEmpty == false else {
            return
        }

        for context in contexts {
            prefetchedItemIDs.remove(context.id)
        }
        listEvents.didCancelPrefetch?(contexts)
    }
}

extension LKCollectionViewAdapter: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard let sources = itemEventSources(at: indexPath) else {
            return true
        }
        return sources.rowEvents.shouldSelect?(sources.context)
            ?? sources.sectionEvents.shouldSelect?(sources.context)
            ?? listEvents.shouldSelect?(sources.context)
            ?? true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let sources = itemEventSources(at: indexPath) else {
            return
        }
        updateSelectionBindingAfterUserSelect(itemID: sources.context.id)
        if let handler = sources.rowEvents.didSelect
            ?? sources.sectionEvents.didSelect
            ?? listEvents.didSelect {
            handler(sources.context)
        }
    }

    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        guard let sources = itemEventSources(at: indexPath) else {
            return true
        }
        return sources.rowEvents.shouldDeselect?(sources.context)
            ?? sources.sectionEvents.shouldDeselect?(sources.context)
            ?? listEvents.shouldDeselect?(sources.context)
            ?? true
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard let sources = itemEventSources(at: indexPath) else {
            return
        }
        updateSelectionBindingAfterUserDeselect(itemID: sources.context.id)
        if let handler = sources.rowEvents.didDeselect
            ?? sources.sectionEvents.didDeselect
            ?? listEvents.didDeselect {
            handler(sources.context)
        }
    }

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        guard let sources = itemEventSources(at: indexPath) else {
            return true
        }
        return sources.rowEvents.shouldHighlight?(sources.context)
            ?? sources.sectionEvents.shouldHighlight?(sources.context)
            ?? listEvents.shouldHighlight?(sources.context)
            ?? true
    }

    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        guard let sources = itemEventSources(at: indexPath) else {
            return
        }
        if let handler = sources.rowEvents.didHighlight
            ?? sources.sectionEvents.didHighlight
            ?? listEvents.didHighlight {
            handler(sources.context)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        guard let sources = itemEventSources(at: indexPath) else {
            return
        }
        if let handler = sources.rowEvents.didUnhighlight
            ?? sources.sectionEvents.didUnhighlight
            ?? listEvents.didUnhighlight {
            handler(sources.context)
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let sources = itemEventSources(at: indexPath) else {
            return
        }
        if let handler = sources.rowEvents.willDisplay
            ?? sources.sectionEvents.willDisplay
            ?? listEvents.willDisplay {
            handler(sources.context)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let sources = itemEventSources(at: indexPath) else {
            return
        }
        if let handler = sources.rowEvents.didEndDisplaying
            ?? sources.sectionEvents.didEndDisplaying
            ?? listEvents.didEndDisplaying {
            handler(sources.context)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        leadingSwipeActionsConfigurationForItemAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        swipeActionsConfiguration(at: indexPath, edge: .leading)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        trailingSwipeActionsConfigurationForItemAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        swipeActionsConfiguration(at: indexPath, edge: .trailing)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplaySupplementaryView view: UICollectionReusableView,
        forElementKind elementKind: String,
        at indexPath: IndexPath
    ) {
        guard
            let context = supplementaryContext(kind: elementKind, at: indexPath),
            let sectionIndex = indexPath.lkSection,
            let section = currentModel.section(at: sectionIndex)
        else {
            return
        }

        switch context.kind {
        case .header:
            section.headerEvents.willDisplay?(context)
        case .footer:
            section.footerEvents.willDisplay?(context)
        case .custom:
            break
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplayingSupplementaryView view: UICollectionReusableView,
        forElementOfKind elementKind: String,
        at indexPath: IndexPath
    ) {
        guard
            let context = supplementaryContext(kind: elementKind, at: indexPath),
            let sectionIndex = indexPath.lkSection,
            let section = currentModel.section(at: sectionIndex)
        else {
            return
        }

        switch context.kind {
        case .header:
            section.headerEvents.didEndDisplaying?(context)
        case .footer:
            section.footerEvents.didEndDisplaying?(context)
        case .custom:
            break
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let context = itemContext(at: indexPath) else {
            return nil
        }
        return listEvents.uiContextMenuConfiguration?(context, point)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionCommitAnimating
    ) {
        listEvents.uiWillPerformPreviewAction?(configuration, animator)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        listEvents.uiPreviewForHighlightingContextMenu?(configuration)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        listEvents.uiPreviewForDismissingContextMenu?(configuration)
    }

    func collectionView(_ collectionView: UICollectionView, canPerformPrimaryActionForItemAt indexPath: IndexPath) -> Bool {
        guard let context = itemContext(at: indexPath) else {
            return false
        }
        return listEvents.canPerformPrimaryAction?(context) ?? true
    }

    func collectionView(_ collectionView: UICollectionView, performPrimaryActionForItemAt indexPath: IndexPath) {
        guard let context = itemContext(at: indexPath) else {
            return
        }
        listEvents.didPerformPrimaryAction?(context)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath
    ) -> Bool {
        guard let context = itemContext(at: indexPath) else {
            return false
        }
        return listEvents.shouldBeginMultipleSelectionInteraction?(context)
            ?? (selectionConfiguration.mode == .multiple)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didBeginMultipleSelectionInteractionAt indexPath: IndexPath
    ) {
        guard let context = itemContext(at: indexPath) else {
            return
        }
        listEvents.didBeginMultipleSelectionInteraction?(context)
    }

    func collectionViewDidEndMultipleSelectionInteraction(_ collectionView: UICollectionView) {
        listEvents.didEndMultipleSelectionInteraction?()
    }

    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        guard let context = itemContext(at: indexPath) else {
            return false
        }
        return listEvents.canFocus?(context) ?? true
    }

    func collectionView(
        _ collectionView: UICollectionView,
        shouldUpdateFocusIn context: UICollectionViewFocusUpdateContext
    ) -> Bool {
        listEvents.shouldUpdateFocus?(context) ?? true
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didUpdateFocusIn context: UICollectionViewFocusUpdateContext,
        with coordinator: UIFocusAnimationCoordinator
    ) {
        listEvents.didUpdateFocus?(context, coordinator)
    }

    func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
        guard let preferredFocusedItemID = listEvents.preferredFocusedItemID else {
            return nil
        }
        return modelIndexForCurrentModel().indexPath(forItemID: preferredFocusedItemID)
    }

    func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        guard let context = itemContext(at: indexPath) else {
            return false
        }
        return listEvents.shouldShowEditMenu?(context) ?? false
    }

    func collectionView(
        _ collectionView: UICollectionView,
        canPerformAction action: Selector,
        forItemAt indexPath: IndexPath,
        withSender sender: Any?
    ) -> Bool {
        guard let context = itemContext(at: indexPath) else {
            return false
        }
        return listEvents.canPerformMenuAction?(context, action, sender) ?? false
    }

    func collectionView(
        _ collectionView: UICollectionView,
        performAction action: Selector,
        forItemAt indexPath: IndexPath,
        withSender sender: Any?
    ) {
        guard let context = itemContext(at: indexPath) else {
            return
        }
        listEvents.performMenuAction?(context, action, sender)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        shouldSpringLoadItemAt indexPath: IndexPath,
        with context: UISpringLoadedInteractionContext
    ) -> Bool {
        guard let itemContext = itemContext(at: indexPath) else {
            return false
        }
        return listEvents.shouldSpringLoad?(itemContext, context) ?? true
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        listEvents.didScroll?(scrollContext(for: scrollView))
        evaluateReachEnd(using: scrollView)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        listEvents.willBeginDragging?(scrollContext(for: scrollView))
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        listEvents.willEndDragging?(scrollContext(for: scrollView))
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        listEvents.didEndDragging?(scrollContext(for: scrollView))
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        listEvents.willBeginDecelerating?(scrollContext(for: scrollView))
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        listEvents.didEndDecelerating?(scrollContext(for: scrollView))
    }

    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        listEvents.shouldScrollToTop?(scrollContext(for: scrollView)) ?? true
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        listEvents.didScrollToTop?(scrollContext(for: scrollView))
    }
}

extension LKCollectionViewAdapter: LKListScrollControlling {
    func scrollToTop(animated: Bool) {
        guard let collectionView else {
            return
        }

        collectionView.setContentOffset(
            CGPoint(
                x: collectionView.contentOffset.x,
                y: -collectionView.adjustedContentInset.top
            ),
            animated: animated
        )
    }

    func scrollToOffset(_ offset: CGPoint, animated: Bool) {
        collectionView?.setContentOffset(offset, animated: animated)
    }

    func scrollToItem(
        id: AnyHashable,
        sectionID: AnyHashable?,
        position: LKScrollPosition,
        animated: Bool
    ) -> Bool {
        guard let collectionView, let indexPath = indexPath(forItemID: id, sectionID: sectionID) else {
            return false
        }

        collectionView.scrollToItem(
            at: indexPath,
            at: position.collectionViewScrollPosition,
            animated: animated
        )
        return true
    }

    func scrollToSection(
        id: AnyHashable,
        position: LKScrollPosition,
        animated: Bool
    ) -> Bool {
        guard
            let collectionView,
            let sectionIndex = currentModel.sections.firstIndex(where: { $0.id == id })
        else {
            return false
        }

        let section = currentModel.sections[sectionIndex]
        if let firstItem = section.items.first {
            return scrollToItem(
                id: firstItem.id,
                sectionID: id,
                position: position,
                animated: animated
            )
        }

        guard section.header != nil else {
            return false
        }

        collectionView.layoutIfNeeded()
        let indexPath = IndexPath.lkIndexPath(item: 0, section: sectionIndex)
        guard let attributes = collectionView.collectionViewLayout.layoutAttributesForSupplementaryView(
            ofKind: UICollectionView.elementKindSectionHeader,
            at: indexPath
        ) else {
            return false
        }

        collectionView.setContentOffset(
            targetContentOffset(for: attributes.frame, position: position, in: collectionView),
            animated: animated
        )
        return true
    }

    private func indexPath(forItemID itemID: AnyHashable, sectionID: AnyHashable?) -> IndexPath? {
        if let sectionID {
            for sectionIndex in currentModel.sections.indices {
                let section = currentModel.sections[sectionIndex]
                guard section.id == sectionID else {
                    continue
                }

                for itemIndex in section.items.indices where section.items[itemIndex].id == itemID {
                    return IndexPath.lkIndexPath(item: itemIndex, section: sectionIndex)
                }
            }
            return nil
        }

        return modelIndexForCurrentModel().indexPath(forItemID: itemID)
    }

    private func targetContentOffset(
        for rect: CGRect,
        position: LKScrollPosition,
        in collectionView: UICollectionView
    ) -> CGPoint {
        switch position {
        case .top:
            return CGPoint(
                x: collectionView.contentOffset.x,
                y: rect.minY - collectionView.adjustedContentInset.top
            )
        case .centeredVertically:
            return CGPoint(
                x: collectionView.contentOffset.x,
                y: rect.midY - collectionView.bounds.height / 2
            )
        case .bottom:
            return CGPoint(
                x: collectionView.contentOffset.x,
                y: rect.maxY - collectionView.bounds.height + collectionView.adjustedContentInset.bottom
            )
        case .left:
            return CGPoint(
                x: rect.minX - collectionView.adjustedContentInset.left,
                y: collectionView.contentOffset.y
            )
        case .centeredHorizontally:
            return CGPoint(
                x: rect.midX - collectionView.bounds.width / 2,
                y: collectionView.contentOffset.y
            )
        case .right:
            return CGPoint(
                x: rect.maxX - collectionView.bounds.width + collectionView.adjustedContentInset.right,
                y: collectionView.contentOffset.y
            )
        }
    }
}
#endif
