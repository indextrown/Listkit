#if canImport(UIKit) && canImport(SwiftUI)
import UIKit
import SwiftUI

final class LKHostingCollectionViewCell: UICollectionViewCell {
    private(set) var renderedItemID: AnyHashable?
    private(set) var renderedIndexPath: IndexPath?
    private(set) var renderedSectionID: AnyHashable?
    private(set) var renderedState = LKCellState.inactive
    private var item: LKItemModel?
    private var indexPath: IndexPath?
    private var sectionID: AnyHashable?
    private var onSizeChange: ((CGSize) -> Void)?

    func render(
        item: LKItemModel,
        indexPath: IndexPath? = nil,
        sectionID: AnyHashable? = nil,
        onSizeChange: ((CGSize) -> Void)? = nil
    ) {
        self.item = item
        self.indexPath = indexPath
        self.sectionID = sectionID
        self.onSizeChange = onSizeChange
        renderedItemID = item.id
        renderedIndexPath = indexPath
        renderedSectionID = sectionID
        updateContentConfiguration(for: configurationState)
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        updateContentConfiguration(for: state)
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let fittedAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        onSizeChange?(fittedAttributes.size)
        return fittedAttributes
    }

    private func updateContentConfiguration(for state: UICellConfigurationState) {
        guard let item else {
            contentConfiguration = nil
            return
        }

        guard let makeContent = item.makeContent else {
            contentConfiguration = nil
            return
        }

        let cellState = LKCellState(
            isSelected: state.isSelected,
            isHighlighted: state.isHighlighted,
            isFocused: state.isFocused
        )
        renderedState = cellState
        contentConfiguration = UIHostingConfiguration {
            makeContent()
                .environment(\.lkCellState, cellState)
                .environment(\.listKitIndexPath, indexPath)
                .environment(\.listKitSectionID, sectionID)
                .environment(\.listKitItemID, item.id)
        }
    }
}
#endif
