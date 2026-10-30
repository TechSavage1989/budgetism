import 'ledger.dart';

/// Explicit workspace boundary: a read snapshot and deliberate planning commands.
abstract interface class PlanningWorkspaceApi {
  Json get planningSnapshot;
  Future<void> saveBudget(Json data);
  Future<void> removeBudget(Json data);
  Future<void> copyBudgets(Json data);
  Future<void> saveSchedule(Json data);
  Future<void> setSchedulePaused(Json data);
  Future<void> matchOccurrence(Json data);
  Future<void> confirmOccurrence(Json data);
  Future<void> postponeOccurrence(Json data);
  Future<void> skipOccurrence(Json data);
}
