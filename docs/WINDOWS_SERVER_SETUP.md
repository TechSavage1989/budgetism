# Windows Server preparation

Status: server smoke-test preparation. The user has authorized a private Windows Server 2025 deployment. The existing API is not yet a completed Plaid service, and dev.18 remains the verified desktop build.

Private-session follow-up: the existing permanent services, loopback HTTPS,
owner setup and protected database backup/isolated restore were verified. The
user requested leaving the existing firewall unchanged; LAN access remains
disabled. A separate Plaid Sandbox smoke test retrieved 316 fictional changes
and removed its temporary Item without writing ledger records. Keep host-specific
addresses, certificate trust, credentials and backup paths in private operations
notes. Never rerun the installer over that installation.

The next [Sandbox preview API](PLAID_SANDBOX_PREVIEW.md) is an authenticated,
disabled-by-default source candidate. It requires a verified API upgrade and
separate protected Sandbox credential provisioning before use. It does not
change the database schema or enable real bank linkage.

## Packaged server test

## Permanent development services

After the smoke test passes, use a package whose permanent-service CI test and Defender scan have passed. Open Windows PowerShell as Administrator in the extracted package folder, and run the installer with a new destination folder:

```powershell
powershell.exe -NoProfile -File .\Install-BudgetismServer.ps1 -InstallDirectory D:\Data\Budgetism\PrivateServer
```

The installer creates BudgetismDatabase and BudgetismApi under separate Windows virtual service accounts. Database port 55432 and API port 55080 bind only to 127.0.0.1. It generates restricted credentials on the server; the API receives a database role without superuser, role-creation or database-creation privileges. Database administrator credentials are not readable by the API service. Program files are read-only for both services. No credentials appear in command arguments or user-facing output.

The installer verifies health and an orderly service restart before setting automatic startup. Existing folders, services or occupied ports cause refusal. A failure stops only the services created by that invocation, leaves them manual, and preserves data for diagnosis; do not delete or rerun over that folder. The installer creates a fresh empty database, not a copy of smoke-test or desktop records. Owner enrollment is disabled. There is no LAN listener, firewall change, IIS change, bank connection or recurring bank refresh. Secure HTTPS/client trust, owner enrollment, database backup/restore and Plaid integration are subsequent work before use with real financial data.

Windows service behavior follows [Microsoft service hosting](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/windows-service?view=aspnetcore-10.0) and PostgreSQL's [pg_ctl service registration](https://www.postgresql.org/docs/current/app-pg-ctl.html).

## Run the smoke test

Extract the complete server-test ZIP into a new folder on the server. In Windows PowerShell in that folder, run:

```powershell
powershell.exe -NoProfile -File .\Test-BudgetismServer.ps1
```

This package includes a private .NET 10 runtime and PostgreSQL 18.6 binaries. It does not install or upgrade the shared .NET runtime or IIS. It verifies the packaged file hashes, creates a new restricted folder and fictional database, and tests the API on loopback ports 55080 and 55432. It checks authentication, exact-cent balances, duplicate-safe retries and logout, then stops the test processes. No firewall rule, Windows service, certificate, scheduled task, bank link or Plaid credential is created. Existing occupied test ports cause a stop before initialization.

The test retains its fictional database and logs in a new runs subfolder for diagnosis. Generated test passwords are random and never printed. Return the PASS lines or error summary, not the credential files. This is an environment test, not a permanent installation or verified dev.19 desktop release. Native service registration, secure LAN HTTPS, recovery tests and Plaid integration are still outstanding.

Build the kit with scripts/package_server_test.ps1 using the .NET SDK and the official PostgreSQL Windows archive. Include PostgreSQL and command-line tool license notices. Never package runs, credentials or user databases. The local test uses the same packaged executables intended for the server; rerun it there because local success does not establish server compatibility.

Sources: [Microsoft Windows service hosting](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/windows-service?view=aspnetcore-10.0), [Microsoft .NET installation](https://learn.microsoft.com/en-us/dotnet/core/install/windows), and [official PostgreSQL Windows distribution](https://www.postgresql.org/download/windows/).

## Read-only inventory

Copy scripts/server_readiness.ps1 to the server through Remote Desktop. Open Windows PowerShell in the containing folder and run:

```powershell
powershell.exe -NoProfile -File .\server_readiness.ps1
```

The script prints a JSON report of Windows/runtime versions, PostgreSQL service status, IIS/Docker presence, relevant listening ports and disk space. It does not install software, change firewall rules, start services, read credentials or contact Plaid. Docker presence does not establish that it is supported or usable on this server. If Windows blocks script execution, report the message rather than weakening machine-wide policy.

Use the report to select the native .NET/PostgreSQL deployment and avoid existing service/port conflicts. Further work must provide a dedicated service identity, restricted secret storage, authenticated HTTPS access, database initialization/upgrade and recovery checks before enabling any LAN endpoint. Do not send existing local workspaces to the server as part of setup. Test with fictional records before real bank authorization.

No installer, server deployment, live bank connection or new verified Windows application package is claimed by this readiness check.
