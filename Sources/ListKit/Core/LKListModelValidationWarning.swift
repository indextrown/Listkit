/// Validation warning emitted before a model is applied to a collection view.
public enum LKListModelValidationWarning: Equatable {
    case duplicateSectionID(AnyHashable)
    case duplicateItemID(sectionID: AnyHashable, itemID: AnyHashable)
}
