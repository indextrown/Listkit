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

struct LKSupplementarySizeKey: Hashable {
    let kind: String
    let indexPath: IndexPath
}

private let lkEmptySupplementaryReuseIdentifier = "ListKit.EmptySupplementaryView"

@MainActor
final class LKCollectionViewAdapter: NSObject {
    private weak var collectionView: UICollectionView?
    private(set) var currentModel: LKListModel
    private var listEvents: LKListEvents
    private var selectionConfiguration: LKSelectionConfiguration
    private var scrollConfiguration: LKScrollConfiguration
    private var refreshConfiguration: LKRefreshConfiguration
    private var isReachEndArmed = true
    private var lastReachEndContentSize: CGSize?
    private var isRefreshActionRunning = false
    private(set) var registeredCellKeys = Set<LKCellRegistrationKey>()
    private(set) var registeredHeaderKeys = Set<LKSupplementaryRegistrationKey>()
    private(set) var registeredFooterKeys = Set<LKSupplementaryRegistrationKey>()
    private(set) var itemSizeStorage = [IndexPath: CGSize]()
    private(set) var supplementarySizeStorage = [LKSupplementarySizeKey: CGSize]()
    private(set) var lastReconfiguredItemIdentifiers = [LKItemIdentifier]()
    private(set) var lastDifferenceKitChangesetCount = 0
    private(set) var didFallbackFromDifferenceKit = false
    private var isUpdating = false
    private var queuedUpdate: LKListModel?
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
        updateEngine: LKUpdateEngine = .reloadData
    ) {
        self.collectionView = collectionView
        self.currentModel = model
        self.listEvents = listEvents
        self.selectionConfiguration = selectionConfiguration
        self.scrollConfiguration = scrollConfiguration
        self.refreshConfiguration = refreshConfiguration
        self.updateEngine = updateEngine
        self.updateCoordinator = LKUpdateCoordinator(engine: updateEngine)
        super.init()
        collectionView.delegate = self
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
        refreshConfiguration: LKRefreshConfiguration? = nil
    ) {
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
        configureSelectionBehavior(on: collectionView)
        configureScrollBehavior(on: collectionView)
        configureRefreshControl(on: collectionView)

        guard isUpdating == false else {
            queuedUpdate = model
            return
        }

        isUpdating = true

        switch updateEngine {
        case .diffableDataSource:
            applyDiffableDataSource(model)
        case .differenceKit:
            applyDifferenceKit(model)
            synchronizeSelectionAfterApply(model: currentModel)
            finishApply()
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
            synchronizeSelectionAfterApply(model: currentModel)
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

    private func applyDifferenceKit(_ model: LKListModel) {
        model.validateForApply()
        let previousModel = currentModel
        let selectedItemIDs = selectedItemIDs(in: collectionView, model: previousModel)
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
            restoreSelection(selectedItemIDs, in: collectionView, model: model)
            synchronizeSelectionAfterApply(model: model)
            restoreFocus(in: collectionView)
            differenceKitApplyCompletionHandler?()
            return
        }

        let interrupt: (Changeset<[LKDifferenceKitSection]>) -> Bool = { changeset in
            let visibleCapacity = max(collectionView.numberOfSections, 1)
                * max(collectionView.bounds.height > 0 ? Int(collectionView.bounds.height / 20) : 1, 1)
            return changeset.changeCount > max(visibleCapacity * 8, 500)
        }

        collectionView.reload(
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
            }
        )

        if didFallbackFromDifferenceKit {
            currentModel = model
        }
        restoreSelection(selectedItemIDs, in: collectionView, model: currentModel)
        restoreFocus(in: collectionView)
        differenceKitApplyCompletionHandler?()
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
            self.synchronizeSelectionAfterApply(model: model)
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

    private func synchronizeSelectionAfterApply(model: LKListModel) {
        guard let collectionView else {
            return
        }

        if selectionConfiguration.mode == .none {
            clearSelection(in: collectionView)
            if selectionConfiguration.hasBinding {
                selectionConfiguration.setSelectedIDs?([])
            }
            return
        }

        guard selectionConfiguration.hasBinding else {
            return
        }

        let selectedIDs = normalizedSelectionIDs(selectionConfiguration.selectedIDs(), model: model)
        applySelection(selectedIDs, to: collectionView, model: model)
        selectionConfiguration.setSelectedIDs?(selectedIDs)
    }

    private func updateSelectionBindingAfterUserSelect(itemID: AnyHashable) {
        guard selectionConfiguration.hasBinding else {
            return
        }

        let currentIDs = normalizedSelectionIDs(selectionConfiguration.selectedIDs(), model: currentModel)
        let selectedIDs: [AnyHashable]
        switch selectionConfiguration.mode {
        case .none:
            selectedIDs = []
        case .single:
            selectedIDs = [itemID]
        case .multiple:
            selectedIDs = currentIDs.contains(itemID) ? currentIDs : currentIDs + [itemID]
        }
        selectionConfiguration.setSelectedIDs?(normalizedSelectionIDs(selectedIDs, model: currentModel))
    }

    private func updateSelectionBindingAfterUserDeselect(itemID: AnyHashable) {
        guard selectionConfiguration.hasBinding else {
            return
        }

        let selectedIDs = normalizedSelectionIDs(
            selectionConfiguration.selectedIDs().filter { $0 != itemID },
            model: currentModel
        )
        selectionConfiguration.setSelectedIDs?(selectedIDs)
    }

    private func normalizedSelectionIDs(_ ids: [AnyHashable], model: LKListModel) -> [AnyHashable] {
        var seen = Set<AnyHashable>()
        var normalized = [AnyHashable]()

        for id in ids where seen.insert(id).inserted && indexPath(forItemID: id, in: model) != nil {
            normalized.append(id)
            if selectionConfiguration.mode == .single {
                break
            }
        }
        return normalized
    }

    private func applySelection(
        _ selectedIDs: [AnyHashable],
        to collectionView: UICollectionView,
        model: LKListModel
    ) {
        clearSelection(in: collectionView)
        for id in selectedIDs {
            guard let indexPath = indexPath(forItemID: id, in: model) else {
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
        collectionView.refreshControl = refreshControl
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

    private func itemContext(at indexPath: IndexPath) -> LKAnyItemContext? {
        guard
            let sectionIndex = indexPath.lkSection,
            let section = currentModel.section(at: sectionIndex),
            let item = currentModel.item(at: indexPath)
        else {
            return nil
        }

        return LKAnyItemContext(
            id: item.id,
            item: item.base ?? item.id,
            indexPath: indexPath,
            sectionID: section.id
        )
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
            let section = currentModel.section(at: sectionIndex),
            let supplementary = currentModel.supplementary(kind: supplementaryKind, at: indexPath)
        else {
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
#endif
