# Dev.27 coordinated update work — candidate

The user requested automatic updates for both the Windows desktop app and the
existing private backend on October 30. This engineering increment continues
verified dev.26; it is not permission to recreate the server or reset its data.
Implementation and hosted acceptance are in progress. Nothing described below
is claimed installed or enabled on the user's server.

## Desktop behavior and safety

The intended setting is opt-in automatic verified download, followed by apply
on the next launch **before** any financial session, vault or connection opens.
Never terminate a running financial session, discard an unsaved form, retry an
uncertain financial command or reboot the machine to apply an update.

Pending metadata contains public version/digest information only. Executable and
installation paths must derive from the running program, not downloaded metadata.
Require update protocol 1 and client API contract 1, immutable package staging,
single-attempt admission, another-instance refusal and an exact version/nonce
readiness handshake. Failed admission keeps the prior app usable; failed new-app
readiness restores the prior program. An interrupted or failed attempt must not
loop on every launch. Existing local workspaces and device settings stay outside
the replaced program folder.

## Backend behavior and safety

Use a separately manifested **API-only** package. The existing full server test
kit contains PostgreSQL, new-installation scripts and migration SQL and must not
be treated as an unattended upgrade payload.

The existing API service identity is deliberately read/execute only. Do not give
it administrator privileges or access to protected database-admin secrets just
to make self-update possible. A coordinator runs only in a separately authorized
existing administrative context. Automatic scheduling/installation is a host
enablement step, not silently created by a repository build.

Before replacement, require a known current program identity, exact supported
existing schema, compatible client/API contracts, a verified candidate and
protected recovery evidence. Quiesce the API, preserve the database service and
data, and test the candidate in a maintenance gate before accepting traffic.
Never run automatic SQL migrations, initialize an empty database, reset an owner,
rotate keys, replace PostgreSQL or alter IIS/firewall settings. Program rollback
is not database rollback: never overwrite newer financial writes with a backup.

## Trust and distribution

Existing release discovery uses the public GitHub repository over validated
HTTPS and requires GitHub's asset SHA-256. This authenticates retrieval from the
configured repository and checks byte integrity; it is not publisher signing or
protection from a compromised release publisher. Unsigned development status
must remain visible. A release manifest must not broaden supported contracts.

No release has yet been published for this work. At 17:23 the user approved
tested desktop and API application-only development prereleases in the existing
repository. Publication remains gated on exact successful validation and scans. GitHub Actions development artifacts
are not automatically discovered by the release feed. The initial dev.24–26
installation has no integrated installer; a separately verified one-time
bootstrap is required before later automatic updates can operate.

## Delivery gates and current blockers

- Native genuine previous/new app swap, preserved settings/custom launch name,
  corrupt/wrong-version/future-contract rejection, failed-readiness rollback,
  another-instance refusal and interrupted-attempt recovery.
- Backend known-version/schema compatibility, quiescence, recovery, healthy
  API-only replacement, failed-health program rollback, and no data/key/owner
  changes using disposable hosted Windows services and PostgreSQL.
- Retain all prior financial, native, package and exact-archive security checks.
- The last documented installed server/client is dev.24. Its old health endpoint
  reports dev.1 and cannot prove installation identity; inspect the actual binary
  and deployment metadata during authorized bootstrap rather than trusting that
  stale string.
- Server2025 access became authorized at 17:27 and a separate read-only inspection
  was started. Bootstrap, scheduler and deployment remain pending exact test
  completion and reviewed installation prerequisites; inspection is not deployment.
- The approved destination is the existing repository development-prerelease
  channel. A separate pinned publication request is required after testing;
  ordinary candidate pushes and update settings do not publish releases.

This document is a candidate contract, not completed acceptance evidence. Record
the final exact source, tests, artifacts and remaining limits before delivery.
