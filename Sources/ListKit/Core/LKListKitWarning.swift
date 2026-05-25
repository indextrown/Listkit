import Foundation

public enum LKListKitWarning: Equatable {
    case duplicateSectionID(AnyHashable)
    case duplicateItemID(sectionID: AnyHashable, itemID: AnyHashable)
    case invalidLookup(kind: LKInvalidLookupKind, indexPath: IndexPath)
    case unsupportedLayout(sectionID: AnyHashable, reason: String)
    case diffFailure(engine: LKUpdateEngine, reason: String)
}

public enum LKInvalidLookupKind: Hashable, Sendable {
    case section
    case item
    case supplementary
}

public enum LKListKitDiagnosticsMode: Hashable, Sendable {
    case disabled
    case enabled
}

extension LKListKitWarning {
    init(_ validationWarning: LKListModelValidationWarning) {
        switch validationWarning {
        case let .duplicateSectionID(sectionID):
            self = .duplicateSectionID(sectionID)
        case let .duplicateItemID(sectionID, itemID):
            self = .duplicateItemID(sectionID: sectionID, itemID: itemID)
        }
    }
}
