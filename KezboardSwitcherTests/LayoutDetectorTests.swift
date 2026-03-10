import Testing
@testable import KezboardSwitcher

@MainActor
struct LayoutDetectorTests {

    @Test func getAllLayoutsReturnsNonEmpty() {
        let detector = LayoutDetector()
        let layouts = detector.getAllLayouts()
        #expect(!layouts.isEmpty, "Expected at least one keyboard layout on this system")
    }

    @Test func layoutsAreSortedByName() {
        let detector = LayoutDetector()
        let layouts = detector.getAllLayouts()
        for i in 1..<layouts.count {
            #expect(layouts[i - 1].layoutName.localizedCaseInsensitiveCompare(layouts[i].layoutName) != .orderedDescending)
        }
    }
}
