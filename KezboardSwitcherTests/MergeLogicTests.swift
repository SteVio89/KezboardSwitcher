import Testing
@testable import KezboardSwitcher

struct MergeLogicTests {

    @Test func emptyBothReturnsEmpty() {
        let result = AppViewModel.merge(config: [], detected: [])
        #expect(result.isEmpty)
    }

    @Test func configOnlyPreserved() {
        let config = [Keyboard(name: "KB1", status: .configured, layoutInfo: LayoutInfo(layoutId: "us", layoutName: "US"))]
        let result = AppViewModel.merge(config: config, detected: [])
        #expect(result.count == 1)
        #expect(result[0].status == .configured)
        #expect(result[0].layoutInfo.layoutId == "us")
    }

    @Test func detectedOnlyAppended() {
        let detected = [Keyboard(name: "KB1", status: .new)]
        let result = AppViewModel.merge(config: [], detected: detected)
        #expect(result.count == 1)
        #expect(result[0].name == "KB1")
        #expect(result[0].status == .new)
    }

    @Test func overlapPreservesConfig() {
        let config = [Keyboard(name: "KB1", status: .configured, layoutInfo: LayoutInfo(layoutId: "de", layoutName: "German"))]
        let detected = [Keyboard(name: "KB1", status: .new)]
        let result = AppViewModel.merge(config: config, detected: detected)
        #expect(result.count == 1)
        #expect(result[0].status == .configured)
        #expect(result[0].layoutInfo.layoutId == "de")
    }

    @Test func ignoredPersists() {
        let config = [Keyboard(name: "KB1", status: .ignored)]
        let detected = [Keyboard(name: "KB1", status: .new)]
        let result = AppViewModel.merge(config: config, detected: detected)
        #expect(result.count == 1)
        #expect(result[0].status == .ignored)
    }

    @Test func mixedMerge() {
        let config = [
            Keyboard(name: "KB1", status: .configured, layoutInfo: LayoutInfo(layoutId: "us", layoutName: "US")),
            Keyboard(name: "KB2", status: .ignored),
        ]
        let detected = [
            Keyboard(name: "KB1", status: .new),
            Keyboard(name: "KB3", status: .new),
        ]
        let result = AppViewModel.merge(config: config, detected: detected)
        #expect(result.count == 3)
        #expect(result[0].name == "KB1")
        #expect(result[0].status == .configured)
        #expect(result[1].name == "KB2")
        #expect(result[1].status == .ignored)
        #expect(result[2].name == "KB3")
        #expect(result[2].status == .new)
    }
}
