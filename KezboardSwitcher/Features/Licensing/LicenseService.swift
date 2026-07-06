//
//  LicenseService.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 08.03.26.
//

import CryptoKit
import Foundation
import IOKit
import os.log

// MARK: - Models

struct LicensePayload: Codable, Equatable {
  var appId: String
  var licenseKey: String
  var machineHash: String
  var activatedAt: String

  enum CodingKeys: String, CodingKey {
    case appId = "bundle_id"
    case licenseKey = "license_key"
    case machineHash = "machine_hash"
    case activatedAt = "activated_at"
  }
}

struct SignedLicense: Codable, Equatable {
  var payload: LicensePayload
  var signature: String
  var keyId: String

  enum CodingKeys: String, CodingKey {
    case payload
    case signature
    case keyId = "key_id"
  }
}

// MARK: - Errors

enum LicenseError: Error, LocalizedError {
  case network(Error)
  case serverError(code: String, message: String)
  case invalidResponse
  case signatureInvalid
  case appIdMismatch
  case machineHashMismatch
  case machineHashUnavailable
  case saveFailed
  case appUpdateRequired
  case noStoredLicense
  case deactivationFailed

  var errorDescription: String? {
    switch self {
    case .network:
      return "Unable to reach the activation server. Check your internet connection."
    case .serverError(_, let message):
      return message
    case .invalidResponse:
      return "Invalid response from the activation server."
    case .signatureInvalid:
      return "The license response could not be verified. Contact support."
    case .appIdMismatch, .machineHashMismatch:
      return "This license is not valid for this app or machine."
    case .machineHashUnavailable:
      return "Could not determine machine identity."
    case .saveFailed:
      return "Failed to store the license. Please try again."
    case .appUpdateRequired:
      return
        "This version of KezboardSwitcher cannot verify the license. Please update to the latest version."
    case .noStoredLicense:
      return "No active license found on this device."
    case .deactivationFailed:
      return "Failed to deactivate the license on the server."
    }
  }
}

// MARK: - LicenseService

struct LicenseService {

  #if DEBUG
    private static let baseURL = "http://localhost:3000"
  #else
    private static let baseURL = "https://stevio.de"
  #endif

  private static let bundleID = "de.stevio.KezboardSwitcher"

  /// Pinned Ed25519 public key for license signature verification.
  /// After server-side key rotation, a new binary with the updated key must be shipped.
  /// Internal (not private) so unit tests can assert forged licenses fail against it.
  static let pinnedPublicKeyB64 = "7+CBehVba1YaCltKCL4az2u6+S74Y8g8/6yKpDYW24g="

  private static var licenseFileURL: URL {
    FileManager.default
      .homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/KezboardSwitcher/license.json")
  }

  private let logger = Logger(subsystem: "de.stevio.KezboardSwitcher", category: "LicenseService")

  // MARK: - Activation

  func activate(licenseKey: String) async throws -> SignedLicense {
    let hash = try machineHash()

    let body: [String: String] = [
      "license_key": licenseKey,
      "machine_hash": hash,
      "device_label": Host.current().localizedName ?? "Unknown Mac",
    ]

    var request = URLRequest(url: URL(string: "\(Self.baseURL)/api/license/activate")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 15
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    #if DEBUG
      logger.debug("Activation request URL: \(request.url!.absoluteString)")
      logger.debug(
        "Activation request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "nil")")
    #endif

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      throw LicenseError.network(error)
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw LicenseError.invalidResponse
    }

    #if DEBUG
      logger.debug("Activation response status: \(httpResponse.statusCode)")
      logger.debug("Activation response body: \(String(data: data, encoding: .utf8) ?? "nil")")
    #endif

    if httpResponse.statusCode != 200 {
      if let apiError = try? JSONDecoder().decode(ServerErrorResponse.self, from: data) {
        throw LicenseError.serverError(code: apiError.code, message: apiError.message)
      }
      throw LicenseError.invalidResponse
    }

    let signed = try JSONDecoder().decode(SignedLicense.self, from: data)
    do {
      try verify(signed, publicKeyB64: Self.pinnedPublicKeyB64)
    } catch LicenseError.signatureInvalid {
      // Pinned key can't verify → server has rotated keys → user needs a newer binary
      throw LicenseError.appUpdateRequired
    }
    try save(signed)
    return signed
  }

  // MARK: - Deactivation

  func deactivate() async throws {
    guard let signed = loadSignedLicense() else {
      throw LicenseError.noStoredLicense
    }

    let body: [String: String] = [
      "license_key": signed.payload.licenseKey,
      "machine_hash": signed.payload.machineHash,
    ]

    var request = URLRequest(url: URL(string: "\(Self.baseURL)/api/license/deactivate")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 15
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      throw LicenseError.network(error)
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw LicenseError.deactivationFailed
    }

    if httpResponse.statusCode != 204 {
      if let apiError = try? JSONDecoder().decode(ServerErrorResponse.self, from: data) {
        if isGoneOnServer(code: apiError.code) {
          // The server no longer knows this activation — nothing left to
          // deactivate remotely, so detach the machine locally and succeed.
          logger.info(
            "Server reports license gone (\(apiError.code, privacy: .public)); removing local license"
          )
          deleteLicenseFile()
          return
        }
        throw LicenseError.serverError(code: apiError.code, message: apiError.message)
      }
      throw LicenseError.deactivationFailed
    }

    deleteLicenseFile()
    logger.info("License deactivated successfully")
  }

