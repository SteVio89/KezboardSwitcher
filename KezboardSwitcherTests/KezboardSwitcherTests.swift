//
//  KezboardSwitcherTests.swift
//  KezboardSwitcherTests
//
//  Created by Stefan Viol on 28.07.25.
//

import Testing
@testable import KezboardSwitcher

struct AppViewModelTests {

    @MainActor
    @Test func assignLayoutUpdatesKeyboard() {
        let vm = AppViewModel()
        vm.keyboards = [Keyboard(name: "KB1", status: .new)]
        let layout = LayoutInfo(layoutId: "com.apple.keylayout.US", layoutName: "US")

        vm.assignLayout(layout, to: vm.keyboards[0])

        #expect(vm.keyboards[0].status == .configured)
        #expect(vm.keyboards[0].layoutInfo.layoutId == "com.apple.keylayout.US")
    }

    @MainActor
    @Test func assignLayoutIgnoresUnknownKeyboard() {
        let vm = AppViewModel()
        vm.keyboards = [Keyboard(name: "KB1", status: .new)]
        let unknown = Keyboard(name: "Unknown", status: .new)
        let layout = LayoutInfo(layoutId: "us", layoutName: "US")

        vm.assignLayout(layout, to: unknown)

        #expect(vm.keyboards[0].status == .new)
    }

    @MainActor
    @Test func toggleIgnoreSetsIgnored() {
        let vm = AppViewModel()
        vm.keyboards = [Keyboard(name: "KB1", status: .configured, layoutInfo: LayoutInfo(layoutId: "us", layoutName: "US"))]

        vm.toggleIgnore(vm.keyboards[0])

        #expect(vm.keyboards[0].status == .ignored)
        #expect(vm.keyboards[0].layoutInfo.layoutId.isEmpty)
    }

    @MainActor
    @Test func toggleIgnoreUnsetsIgnored() {
        let vm = AppViewModel()
        vm.keyboards = [Keyboard(name: "KB1", status: .ignored)]

        vm.toggleIgnore(vm.keyboards[0])

        #expect(vm.keyboards[0].status == .new)
    }

    @MainActor
    @Test func filterManagedKeyboards() {
        let keyboards = [
            Keyboard(name: "KB1", status: .configured, layoutInfo: LayoutInfo(layoutId: "us", layoutName: "US")),
            Keyboard(name: "KB2", status: .new),
            Keyboard(name: "KB3", status: .ignored),
            Keyboard(name: "KB4", status: .configured, layoutInfo: LayoutInfo()),
        ]

        let filtered = keyboards.filter {
            $0.status == .configured && !$0.layoutInfo.layoutId.isEmpty
        }

        #expect(filtered.count == 1)
        #expect(filtered[0].name == "KB1")
    }
}
