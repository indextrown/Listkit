#if canImport(UIKit) && canImport(SwiftUI)
import UIKit
import SwiftUI

final class LKHostingSupplementaryView: UICollectionReusableView {
    private(set) var renderedSupplementaryID: AnyHashable?
    private(set) var hostedContentView: UIView?
    private(set) var renderedState = LKCellState.inactive
    private var onSizeChange: ((CGSize) -> Void)?

    func render(
        supplementary: LKSupplementaryModel,
        state: LKCellState = .inactive,
        onSizeChange: ((CGSize) -> Void)? = nil
    ) {
        renderedSupplementaryID = supplementary.id
        renderedState = state
        self.onSizeChange = onSizeChange
        applyBackgroundColor(supplementary.backgroundColor)
        hostedContentView?.removeFromSuperview()

        guard let content = supplementary.content else {
            hostedContentView = nil
            return
        }

        let contentView = content.makeSupplementaryContentView(state: state)
        contentView.backgroundColor = supplementary.backgroundColor
        contentView.isOpaque = isOpaque

        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        hostedContentView = contentView
    }

    private func applyBackgroundColor(_ backgroundColor: UIColor?) {
        self.backgroundColor = backgroundColor
        isOpaque = (backgroundColor?.cgColor.alpha ?? 0) >= 1
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let fittedAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        onSizeChange?(fittedAttributes.size)
        return fittedAttributes
    }
}
#endif
