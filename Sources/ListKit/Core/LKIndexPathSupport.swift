import Foundation

extension IndexPath {
    static func lkIndexPath(item: Int, section: Int) -> IndexPath {
        IndexPath(indexes: [section, item])
    }

    var lkSection: Int? {
        count > 0 ? self[0] : nil
    }

    var lkItem: Int? {
        count > 1 ? self[1] : nil
    }
}
