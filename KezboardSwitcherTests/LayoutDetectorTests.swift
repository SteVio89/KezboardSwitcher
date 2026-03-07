import Testing
@testable import KezboardSwitcher

struct LayoutDetectorTests {

    @Test func getAvailableLayoutsReturnsNonEmpty() {
        let detector = LayoutDetector()
        let layouts = detector.getAvailableLayouts()
        #expect(!layouts.isEmpty, "Expected at least one keyboard layout on this system")
    }

    @Test func layoutsAreSortedByName() {
        let detector = LayoutDetector()
        let layouts = detector.getAvailableLayouts()
        for i in 1..<layouts.count {
            #expect(layouts[i - 1].layoutName.localizedCaseInsensitiveCompare(layouts[i].layoutName) != .orderedDescending)
        }
    }
}
