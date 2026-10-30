-- Explicit additive planning upgrade. Never run without protected recovery.
BEGIN;
SELECT pg_advisory_xact_lock(744502024001);
DO $planning$
BEGIN
 IF to_regclass('public."Owners"') IS NULL OR to_regclass('public."JournalEntries"') IS NULL
 OR to_regclass('public."BankSchemaVersions"') IS NULL THEN
   RAISE EXCEPTION 'Verified baseline missing';
 END IF;
 IF (SELECT "Version" FROM "BankSchemaVersions" WHERE "Id"=1) IS DISTINCT FROM 1
 OR (SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN
 ('Owners','Sessions','LedgerAccounts','JournalEntries','LedgerPostings','OperationRecords','ChangeRecords',
  'BankConnections','BankAccounts','BankSources','BankSourceRevisions','BankBatches','BankEvents','BankSchemaVersions')) <> 14 THEN
   RAISE EXCEPTION 'Unrecognized baseline; refusing planning upgrade';
 END IF;
 IF to_regclass('public."PlanningSchemaVersions"') IS NOT NULL THEN
   IF (SELECT "Version" FROM "PlanningSchemaVersions" WHERE "Id"=1) IS DISTINCT FROM 1
   OR (SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN
       ('PlanningSchemaVersions','PlanningWorkspaces','PlanningEvents')) <> 3 THEN
     RAISE EXCEPTION 'Unknown planning schema';
   END IF;
   RETURN;
 END IF;
 IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('PlanningWorkspaces','PlanningEvents')) THEN
   RAISE EXCEPTION 'Partial planning schema';
 END IF;
 CREATE TABLE "PlanningSchemaVersions" ("Id" integer PRIMARY KEY, "Version" integer NOT NULL);
 CREATE TABLE "PlanningWorkspaces" ("OwnerId" uuid PRIMARY KEY, "Version" integer NOT NULL, "PayloadJson" text NOT NULL);
 CREATE TABLE "PlanningEvents" ("Id" uuid PRIMARY KEY,"OwnerId" uuid NOT NULL,"OperationId" uuid NOT NULL,
   "Action" character varying(40) NOT NULL,"ObjectId" character varying(150) NOT NULL,"Version" integer NOT NULL,
   "DetailsJson" text NOT NULL,"CreatedUtc" timestamp with time zone NOT NULL);
 CREATE INDEX "IX_PlanningEvents_OwnerId_CreatedUtc" ON "PlanningEvents" ("OwnerId","CreatedUtc");
 INSERT INTO "PlanningSchemaVersions" VALUES (1,1);
END $planning$;
COMMIT;
