# Remembering a private server address

Dev.21 adds optional address continuity to the welcome screen. The previous
insecure HTTP placeholder is removed; a new device starts with an empty field
and a trusted-HTTPS hint. **Remember server address on this device** starts off.
After the user opts in and explicitly connects successfully over normal HTTPS,
only the canonical base address is stored in a device preference. The UI discloses
that this address is stored without encryption. Owner usernames/passwords,
bootstrap secrets, sessions, provider credentials and financial records are not
read from input fields into that preference.

Restoring a remembered address never connects, signs in, retrieves provider data
or opens a local workspace. A web build's explicit `API_BASE_URL` keeps its earlier
setup-status handshake, but that automatic handshake does not write preferences.
Userinfo, queries, fragments, plaintext HTTP, invalid ports and malformed addresses
are rejected. Reverse-proxy base paths remain supported. A failed handshake
preserves the earlier saved address. Failed preference writes do not block a
successful connection. **Forget saved address**, or unchecking the option, removes
only that preference and preserves other settings and all financial records.

Typing a new destination invalidates in-flight setup responses, clears credential
fields and returns to connection setup. A late preference read cannot overwrite
typed text. Credentials cannot be edited or redirected during an active sign-in;
disposed/obsolete responses cannot sign a different screen in. Errors are curated
without echoing network exception bodies. No owner password or bearer session is
persisted and there is no automatic sign-in.

Validation retains all earlier checks and adds preference/connection tests plus
two native Windows processes. The native tests use a uniquely named fictional
preference key, never the user's normal address key, and remove that test key
after independent-process reload and Forget verification. A fictional welcome
screenshot is retained for layout review. This is client-only: the verified dev.20
API, bank schema, source checkpoint, account mapping and ledger remain unchanged.
Full package/native/security checks are required before delivery.
