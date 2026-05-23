import Foundation

/// Immutable snapshot consumed by adapters, layouts, and update engines.
public struct LKListModel: Equatable {
    public static var empty: LKListModel {
        LKListModel()
    }

    public var sections: [LKSectionModel]

    public init(sections: [LKSectionModel] = []) {
        self.sections = sections
    }

    public func section(at index: Int) -> LKSectionModel? {
        guard sections.indices.contains(index) else {
            return nil
        }
        return sections[index]
    }

    public func item(at indexPath: IndexPath) -> LKItemModel? {
        guard
            let sectionIndex = indexPath.lkSection,
            let itemIndex = indexPath.lkItem,
            let section = section(at: sectionIndex),
            section.items.indices.contains(itemIndex)
        else {
            return nil
        }
        return section.items[itemIndex]
    }

    public func supplementary(
        kind: LKSupplementaryKind,
        at indexPath: IndexPath
    ) -> LKSupplementaryModel? {
        guard
            let sectionIndex = indexPath.lkSection,
            let section = section(at: sectionIndex)
        else {
            return nil
        }
        return section.supplementary(kind: kind)
    }

    public func validationWarnings() -> [LKListModelValidationWarning] {
        var warnings: [LKListModelValidationWarning] = []
        var sectionIDs = Set<AnyHashable>()

        for section in sections {
            if sectionIDs.insert(section.id).inserted == false {
                warnings.append(.duplicateSectionID(section.id))
            }

            var itemIDs = Set<AnyHashable>()
            for item in section.items where itemIDs.insert(item.id).inserted == false {
                warnings.append(.duplicateItemID(sectionID: section.id, itemID: item.id))
            }
        }

        return warnings
    }

    @discardableResult
    public func validateForApply(
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> [LKListModelValidationWarning] {
        let warnings = validationWarnings()

        #if DEBUG
        if warnings.isEmpty == false {
            assertionFailure("Invalid LKListModel: \(warnings)", file: file, line: line)
        }
        #endif

        return warnings
    }
}
