import '../finance_api.dart';
import 'ledger.dart';
import 'vault.dart';

class LocalFinanceApi extends FinanceApi {
  LocalFinanceApi(this.vault) : super('local://encrypted-workspace');
  final LocalVault vault;
  @override
  Future<Map<String, dynamic>> snapshot() async {
    await vault.refresh();
    return vault.ledger.snapshot();
  }
  @override
  Future<void> createAccount(Json data) => vault.apply('account', data);
  @override
  Future<void> createTransaction(Json data) => vault.apply('transaction', data);
  Future<void> saveCategory(Json data) => vault.apply('category', data);
  Future<void> voidTransaction(Json data) => vault.apply('void', data);
  Future<void> saveBudget(Json data) => vault.apply('budget', data);
  Future<void> removeBudget(Json data) => vault.apply('budget-remove', data);
  Future<void> copyBudgets(Json data) => vault.apply('budget-copy', data);
  @override
  Future<void> logout() => vault.close();
}
