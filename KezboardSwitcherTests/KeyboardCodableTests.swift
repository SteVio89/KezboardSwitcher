import Testing
import Foundation
@testable import KezboardSwitcher

struct KeyboardCodableTests {

    @Test func encodeKeyboardProducesLowercaseKeys() throws {
        let keyboard = Keyboard(
            name: "Apple Internal Keyboard",
            status: .configured,
            layoutInfo: LayoutInfo(layoutId: "com.apple.keylayout.US", layoutName: "U.S.")
        )
        let data = try JSONEncoder().encode(keyboard)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"name\""))
        #expect(json.contains("\"status\""))
        #expect(json.contains("\"layoutInfo\""))
        #expect(json.contains("\"layoutId\""))
        #expect(json.contains("\"layoutName\""))
    }

    @Test func decodeKeyboardPreservesAllFields() throws {
        let json = """
        {"name":"TestKB","status":"configured","layoutInfo":{"layoutId":"com.apple.keylayout.German","layoutName":"German"}}
        """
        let data = json.data(using: .utf8)!
        let keyboard = try JSONDecoder().decode(Keyboard.self, from: data)

        #expect(keyboard.name == "TestKB")
        #expect(keyboard.status == .configured)
        #expect(keyboard.layoutInfo.layoutId == "com.apple.keylayout.German")
        #expect(keyboard.layoutInfo.layoutName == "German")
    }

    @Test func encodeThenDecodeRoundTrip() throws {
        let original = Keyboard(
            name: "Keychron K2",
            status: .ignored,
            layoutInfo: LayoutInfo(layoutId: "com.apple.keylayout.French", layoutName: "French")
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Keyboard.self, from: data)

        #expect(original == decoded)
    }

    @Test func keyboardStatusRawValues() {
        #expect(KeyboardStatus.new.rawValue == "new")
        #expect(KeyboardStatus.configured.rawValue == "configured")
        #expect(KeyboardStatus.ignored.rawValue == "ignored")
    }

    @Test func keyboardIdentifiable() {
        let keyboard = Keyboard(name: "TestKB", status: .new)
        #expect(keyboard.id == "TestKB")
    }
}
