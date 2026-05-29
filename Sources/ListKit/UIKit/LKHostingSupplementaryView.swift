#if canImport(UIKit) && canImport(SwiftUI)
import UIKit
import SwiftUI

final class LKHostingSupplementaryView: UICollectionReusableView {
    private(set) var renderedSupplementaryID: AnyHashable?
    private(set) var hostedContentView: UIView?
    private(set) var fullBleedBackgroundView: UIView?
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

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutFullBleedBackgroundView()
    }

    private func applyBackgroundColor(_ backgroundColor: UIColor?) {
        self.backgroundColor = backgroundColor
        isOpaque = (backgroundColor?.cgColor.alpha ?? 0) >= 1

        guard let backgroundColor else {
            fullBleedBackgroundView?.removeFromSuperview()
            fullBleedBackgroundView = nil
            return
        }

        let backgroundView = fullBleedBackgroundView ?? UIView()
        backgroundView.backgroundColor = backgroundColor
        backgroundView.isOpaque = isOpaque
        backgroundView.isUserInteractionEnabled = false
        if backgroundView.superview == nil {
            insertSubview(backgroundView, at: 0)
        }
        clipsToBounds = false
        fullBleedBackgroundView = backgroundView
        setNeedsLayout()
    }

    private func layoutFullBleedBackgroundView() {
        guard let fullBleedBackgroundView else {
            return
        }

        guard let collectionView = nearestCollectionView() else {
            fullBleedBackgroundView.frame = bounds
            return
        }

        let frameInCollectionView = convert(bounds, to: collectionView)
        fullBleedBackgroundView.frame = CGRect(
            x: -frameInCollectionView.minX,
            y: 0,
            width: collectionView.bounds.width,
            height: bounds.height
        )
    }

    private func nearestCollectionView() -> UICollectionView? {
        var candidate = superview
        while let view = candidate {
            if let collectionView = view as? UICollectionView {
                return collectionView
            }
            candidate = view.superview
        }
        return nil
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
