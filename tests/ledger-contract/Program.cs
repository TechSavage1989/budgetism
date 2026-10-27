using Budgetism.Api;

var owner = Guid.NewGuid();
var checking = Guid.NewGuid();
var savings = Guid.NewGuid();
var card = Guid.NewGuid();
var equity = Guid.NewGuid();
var expense = Guid.NewGuid();
var income = Guid.NewGuid();
var date = new DateOnly(2026, 10, 27);
var amounts = new Dictionary<Guid, long>();
var entries = new List<JournalEntry>();

void Record(JournalEntry entry)
{
    LedgerRules.AssertBalanced(entry);
    entries.Add(entry);
    foreach (var posting in entry.Postings)
        amounts[posting.LedgerAccountId] = checked(amounts.GetValueOrDefault(posting.LedgerAccountId) + posting.AmountMinor);
}
void Check(bool condition, string description)
{
    if (!condition) throw new Exception($"FAIL: {description}");
    Console.WriteLine($"PASS: {description}");
}

Record(LedgerRules.CreateOpening(owner, Guid.NewGuid(), date, checking, equity, 100_000, "USD"));
Check(amounts[checking] == 100_000, "Opening balance $1,000.00");
Record(LedgerRules.Create(owner, Guid.NewGuid(), date, "expense", checking, expense, 8_000, "USD", "Groceries", ""));
Check(amounts[checking] == 92_000 && amounts[expense] == 8_000,
    "AT-002: $80 expense leaves $920 and $80 category expense");
Record(LedgerRules.Create(owner, Guid.NewGuid(), date, "transfer", checking, savings, 20_000, "USD", "Savings transfer", ""));
Check(amounts[checking] == 72_000 && amounts[savings] == 20_000 &&
      amounts[checking] + amounts[savings] == 92_000 && amounts[expense] == 8_000,
    "AT-003: $200 transfer preserves assets and spending");
Record(LedgerRules.Create(owner, Guid.NewGuid(), date, "expense", card, expense, 12_500, "USD", "Credit card purchase", ""));
Check(amounts[card] == -12_500 && amounts[expense] == 20_500,
    "AT-004: Credit card purchase raises expense and liability");
Record(LedgerRules.Create(owner, Guid.NewGuid(), date, "transfer", checking, card, 12_500, "USD", "Credit payment", ""));
Check(amounts[card] == 0 && amounts[checking] == 59_500 && amounts[expense] == 20_500,
    "AT-004: Credit card payment clears liability with no extra spending");

var rejected = false;
try { LedgerRules.Create(owner, Guid.NewGuid(), date, "expense", checking, expense, 0, "USD", "", ""); }
catch (ArgumentOutOfRangeException) { rejected = true; }
Check(rejected, "Zero transaction amount rejected");
rejected = false;
try { LedgerRules.Create(owner, Guid.NewGuid(), date, "expense", checking, expense, 100, "EUR", "", ""); }
catch (ArgumentException) { rejected = true; }
Check(rejected, "Cross-currency posting rejected until FX is implemented");
Check(entries.All(e => e.Postings.Count == 2 && e.Postings.Sum(p => p.AmountMinor) == 0),
    "Every journal entry balances exactly");
Console.WriteLine("All ledger contract tests passed.");
