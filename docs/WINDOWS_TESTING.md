# Budgetism dev.3 Windows testing

## Back up the current workspace

In dev.2, open User options > Backups and storage and export an encrypted backup. Keep the original password separately. Close all Budgetism windows before opening dev.3. No server setup or development tools are needed.

## Download and launch

Open [successful build 40604743739](https://github.com/TechSavage1989/budgetism/actions/runs/40604743739) while signed in to GitHub. Under Artifacts, download **Budgetism-Windows-x64-development**. Extract the outer ZIP, then extract **Budgetism-Windows-x64.zip** inside it into a separate testing folder.

Run **Budgetism.exe** inside the extracted Budgetism folder, with its supporting files beside it, under the same Windows account as dev.2. The opening screen should say **0.1.0-dev.3**. The database is stored separately under your Windows profile; do not copy, delete or replace it when extracting the program.

## Disable the routine password prompt

1. Select **Open local workspace** and enter the existing workspace password.
2. Open **User options > Workspace security**.
3. Turn off **Require a password to open this workspace**.
4. Enter **Current workspace password** once and select **Save**.
5. Confirm the saved message, close the dialog and check your accounts and transactions.
6. Close Budgetism completely, reopen dev.3, and select **Open local workspace**. It should open without a password prompt and retain the same records and balances.

The same switch enables protection again, asking for a new password and confirmation of at least 14 characters. New workspace setup defaults to password-free access unless you choose otherwise. Do not create a new workspace to change an existing workspace's setting.

## Important recovery details

Financial records remain encrypted in both modes. Password-free access relies on the Windows user profile and OS-protected device key. Anyone using that Windows account can open the workspace. Copying only the SQLite database is not a portable recovery method.

Dev.3 backup exports ask for a separate backup password; this does not turn the local password prompt back on. Existing backups still require their original password. There is no password/key recovery.

Changing security upgrades the encrypted format. **Do not use dev.2 against the converted database.** Keep the pre-change backup for recovery rather than deleting or replacing application-data files to troubleshoot.

This remains a development preview. Automated Windows key-store/process tests passed, but these steps confirm the actual end-user workflow on your PC. Cross-device synchronization, budgets and updater installation are not included in this milestone.
