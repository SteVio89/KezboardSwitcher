import Testing
import Foundation
@testable import KezboardSwitcher

struct ConfigServiceTests {

    @Test func saveAndLoadRoundTrip() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let configURL = tempDir.appendingPathComponent("config.json")
        let service = ConfigService(configURL: configURL)

        let keyboards = [
            Keyboard(name: "Apple Internal", status: .configured,
                     layoutInfo: LayoutInfo(layoutId: "com.apple.keylayout.US", layoutName: "U.S.")),
            Keyboard(name: "Keychron K2", status: .ignored),
        ]

        try service.save(keyboards: keyboards)
        let loaded = service.load()

        #expect(loaded.count == 2)
        #expect(loaded[0] == keyboards[0])
        #expect(loaded[1] == keyboards[1])

        try FileManager.default.removeItem(at: tempDir)
    }

    @Test func loadMissingFileReturnsEmpty() {
        let configURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("nonexistent.json")
        let service = ConfigService(configURL: configURL)

        let result = service.load()
        #expect(result.isEmpty)
    }

    @Test func loadCorruptFileMovesItToBackup() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let configURL = tempDir.appendingPathComponent("config.json")
        let backupURL = tempDir.appendingPathComponent("config.json.bak")
        let service = ConfigService(configURL: configURL)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let garbage = Data("not valid json {{{".utf8)
        try garbage.write(to: configURL)

        let loaded = service.load()
        #expect(loaded.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: configURL.path))
        #expect(try Data(contentsOf: backupURL) == garbage)

        // A subsequent save must write a fresh, valid config file.
        let keyboards = [Keyboard(name: "Keychron K2", status: .ignored)]
        try service.save(keyboards: keyboards)
        let reloaded = service.load()
        #expect(reloaded == keyboards)

        try FileManager.default.removeItem(at: tempDir)
    }
}
