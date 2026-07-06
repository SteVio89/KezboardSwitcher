import CryptoKit
import Foundation
import Testing

@testable import KezboardSwitcher

struct LicenseVerifyTests {

  // MARK: - F3: Pinned-key verification blocks forged licenses

  @Test func forgedLicenseFailsAgainstPinnedKeyButPassesForgersOwnKey() throws {
    let service = LicenseService()

    // Payload with the real bundle id and this machine's hash, so only the
    // signature check can distinguish forged from genuine.
    let payload = LicensePayload(
      appId: "de.stevio.KezboardSwitcher",
      licenseKey: UUID().uuidString.lowercased(),
      machineHash: try service.machineHash(),
      activatedAt: "2026-07-05T00:00:00Z"
    )

    let forgerKey = Curve25519.Signing.PrivateKey()
    let signature = try forgerKey.signature(for: service.canonicalJSON(payload))
    let forged = SignedLicense(
      payload: payload,
      signature: signature.base64EncodedString(),
      keyId: "forged-key"
    )

    #expect(throws: LicenseError.self) {
      try service.verify(forged, publicKeyB64: LicenseService.pinnedPublicKeyB64)
    }

    // Sanity check: the same license verifies against the forger's own key,
    // proving the pinned key is what blocks the forgery.
    let forgerPublicKeyB64 = forgerKey.publicKey.rawRepresentation.base64EncodedString()
    try service.verify(forged, publicKeyB64: forgerPublicKeyB64)
  }

  // MARK: - F3: license.json decoding ignores unknown keys

  @Test func signedLicenseDecodesIgnoringUnknownKeys() throws {
    let json = """
      {"payload":{"bundle_id":"de.stevio.KezboardSwitcher","license_key":"abc-123","machine_hash":"deadbeef","activated_at":"2026-01-01T00:00:00Z"},"signature":"c2ln","key_id":"k1","publicKeyB64":"KwCZfVIUkhLVB2jfn0OypXfY8hWHgNPMzSxORKGjeXQ="}
      """
    let signed = try JSONDecoder().decode(SignedLicense.self, from: Data(json.utf8))

    #expect(signed.payload.appId == "de.stevio.KezboardSwitcher")
    #expect(signed.payload.licenseKey == "abc-123")
    #expect(signed.payload.machineHash == "deadbeef")
    #expect(signed.signature == "c2ln")
    #expect(signed.keyId == "k1")
  }

  // MARK: - F7: Server error decoding

  @Test func serverErrorResponseDecodesErrorKeyAsCode() throws {
    let body = """
      {"error":"activation_slots_full","message":"Maximum device activations reached"}
      """
    let decoded = try JSONDecoder().decode(ServerErrorResponse.self, from: Data(body.utf8))

    #expect(decoded.code == "activation_slots_full")
    #expect(decoded.message == "Maximum device activations reached")
  }

  // MARK: - F11: Gone-on-server decision

  @Test func isGoneOnServerMatchesOnlyGoneCodes() {
    let service = LicenseService()

    #expect(service.isGoneOnServer(code: "license_invalid"))
    #expect(service.isGoneOnServer(code: "license_revoked"))
    #expect(!service.isGoneOnServer(code: "activation_slots_full"))
    #expect(!service.isGoneOnServer(code: "no_active_signing_key"))
    #expect(!service.isGoneOnServer(code: ""))
  }
}
