#if canImport(UIKit)
import UIKit

@MainActor
enum LKCollectionLayoutProvider {
    static func makeLayout(
        model: LKListModel,
        defaultStyle: LKListStyle
    ) -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, environment in
            guard let section = model.section(at: sectionIndex) else {
                return makeListSection(
                    for: nil,
                    appearance: defaultStyle.listAppearance,
                    environment: environment,
                    scrollAxis: .vertical
                )
            }

            if let layout = section.layout {
                return makeSection(
                    layout,
                    sectionIndex: sectionIndex,
                    model: section,
                    environment: environment
                )
            }

            switch section.scrollAxis {
            case .vertical:
                return makeListSection(
                    for: section,
                    appearance: defaultStyle.listAppearance,
                    environment: environment,
                    scrollAxis: section.scrollAxis
                )
            case .horizontal:
                return makeHorizontalSection(for: section)
            }
        }
    }

    static func signature(model: LKListModel, defaultStyle: LKListStyle) -> String {
        let sectionSignatures = model.sections.map { section in
            let header = section.header == nil ? "no-header" : "header"
            let footer = section.footer == nil ? "no-footer" : "footer"
            let layout = section.layout?.signature ?? "default"
            let itemSpacing = section.itemSpacing.map(String.init(describing:)) ?? "default-spacing"
            let contentInsets = section.sectionContentInsets?.signature ?? "default-insets"
            let supplementaryInsetsReference = section.supplementaryContentInsetsReference?.signature ?? "default-supplementary-insets-reference"
            return "\(section.id)-\(header)-\(footer)-\(layout)-\(section.scrollAxis)-\(section.orthogonalScrollingBehavior)-\(itemSpacing)-\(contentInsets)-\(supplementaryInsetsReference)-pinned-\(section.pinsHeader)"
        }
        return "\(defaultStyle)-\(sectionSignatures.joined(separator: "|"))"
    }

    static func makeHorizontalSectionForTesting(
        model: LKSectionModel,
        width: CGFloat?,
        height: CGFloat?
    ) -> NSCollectionLayoutSection {
        makeHorizontalSection(for: model, width: width, height: height)
    }

    static func makeGridSectionForTesting(
        columns: Int,
        spacing: CGFloat?,
        itemHeight: CGFloat?,
        columnSpacing: CGFloat?,
        rowSpacing: CGFloat?,
        model: LKSectionModel,
        effectiveContentWidth: CGFloat
    ) -> NSCollectionLayoutSection {
        makeGridSection(
            columns: columns,
            spacing: spacing,
            itemHeight: itemHeight,
            columnSpacing: columnSpacing,
            rowSpacing: rowSpacing,
            model: model,
            effectiveContentWidth: effectiveContentWidth
        )
    }

    private static func makeSection(
        _ layout: LKSectionLayout,
        sectionIndex: Int,
        model: LKSectionModel,
        environment: NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection {
        let layoutSection: NSCollectionLayoutSection
        switch layout {
        case let .list(appearance):
            layoutSection = makeListSection(
                for: model,
                appearance: appearance,
                environment: environment,
                scrollAxis: model.scrollAxis
            )
        case let .horizontal(width, height):
            layoutSection = makeHorizontalSection(
                for: model,
                width: width,
                height: height
            )
        case let .grid(columns, spacing):
            layoutSection = makeGridSection(
                columns: columns,
                spacing: spacing,
                itemHeight: nil,
                columnSpacing: nil,
                rowSpacing: nil,
                model: model,
                effectiveContentWidth: environment.container.effectiveContentSize.width
            )
        case let .fixedGrid(columns, itemHeight, columnSpacing, rowSpacing):
            layoutSection = makeGridSection(
                columns: columns,
                spacing: nil,
                itemHeight: itemHeight,
                columnSpacing: columnSpacing,
                rowSpacing: rowSpacing,
                model: model,
                effectiveContentWidth: environment.container.effectiveContentSize.width
            )
        case let .custom(provider):
            layoutSection = provider(sectionIndex, environment)
            applyItemSpacing(model.itemSpacing, to: layoutSection)
            applySectionContentInsets(model.sectionContentInsets, to: layoutSection)
            applySupplementaryContentInsetsReference(
                model.supplementaryContentInsetsReference,
                to: layoutSection
            )
            applyPinnedHeader(model.pinsHeader, to: layoutSection)
            if model.scrollAxis == .horizontal {
                applyScrollAxis(
                    model.scrollAxis,
                    behavior: model.orthogonalScrollingBehavior,
                    to: layoutSection
                )
            }
            return layoutSection
        }
        applyItemSpacing(model.itemSpacing, to: layoutSection)
        applyScrollAxis(
            model.scrollAxis,
            behavior: model.orthogonalScrollingBehavior,
            to: layoutSection
        )
        applySectionContentInsets(model.sectionContentInsets, to: layoutSection)
        applySupplementaryContentInsetsReference(
            model.supplementaryContentInsetsReference,
            to: layoutSection
        )
        return layoutSection
    }

    private static func makeListSection(
        for section: LKSectionModel?,
        appearance: UICollectionLayoutListConfiguration.Appearance,
        environment: NSCollectionLayoutEnvironment,
        scrollAxis: LKSectionScrollAxis
    ) -> NSCollectionLayoutSection {
        var configuration = UICollectionLayoutListConfiguration(appearance: appearance)
        configuration.showsSeparators = true
        configuration.headerMode = .none
        configuration.footerMode = .none
        let layoutSection = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
        if let section {
            layoutSection.boundarySupplementaryItems = boundarySupplementaryItems(for: section)
        }
        applyItemSpacing(section?.itemSpacing, to: layoutSection)
        applySectionContentInsets(section?.sectionContentInsets, to: layoutSection)
        applySupplementaryContentInsetsReference(
            section?.supplementaryContentInsetsReference,
            to: layoutSection
        )
        applyScrollAxis(
            scrollAxis,
            behavior: section?.orthogonalScrollingBehavior ?? .continuous,
            to: layoutSection
        )
        return layoutSection
    }

    private static func makeHorizontalSection(for model: LKSectionModel) -> NSCollectionLayoutSection {
        makeHorizontalSection(for: model, width: nil, height: nil)
    }

    private static func makeHorizontalSection(
        for model: LKSectionModel,
        width: CGFloat?,
        height: CGFloat?
    ) -> NSCollectionLayoutSection {
        let effectiveSpacing = model.itemSpacing ?? 0
        let itemWidth: NSCollectionLayoutDimension = width == nil
            ? .estimated(44)
            : .fractionalWidth(1)
        let groupWidth: NSCollectionLayoutDimension = width.map {
            .absolute(max($0, 1))
        } ?? .estimated(44)
        let groupHeight: NSCollectionLayoutDimension = height.map {
            .absolute(max($0, 1))
        } ?? .estimated(44)
        let itemSize = NSCollectionLayoutSize(
            widthDimension: itemWidth,
            heightDimension: groupHeight
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: groupWidth,
            heightDimension: groupHeight
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = effectiveSpacing
        section.contentInsets = model.sectionContentInsets?.directionalInsets
            ?? NSDirectionalEdgeInsets(
                top: effectiveSpacing / 2,
                leading: effectiveSpacing / 2,
                bottom: effectiveSpacing / 2,
                trailing: effectiveSpacing / 2
            )
        applySupplementaryContentInsetsReference(
            model.supplementaryContentInsetsReference,
            to: section
        )
        section.boundarySupplementaryItems = boundarySupplementaryItems(for: model)
        applyScrollAxis(.horizontal, behavior: model.orthogonalScrollingBehavior, to: section)
        return section
    }

    private static func makeGridSection(
        columns: Int,
        spacing: CGFloat?,
        itemHeight: CGFloat?,
        columnSpacing: CGFloat?,
        rowSpacing: CGFloat?,
        model: LKSectionModel,
        effectiveContentWidth: CGFloat
    ) -> NSCollectionLayoutSection {
        let safeColumns = max(columns, 1)
        let fallbackSpacing = model.itemSpacing ?? spacing ?? 0
        let effectiveColumnSpacing = columnSpacing ?? fallbackSpacing
        let effectiveRowSpacing = rowSpacing ?? fallbackSpacing
        let isHorizontal = model.scrollAxis == .horizontal
        let contentInsets = model.sectionContentInsets?.directionalInsets
            ?? NSDirectionalEdgeInsets(
                top: fallbackSpacing / 2,
                leading: fallbackSpacing / 2,
                bottom: fallbackSpacing / 2,
                trailing: fallbackSpacing / 2
            )
        let heightDimension: NSCollectionLayoutDimension = itemHeight.map {
            .absolute(max($0, 1))
        } ?? .estimated(44)
        let section: NSCollectionLayoutSection

        if let itemHeight {
            let groupWidth = isHorizontal
                ? estimatedHorizontalGroupWidth(columns: safeColumns, spacing: effectiveColumnSpacing)
                : max(
                    effectiveContentWidth - contentInsets.leading - contentInsets.trailing,
                    0
                )
            let totalColumnSpacing = effectiveColumnSpacing * CGFloat(safeColumns - 1)
            let itemWidth = max((groupWidth - totalColumnSpacing) / CGFloat(safeColumns), 0)
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .absolute(groupWidth),
                heightDimension: .absolute(max(itemHeight, 1))
            )
            let group = NSCollectionLayoutGroup.custom(layoutSize: groupSize) { _ in
                (0..<safeColumns).map { column in
                    let x = CGFloat(column) * (itemWidth + effectiveColumnSpacing)
                    return NSCollectionLayoutGroupCustomItem(
                        frame: CGRect(
                            x: x,
                            y: 0,
                            width: itemWidth,
                            height: max(itemHeight, 1)
                        )
                    )
                }
            }
            section = NSCollectionLayoutSection(group: group)
        } else {
            let itemWidth: NSCollectionLayoutDimension = isHorizontal
                ? .estimated(44)
                : .fractionalWidth(1.0 / CGFloat(safeColumns))
            let groupWidth: NSCollectionLayoutDimension = isHorizontal
                ? .estimated(estimatedHorizontalGroupWidth(columns: safeColumns, spacing: effectiveColumnSpacing))
                : .fractionalWidth(1)
            let itemSize = NSCollectionLayoutSize(
                widthDimension: itemWidth,
                heightDimension: heightDimension
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: groupWidth,
                heightDimension: heightDimension
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                repeatingSubitem: item,
                count: safeColumns
            )
            group.interItemSpacing = .fixed(effectiveColumnSpacing)
            section = NSCollectionLayoutSection(group: group)
        }
        section.interGroupSpacing = effectiveRowSpacing
        section.contentInsets = contentInsets
        applySupplementaryContentInsetsReference(
            model.supplementaryContentInsetsReference,
            to: section
        )
        section.boundarySupplementaryItems = boundarySupplementaryItems(for: model)
        return section
    }

    private static func estimatedHorizontalGroupWidth(columns: Int, spacing: CGFloat) -> CGFloat {
        let estimatedItemWidth: CGFloat = 44
        return CGFloat(columns) * estimatedItemWidth
            + CGFloat(max(columns - 1, 0)) * spacing
    }

    private static func applyItemSpacing(
        _ spacing: CGFloat?,
        to section: NSCollectionLayoutSection
    ) {
        guard let spacing else {
            return
        }
        section.interGroupSpacing = spacing
    }

    private static func applySectionContentInsets(
        _ insets: LKEdgeInsets?,
        to section: NSCollectionLayoutSection
    ) {
        guard let insets else {
            return
        }
        section.contentInsets = insets.directionalInsets
    }

    private static func applySupplementaryContentInsetsReference(
        _ reference: UIContentInsetsReference?,
        to section: NSCollectionLayoutSection
    ) {
        guard let reference else {
            return
        }
        section.supplementaryContentInsetsReference = reference
    }

    private static func applyScrollAxis(
        _ axis: LKSectionScrollAxis,
        behavior: LKSectionOrthogonalScrollingBehavior,
        to section: NSCollectionLayoutSection
    ) {
        switch axis {
        case .vertical:
            section.orthogonalScrollingBehavior = .none
        case .horizontal:
            section.orthogonalScrollingBehavior = behavior.uiKitValue
        }
    }

    private static func applyPinnedHeader(
        _ pinsHeader: Bool,
        to section: NSCollectionLayoutSection
    ) {
        section.boundarySupplementaryItems.forEach { item in
            if item.elementKind == UICollectionView.elementKindSectionHeader {
                item.pinToVisibleBounds = pinsHeader
            }
        }
    }

    private static func boundarySupplementaryItems(
        for section: LKSectionModel
    ) -> [NSCollectionLayoutBoundarySupplementaryItem] {
        var items = [NSCollectionLayoutBoundarySupplementaryItem]()
        let supplementarySize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(44)
        )

        if section.header != nil {
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: supplementarySize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            header.pinToVisibleBounds = section.pinsHeader
            items.append(header)
        }

        if section.footer != nil {
            items.append(
                NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: supplementarySize,
                    elementKind: UICollectionView.elementKindSectionFooter,
                    alignment: .bottom
                )
            )
        }

        return items
    }
}

private extension LKEdgeInsets {
    var directionalInsets: NSDirectionalEdgeInsets {
        NSDirectionalEdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }

    var signature: String {
        "\(top),\(left),\(bottom),\(right)"
    }
}

private extension UIContentInsetsReference {
    var signature: String {
        String(describing: self)
    }
}
#endif
