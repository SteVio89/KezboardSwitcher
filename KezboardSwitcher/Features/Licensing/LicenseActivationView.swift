//
//  LicenseActivationView.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 08.03.26.
//

import SwiftUI

struct LicenseActivationView: View {
    @Environment(AppViewModel.self) private var viewModel

    @State private var licenseKey: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("Activate License")
                .font(.title2.bold())

            VStack(spacing: 4) {
                Text("Enter the license key from your purchase to activate KezboardSwitcher.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Link("Get a license at store.stevio.de", destination: URL(string: "https://store.stevio.de")!)
                    .font(.callout)
            }
            .frame(maxWidth: 350)

            VStack(spacing: 12) {
                TextField("License Key", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                    .onSubmit { activate() }

                Button("Activate") { activate() }
                    .buttonStyle(.borderedProminent)
                    .disabled(licenseKey.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                        .frame(maxWidth: 320)
                }
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }

    private func activate() {
        let key = licenseKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !isLoading else { return }
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await viewModel.activateLicense(licenseKey: key)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
