# Private-server Sandbox client preview

The dev.19 client candidate adds a read-only Sandbox panel to Connections when
signed into a private server. The local fictional bank pipeline and saved local
workspaces remain separate. No local workspace is uploaded, upgraded or imported
by this panel. Real bank linkage and durable server bank ingestion are unfinished.

## Use the preview

1. Use a verified client package with its exact archive/extracted Defender evidence.
   Keep the existing program and independent encrypted workspace backups.
2. At the welcome screen, enter your trusted private HTTPS server URL and choose
   Connect to server. Enter your Budgetism owner username/password locally.
   The client refuses plaintext server connection before requesting credentials.
   Do not enter a Plaid secret or bank password in the application.
3. Open Connections and choose Retrieve fictional activity. This is the only action
   that retrieves the Sandbox preview. Navigating, reading, the ordinary account
   snapshot refresh and timers never retrieve provider activity.
4. Review the fictional account groups, dates, USD money-in/out amounts and
   pending/posted/removed status. These are changes reported by the source, not
   account balances or spending totals. Pending activity is not posted. A removal
   has no invented amount. No record, map, approve or import action is offered.
5. A new request clears the prior preview while loading. A failure never leaves
   old results looking current. Closing the panel or signing out discards its data;
   a late response cannot reappear in another session.

The panel keeps the preview in memory only. Server credentials remain in the
server's protected secret files. Owner bearer sessions remain in client memory.
The transport uses normal certificate validation, refuses redirects, limits the
client response to 4 MiB and allows 95 seconds for the bounded server request.
No provider response/error bodies or transport exception text appear in errors.
Rendering initially shows 50 changes; Show 50 more changes is a local display action.

This panel requires the verified [Sandbox API](PLAID_SANDBOX_PREVIEW.md), protected
server-side Sandbox credentials and a controlled exact-cent USD fixture. The API
continues to reject fractional cents. If data is not ready, request it again later.
Expired sessions require sign-in; disabled setup requires local administrator
configuration. Never bypass HTTPS/certificate errors.

## Verification

Unit/widget contracts cover strict fictional data/amount/date validation, removal
tombstones, empty not-ready batches, HTTPS/auth/redirect guards, response limits,
sanitized failures, session changes, explicit single-flight retrieval and real
server Connections navigation. A native Windows test uses fictional data and a
separate temporary encrypted workspace to verify no writes across preview,
failure and navigation. Its screenshot artifact contains invented data only.
The retained native tests and package/security gates remain enabled.

The source candidate is not a delivery until full CI, native checks, package
verification and exact archive/extracted scans pass. The dev.18 package remains
the previously user-confirmed desktop baseline until the new client is verified.
