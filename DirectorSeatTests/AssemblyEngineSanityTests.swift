import XCTest
@testable import DirectorSeat

final class AssemblyEngineSanityTests: XCTestCase {
    func testTargetBuildsAndImports() {
        XCTAssertNotNil(FilmmakingPlan.fastTest)
        XCTAssertEqual(FilmmakingPlan.fastTest.scenes.count, 1)
    }
}
