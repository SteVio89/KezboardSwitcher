//
//  ContentView.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 28.07.25.
//

import SwiftUI

struct ContentView: View {
    
    @State private var keyboardManager: KeyboardManager?
    @State private var keyboards: [Keyboard] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var lastDetectedKeyboard: String = "None"
    
    var body: some View {
        VStack {
            VStack(spacing: 20) {
                VStack {
                    Image(systemName: "keyboard")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                        .font(.largeTitle)
                    Text("KezboardSwitcher")
                        .font(.title2)
                }
                .padding(.top)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Status")
                        .font(.headline)
                    
                    HStack {
                        Text("Manager Status:")
                        Spacer()
                        Text(keyboardManager != nil ? "Active" : "Incative")
                            .foregroundColor(keyboardManager != nil ? .green : .red)
                    }
                    
                    HStack {
                        Text("Last detected: ")
                        Spacer()
                        Text(lastDetectedKeyboard)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Connected Keyboards (\(keyboards.count))")
                            .font(.headline)
                        Spacer()
                        Button("Refresh") {
                            refreshKeyboards()
                        }
                        .disabled(isLoading)
                    }
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Spacer()
                        }
                        .padding()
                    } else if keyboards.isEmpty {
                        Text("No keyboards detected")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(keyboards.indices, id: \.self) { index in
                            HStack {
                                Image(systemName: "keyboard")
                                    .foregroundColor(.blue)
                                Text(keyboards[index].name)
                                Spacer()
                                Text(keyboards[index].status.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(statusColor(for: keyboards[index].status))
                                    .cornerRadius(8)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("KeyboardSwitcher")
            .onAppear{
                initKeyboardManager()
            }
        }
    }
    
    private func statusColor(for status: KeyboardStatus) -> Color {
        switch status {
        case .new: return Color.orange.opacity(0.3)
        case .configured: return Color.green.opacity(0.3)
        case .ignored: return Color.red.opacity(0.3)
        }
    }
    
    private func initKeyboardManager() {
        do {
            keyboardManager = try KeyboardManager()
            refreshKeyboards()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func refreshKeyboards() {
        guard let manager = keyboardManager else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fetchedKeyboards = manager.fetchConnectedKeyboards()
            
            DispatchQueue.main.async {
                keyboards = fetchedKeyboards
                isLoading = false
            }
        }
    }
}

#Preview {
    ContentView()
}
