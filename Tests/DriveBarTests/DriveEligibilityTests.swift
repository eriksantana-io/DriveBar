import XCTest
@testable import DriveBar

final class DriveEligibilityTests: XCTestCase {
    func testExternalFixedMediaIsEjectable() {
        XCTAssertTrue(DriveEligibility.canEject(path: "/Volumes/ZV1_256", local: true, internalDisk: false, removable: false))
    }
    func testSystemAndInternalVolumesStayProtected() {
        for path in ["/", "/System/Volumes", "/System/Volumes/Data"] {
            XCTAssertFalse(DriveEligibility.canEject(path: path, local: true, internalDisk: false, removable: true))
        }
        XCTAssertFalse(DriveEligibility.canEject(path: "/Volumes/Recovery", local: true, internalDisk: true, removable: false))
    }
    func testCardInInternalReaderIsEjectable() {
        XCTAssertTrue(DriveEligibility.canEject(path: "/Volumes/ZV1_256", local: true, internalDisk: true, removable: true))
    }
    func testUnknownLocationNeedsPositiveEvidence() {
        XCTAssertFalse(DriveEligibility.canEject(path: "/Volumes/Unknown", local: true, internalDisk: nil, removable: false))
        XCTAssertTrue(DriveEligibility.canEject(path: "/Volumes/Card", local: true, internalDisk: nil, removable: true))
    }
    func testNetworkSharesRemainEjectable() {
        XCTAssertTrue(DriveEligibility.canEject(path: "/Volumes/Share", local: false, internalDisk: nil, removable: false))
    }
}
