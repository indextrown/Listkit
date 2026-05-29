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
            return "\(section.id)-\(header)-\(footer)-\(layout)-\(section.scrollAxis)-\(section.orthogonalScrollingBehavior)-\(itemSpacing)-pinned-\(section.pinsHeader)"
        }
        return "\(defaultStyle)-\(sectionSignatures.joined(separator: "|"))"
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
            layoutSection = makeGridSection(columns: columns, spacing: spacing, model: model)
        case let .custom(provider):
            layoutSection = provider(sectionIndex, environment)
            applyItemSpacing(model.itemSpacing, to: layoutSection)
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
        section.contentInsets = NSDirectionalEdgeInsets(
            top: effectiveSpacing / 2,
            leading: effectiveSpacing / 2,
            bottom: effectiveSpacing / 2,
            trailing: effectiveSpacing / 2
        )
        section.boundarySupplementaryItems = boundarySupplementaryItems(for: model)
        applyScrollAxis(.horizontal, behavior: model.orthogonalScrollingBehavior, to: section)
        return section
    }

    private static func makeGridSection(
        columns: Int,
        spacing: CGFloat,
        model: LKSectionModel
    ) -> NSCollectionLayoutSection {
        let safeColumns = max(columns, 1)
        let effectiveSpacing = model.itemSpacing ?? spacing
        let isHorizontal = model.scrollAxis == .horizontal
        let itemWidth: NSCollectionLayoutDimension = isHorizontal
            ? .estimated(44)
            : .fractionalWidth(1.0 / CGFloat(safeColumns))
        let groupWidth: NSCollectionLayoutDimension = isHorizontal
            ? .estimated(estimatedHorizontalGroupWidth(columns: safeColumns, spacing: effectiveSpacing))
            : .fractionalWidth(1)
        let itemSize = NSCollectionLayoutSize(
            widthDimension: itemWidth,
            heightDimension: .estimated(44)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: groupWidth,
            heightDimension: .estimated(44)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            repeatingSubitem: item,
            count: safeColumns
        )
        group.interItemSpacing = .fixed(effectiveSpacing)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = effectiveSpacing
        section.contentInsets = NSDirectionalEdgeInsets(
            top: effectiveSpacing / 2,
            leading: effectiveSpacing / 2,
            bottom: effectiveSpacing / 2,
            trailing: effectiveSpacing / 2
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
#endif
