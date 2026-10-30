import '../finance_api.dart';
import 'ledger.dart';
import 'vault.dart';
import 'bank_provider.dart';
import 'planning_api.dart';

class LocalFinanceApi extends FinanceApi implements PlanningWorkspaceApi {
  LocalFinanceApi(this.vault) : super('local://encrypted-workspace');
  final LocalVault vault;
  @override
  Json get planningSnapshot => {
    ...vault.ledger.snapshot(includeVoided: true),
    'audit': LocalLedger.rows(vault.ledger.data['audit'] ?? <Json>[]).map(LocalLedger.clone).toList(),
  };
  late final BankRefreshService bankRefresh = BankRefreshService(vault);
  Future<void> connectSimulation(Json data) => vault.apply('bank-connect', data);
  Future<void> setBankConnected(Json data) => vault.apply('bank-state', data);
  Future<void> reviewBankSource(Json data) => vault.apply('bank-review', data);
  @override
  Future<Map<String, dynamic>> snapshot() async {
    await vault.refresh();
    return vault.ledger.snapshot();
  }
  @override
  Future<void> createAccount(Json data) => vault.apply('account', data);
  @override
  Future<void> createTransaction(Json data) => vault.apply('transaction', data);
  Future<void> undoCategoryBatch(Json data) => vault.apply('category-undo', data);
  Future<void> saveCategoryRule(Json data) => vault.apply('category-rule', data);
  Future<void> applyCategoryRules(Json data) => vault.apply('categorize', data);
  Future<void> reconcile(Json data) => vault.apply('reconcile', data);
  Future<void> reopenStatement(Json data) => vault.apply('reconcile-reopen', data);
  Future<void> saveImportProfile(Json data) => vault.apply('import-profile', data);
  Future<void> archiveImportProfile(Json data) => vault.apply('import-profile-state', data);
  Future<void> importCsv(Json data) => vault.apply('import-csv', data);
  Future<void> saveCategory(Json data) => vault.apply('category', data);
  Future<void> voidTransaction(Json data) => vault.apply('void', data);
  @override
  Future<void> saveBudget(Json data) => vault.apply('budget', data);
  @override
  Future<void> removeBudget(Json data) => vault.apply('budget-remove', data);
  @override
  Future<void> copyBudgets(Json data) => vault.apply('budget-copy', data);
  @override
  Future<void> saveSchedule(Json data) => vault.apply('schedule', data);
  @override
  Future<void> setSchedulePaused(Json data) => vault.apply('schedule-state', data);
  @override
  Future<void> matchOccurrence(Json data) => vault.apply('schedule-match', data);
  @override
  Future<void> confirmOccurrence(Json data) => vault.apply('schedule-confirm', data);
  @override
  Future<void> postponeOccurrence(Json data) => vault.apply('schedule-postpone', data);
  @override
  Future<void> skipOccurrence(Json data) => vault.apply('schedule-skip', data);
  @override
  Future<void> logout() => vault.close();
}
