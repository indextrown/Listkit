import XCTest
@testable import ListKit

final class ListKitTests: XCTestCase {
    func testNamespaceUsesLKPrefix() {
        XCTAssertEqual(ListKit.apiPrefix, "LK")
    }

    func testMinimumIOSVersionIsDocumented() {
        XCTAssertEqual(ListKit.minimumIOSVersion, "16.0")
    }

    func testUpdateEngineCasesArePublicAndEquatable() {
        XCTAssertEqual(LKUpdateEngine.reloadData, .reloadData)
        XCTAssertNotEqual(LKUpdateEngine.reloadData, .diffableDataSource)
        XCTAssertNotEqual(LKUpdateEngine.diffableDataSource, .differenceKit)
    }

    func testPlatformCapabilityFlagsCompile() {
        _ = LKPlatformSupport.canImportSwiftUI
        _ = LKPlatformSupport.canImportUIKit
    }
}
