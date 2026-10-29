import 'csv_import.dart';
import 'ledger.dart';

/// Converts reviewed column indexes to unique header names, then resolves names
/// against a later file. Extra columns are ignored; no positional fallback.
class CsvProfiles {
  static Json capture(CsvTable table, CsvMapping mapping, {required String delimiter,
      String? expenseCategoryId, String? incomeCategoryId, required List<Json> categories}) {
    mapping.validate(table.headers.length);
    String? header(int index) {
      if (index < 0) return null;
      if (index >= table.headers.length) throw const FormatException('CSV column is no longer available.');
      final value = table.headers[index];
      if (table.headers.where((h) => ImportProfiles.headerKey(h) == ImportProfiles.headerKey(value)).length != 1) {
        throw FormatException('Cannot save a profile: the mapped header "$value" appears more than once. Use manual mapping.');
      }
      return value;
    }
    final signed = mapping.amountColumn >= 0;
    return ImportProfiles.settings({
      'delimiter': delimiter, 'dateFormat': mapping.dateFormat, 'amountMode': signed ? 'signed' : 'separate',
      'reverseSign': signed && mapping.reverseSign,
      'columns': {'date': header(mapping.dateColumn), 'payee': header(mapping.payeeColumn),
        'amount': signed ? header(mapping.amountColumn) : null,
        'debit': signed ? null : header(mapping.debitColumn), 'credit': signed ? null : header(mapping.creditColumn),
        'reference': header(mapping.referenceColumn), 'notes': header(mapping.notesColumn)},
      'expenseCategoryId': expenseCategoryId, 'incomeCategoryId': incomeCategoryId,
    }, categories);
  }

  static CsvMapping resolve(Json profile, CsvTable table, List<Json> categories) {
    if (profile['archived'] != false) throw const FormatException('Restore this profile before using it.');
    final s = ImportProfiles.settings(profile['settings'], categories);
    final columns = Map<String, dynamic>.from(s['columns'] as Map);
    int index(String field) {
      final label = columns[field];
      if (label == null) return -1;
      final matches = <int>[for (var i = 0; i < table.headers.length; i++)
        if (ImportProfiles.headerKey(table.headers[i]) == ImportProfiles.headerKey(label as String)) i];
      if (matches.length != 1) {
        throw FormatException('Profile not applied: header "$label" is missing or appears more than once. Choose manual mapping or another profile.');
      }
      return matches.single;
    }
    final result = CsvMapping(dateColumn: index('date'), payeeColumn: index('payee'),
      amountColumn: index('amount'), debitColumn: index('debit'), creditColumn: index('credit'),
      referenceColumn: index('reference'), notesColumn: index('notes'),
      dateFormat: s['dateFormat'] as String, reverseSign: s['reverseSign'] as bool);
    result.validate(table.headers.length);
    return result;
  }
}
