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
                    environment: environment
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

            return makeListSection(
                for: section,
                appearance: defaultStyle.listAppearance,
                environment: environment
            )
        }
    }

    static func signature(model: LKListModel, defaultStyle: LKListStyle) -> String {
        let sectionSignatures = model.sections.map { section in
            let header = section.header == nil ? "no-header" : "header"
            let footer = section.footer == nil ? "no-footer" : "footer"
            let layout = section.layout?.signature ?? "default"
            return "\(section.id)-\(header)-\(footer)-\(layout)"
        }
        return "\(defaultStyle)-\(sectionSignatures.joined(separator: "|"))"
    }

    private static func makeSection(
        _ layout: LKSectionLayout,
        sectionIndex: Int,
        model: LKSectionModel,
        environment: NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection {
        switch layout {
        case let .list(appearance):
            makeListSection(for: model, appearance: appearance, environment: environment)
        case let .grid(columns, spacing):
            makeGridSection(columns: columns, spacing: spacing, model: model)
        case let .custom(provider):
            provider(sectionIndex, environment)
        }
    }

    private static func makeListSection(
        for section: LKSectionModel?,
        appearance: UICollectionLayoutListConfiguration.Appearance,
        environment: NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection {
        var configuration = UICollectionLayoutListConfiguration(appearance: appearance)
        configuration.showsSeparators = true
        configuration.headerMode = section?.header == nil ? .none : .supplementary
        configuration.footerMode = section?.footer == nil ? .none : .supplementary
        return NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
    }

    private static func makeGridSection(
        columns: Int,
        spacing: CGFloat,
        model: LKSectionModel
    ) -> NSCollectionLayoutSection {
        let safeColumns = max(columns, 1)
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(safeColumns)),
            heightDimension: .estimated(44)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(44)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            repeatingSubitem: item,
            count: safeColumns
        )
        group.interItemSpacing = .fixed(spacing)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = NSDirectionalEdgeInsets(
            top: spacing / 2,
            leading: spacing / 2,
            bottom: spacing / 2,
            trailing: spacing / 2
        )
        section.boundarySupplementaryItems = boundarySupplementaryItems(for: model)
        return section
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
            items.append(
                NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: supplementarySize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
            )
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
