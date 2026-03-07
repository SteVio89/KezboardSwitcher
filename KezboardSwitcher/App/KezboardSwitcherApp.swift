//
//  KezboardSwitcherApp.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 28.07.25.
//

import SwiftUI

@main
struct KezboardSwitcherApp : App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
/*
@main
struct KezboardSwitcherApp {
    static func main() {
        do {
            let keyboardManager = try KeyboardManager()
            let keyboards = keyboardManager.fetchConnectedKeyboards()
            print("Found \(keyboards.count) keyboard(s):\n")
            if keyboards.isEmpty {
                print("No keyboards detected")
            } else {
                keyboards.enumerated().forEach { index, keyboard in print("\(index + 1). \(keyboard.name)")
                }
            }
        } catch {
                print("Error: \(error)")
                exit(1)
        }
    }
}
*/
