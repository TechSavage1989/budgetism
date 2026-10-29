using Budgetism.Api;
using Microsoft.EntityFrameworkCore;
using Npgsql;

if (args.Length == 2 && args[0] == "--generate-schema")
{
    using var model = new FinanceDb(new DbContextOptionsBuilder<FinanceDb>().UseNpgsql("Host=localhost;Database=fictional;Username=fictional").Options);
    var statements = model.Database.GenerateCreateScript().Split(';', StringSplitOptions.RemoveEmptyEntries)
        .Select(s => s.Trim()).Where(s => s.StartsWith("CREATE TABLE \"Bank", StringComparison.Ordinal) ||
            ((s.StartsWith("CREATE INDEX", StringComparison.Ordinal) || s.StartsWith("CREATE UNIQUE INDEX", StringComparison.Ordinal)) && s.Contains(" ON \"Bank", StringComparison.Ordinal))).ToArray();
    if (statements.Count(s => s.StartsWith("CREATE TABLE", StringComparison.Ordinal)) != 7) throw new Exception("Expected seven additive bank tables.");
    var sql = """
    -- Explicit additive Sandbox source schema v1. No existing table or row is altered.
    -- Run only after a protected backup/restore check, as the application schema owner.
    BEGIN;
    SELECT pg_advisory_xact_lock(744502019001);
    DO $budgetism_bank_schema$
    DECLARE existing_version integer;
    BEGIN
      IF to_regclass('public."Owners"') IS NULL OR to_regclass('public."LedgerAccounts"') IS NULL
         OR to_regclass('public."JournalEntries"') IS NULL OR to_regclass('public."LedgerPostings"') IS NULL
         OR to_regclass('public."Sessions"') IS NULL OR to_regclass('public."OperationRecords"') IS NULL
         OR to_regclass('public."ChangeRecords"') IS NULL THEN
        RAISE EXCEPTION 'Budgetism baseline tables are missing; refusing upgrade';
      END IF;
      IF to_regclass('public."BankSchemaVersions"') IS NOT NULL THEN
        EXECUTE 'SELECT "Version" FROM "BankSchemaVersions" WHERE "Id"=1' INTO existing_version;
        IF existing_version IS DISTINCT FROM 1 OR
           (SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN
             ('BankConnections','BankAccounts','BankSources','BankSourceRevisions','BankBatches','BankEvents','BankSchemaVersions')) <> 7 THEN
          RAISE EXCEPTION 'Unrecognized or incomplete bank schema; refusing upgrade';
        END IF;
        RETURN;
      END IF;
      IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name IN
          ('BankConnections','BankAccounts','BankSources','BankSourceRevisions','BankBatches','BankEvents')) THEN
        RAISE EXCEPTION 'Partial bank schema found; refusing upgrade';
      END IF;
    """;
    sql += "\n" + string.Join(";\n", statements) + ";\n";
    sql += "INSERT INTO \"BankSchemaVersions\" (\"Id\",\"Version\") VALUES (1,1);\nEND\n$budgetism_bank_schema$;\nCOMMIT;\n";
    File.WriteAllText(args[1], sql);
    Console.WriteLine("PASS: Generated seven-table additive schema; existing ledger DDL excluded.");
    return;
}
await Contracts.RunAsync(args);