  /// Returns true when a server error code means the license or activation no
  /// longer exists server-side, so the local license file should be removed as
  /// if deactivation had succeeded.
  ///
  /// The deactivate endpoint returns `license_invalid` for all gone cases
  /// (unknown key, revoked license, activation not found); `license_revoked`
  /// is accepted for future-proofing.
  ///
  /// - Parameter code: The `error` code from a `ServerErrorResponse`.
  /// - Returns: True if the license is gone on the server.
  func isGoneOnServer(code: String) -> Bool {
    code == "license_invalid" || code == "license_revoked"
  }

  // MARK: - Verification

  func verify(_ signedLicense: SignedLicense, publicKeyB64: String) throws {
    guard signedLicense.payload.appId == Self.bundleID else {
      throw LicenseError.appIdMismatch
    }

    let currentHash = try machineHash()
    guard signedLicense.payload.machineHash == currentHash else {
      throw LicenseError.machineHashMismatch
    }

    guard verifySignature(signedLicense, publicKeyB64: publicKeyB64) else {
      throw LicenseError.signatureInvalid
    }
  }

  /// Checks only the Ed25519 signature — no payload field validation.
  private func verifySignature(_ signedLicense: SignedLicense, publicKeyB64: String) -> Bool {
    guard let keyBytes = Data(base64Encoded: publicKeyB64),
      let sigBytes = Data(base64Encoded: signedLicense.signature),
      let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyBytes)
    else {
      return false
    }
    let message = canonicalJSON(signedLicense.payload)
    return publicKey.isValidSignature(sigBytes, for: message)
  }

  // MARK: - Machine Hash

  /// SHA-256 hash of the IOPlatformUUID, returned as a 64-character lowercase hex string.
  func machineHash() throws -> String {
    guard let uuid = platformUUID() else {
      throw LicenseError.machineHashUnavailable
    }
    let hash = SHA256.hash(data: Data(uuid.utf8))
    return hash.map { String(format: "%02x", $0) }.joined()
  }

  private func platformUUID() -> String? {
    let service = IOServiceGetMatchingService(
      kIOMainPortDefault,
      IOServiceMatching("IOPlatformExpertDevice")
    )
    guard service != IO_OBJECT_NULL else { return nil }
    defer { IOObjectRelease(service) }

    let key = "IOPlatformUUID" as CFString
    guard let ref = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0) else {
      return nil
    }
    return ref.takeRetainedValue() as? String
  }

  // MARK: - Canonical JSON

  /// Builds JSON in the exact field order that the Go server uses for signing.
  /// Go's json.Marshal serializes struct fields in declaration order:
  /// app_id, license_key, machine_hash, activated_at
  func canonicalJSON(_ payload: LicensePayload) -> Data {
    let s =
      "{\"bundle_id\":\"\(jsonEscape(payload.appId))\",\"license_key\":\"\(jsonEscape(payload.licenseKey))\",\"machine_hash\":\"\(jsonEscape(payload.machineHash))\",\"activated_at\":\"\(jsonEscape(payload.activatedAt))\"}"
    return Data(s.utf8)
  }

  private func jsonEscape(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }

  // MARK: - File Persistence

  func load() -> SignedLicense? {
    guard let signed = loadSignedLicense() else {
      logger.info("No stored license found")
      return nil
    }

    do {
      try verify(signed, publicKeyB64: Self.pinnedPublicKeyB64)
    } catch {
      logger.info("Stored license failed verification: \(error). Treating as unlicensed.")
      deleteLicenseFile()
      return nil
    }

    return signed
  }

  func save(_ signedLicense: SignedLicense) throws {
    let url = Self.licenseFileURL
    let dir = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(signedLicense)
    try data.write(to: url, options: [.atomic])
  }

  private func loadSignedLicense() -> SignedLicense? {
    guard let data = try? Data(contentsOf: Self.licenseFileURL) else { return nil }
    return try? JSONDecoder().decode(SignedLicense.self, from: data)
  }

  private func deleteLicenseFile() {
    try? FileManager.default.removeItem(at: Self.licenseFileURL)
  }

}

// MARK: - Server Error Response

/// Mirrors the server's error JSON `{"error": "<code>", "message": "<text>"}`.
/// Internal (not private) so unit tests can cover the decoding.
struct ServerErrorResponse: Decodable {
  let code: String
  let message: String

  enum CodingKeys: String, CodingKey {
    case code = "error"
    case message
  }
}
