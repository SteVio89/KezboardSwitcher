# Server Change: Remove Public Keys Endpoint

## Context

The KezboardSwitcher macOS app has been updated to use a **pinned Ed25519 public key** hardcoded in the binary for license signature verification. The app no longer fetches public keys from the server during activation.

This means the `GET /api/sdk/public-keys` endpoint is no longer needed by this client and can be removed.

## What Changed on the Client

- The app verifies license signatures against a **pinned public key** compiled into the binary
- The `GET /api/sdk/public-keys` endpoint is no longer called
- The `key_id` field in `SignedLicense` is still decoded but ignored by the client
- If the server rotates signing keys, a new app binary must be shipped with the updated pinned key **before** activating the new key on the server

## Server Changes Required

### 1. Remove the `GET /api/sdk/public-keys` endpoint

Delete the route handler and any associated code:
- The route registration (e.g., `router.GET("/api/sdk/public-keys", ...)`)
- The handler function that returns `PublicKeysResponse`
- Any middleware specific to this endpoint

### 2. Remove the public keys response models (if only used by this endpoint)

The response had this shape:

```json
{
  "active_key_id": "key-1",
  "keys": [
    {
      "key_id": "key-1",
      "public_key_b64": "wELIbL12VUOKNnIEHA14tQUjBsSvfYT+foq9UzgZJJ8=",
      "active": true
    }
  ]
}
```

Remove the Go structs/types backing this response if they are no longer referenced elsewhere.

### 3. Keep the signing key infrastructure on the server

The server still needs to:
- Store the Ed25519 **private** signing key
- Sign `LicensePayload` during `POST /api/license/activate`
- Include `signature` and `key_id` in the `SignedLicense` response (the client ignores `key_id` but it's harmless to keep for logging/auditing)

The `POST /api/license/activate` response shape is **unchanged**:

```json
{
  "payload": {
    "bundle_id": "de.stevio.KezboardSwitcher",
    "license_key": "...",
    "machine_hash": "...",
    "activated_at": "..."
  },
  "signature": "<base64 Ed25519 signature>",
  "key_id": "key-1"
}
```

### 4. Key rotation procedure (future)

When you need to rotate the signing key:

1. Generate a new Ed25519 keypair on the server
2. Ship a new app binary with the new public key pinned in `LicenseService.pinnedPublicKeyB64`
3. Wait for distribution / availability of the new binary
4. Switch the server to sign with the new private key
5. Old binaries will fail activation with a clear "please update" error

## What NOT to Change

- `POST /api/license/activate` — no changes needed
- `POST /api/license/deactivate` — no changes needed
- The signing logic on the server — still signs with Ed25519 as before
- The `key_id` field in responses — keep it for server-side auditing, the client just ignores it
