import XCTest
@testable import CrownPrix_Watch_App

final class CrownPrixTests: XCTestCase {
    func testResourcesAccessible() {
        let url = BundleHelper.svgURL(name: "RaceCircuitMonaco", bundle: Bundle.main)
        XCTAssertNotNil(url, "Monaco SVG not found via BundleHelper")
    }
}
