import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'ledger.dart';

/// A bounded CSV reader. Values are literal text, never spreadsheet expressions.
class CsvTable {
  CsvTable(this.headers, this.records, this.digest);
  final List<String> headers;
  final List<List<String>> records;
  final String digest;
  static const maxBytes = 2 * 1024 * 1024;
  static const maxRows = 1000;
  static CsvTable parse(String input, {String delimiter = ','}) {
    if (![',', ';', '\t'].contains(delimiter)) throw const FormatException('Choose a supported separator.');
    if (utf8.encode(input).length > maxBytes) throw const FormatException('CSV exceeds the 2 MB limit.');
    final digest = sha256.convert(utf8.encode(input)).toString();
    final text = input.startsWith('\uFEFF') ? input.substring(1) : input;
    if (text.contains('\u0000')) throw const FormatException('Use UTF-8 CSV, not a binary or UTF-16 file.');
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    var closed = false;
    void endField() {
      if (field.length > 4096) throw const FormatException('A CSV field exceeds 4096 characters.');
      row.add(field.toString()); field = StringBuffer(); closed = false;
      if (row.length > 40) throw const FormatException('CSV supports up to 40 columns.');
    }
    void endRow() {
      endField(); rows.add(row); row = <String>[];
      if (rows.length > maxRows + 1) throw const FormatException('CSV supports up to 1000 data rows per file.');
    }
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') { field.write('"'); i++; }
          else { quoted = false; closed = true; }
        } else { field.write(c); }
      } else if (c == delimiter) {
        endField();
      } else if (c == '\r' || c == '\n') {
        endRow();
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      } else if (closed) {
        throw const FormatException('Unexpected text after a quoted CSV field.');
      } else if (c == '"') {
        if (field.isNotEmpty) throw const FormatException('Quotes must surround the complete CSV field.');
        quoted = true;
      } else { field.write(c); }
      if (field.length > 4096) throw const FormatException('A CSV field exceeds 4096 characters.');
    }
    if (quoted) throw const FormatException('CSV contains an unclosed quoted field.');
    if (field.isNotEmpty || row.isNotEmpty || closed) endRow();
    if (rows.length < 2 || rows.first.length < 3) throw const FormatException('CSV needs a header and at least one data row, with three or more columns.');
    final headers = rows.first.map((h) => h.trim()).toList();
    if (headers.any((h) => h.isEmpty || h.length > 100)) throw const FormatException('Every column needs a header of 1 to 100 characters.');
    return CsvTable(headers, rows.skip(1).toList(), digest);
  }
}

class CsvMapping {
  const CsvMapping({required this.dateColumn, required this.payeeColumn,
    this.amountColumn = -1, this.debitColumn = -1, this.creditColumn = -1,
    this.referenceColumn = -1, this.notesColumn = -1, this.dateFormat = 'ymd', this.reverseSign = false});
  final int dateColumn, payeeColumn, amountColumn, debitColumn, creditColumn, referenceColumn, notesColumn;
  final String dateFormat;
  final bool reverseSign;
  void validate(int columns) {
    if (!['ymd', 'mdy', 'dmy'].contains(dateFormat)) throw const FormatException('Choose a date format.');
    final used = [dateColumn, payeeColumn,
      if (amountColumn >= 0) amountColumn else ...[debitColumn, creditColumn],
      if (referenceColumn >= 0) referenceColumn, if (notesColumn >= 0) notesColumn];
    if (used.any((i) => i < 0 || i >= columns) || used.toSet().length != used.length) {
      throw const FormatException('Map each required field to a different CSV column.');
    }
  }
}

class CsvEntry {
  CsvEntry(this.rowNumber, this.values, this.error);
  final int rowNumber;
  final Json? values;
  final String? error;
}

class CsvImport {
  static String date(String input, String format) {
    final value = input.trim();
    String result;
    if (format == 'ymd') {
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) throw const FormatException('Expected YYYY-MM-DD.');
      result = value;
    } else {
      final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(value);
      if (match == null || !['mdy', 'dmy'].contains(format)) throw const FormatException('Expected a slash-separated date with a four-digit year.');
      final month = match.group(format == 'mdy' ? 1 : 2)!.padLeft(2, '0');
      final day = match.group(format == 'mdy' ? 2 : 1)!.padLeft(2, '0');
      result = '${match.group(3)}-$month-$day';
    }
    LocalLedger.date(result);
    return result;
  }
  /// US decimal-point USD only. No float parsing, rounding or locale guessing.
  static int amount(String input, {bool emptyIsZero = false}) {
    var value = input.trim();
    if (value.isEmpty && emptyIsZero) return 0;
    var negative = false;
    if (value.startsWith('(') && value.endsWith(')')) {
      negative = true; value = value.substring(1, value.length - 1);
      if (value.startsWith('-') || value.startsWith('+')) throw const FormatException('Conflicting amount signs.');
    } else if (value.startsWith('-') || value.startsWith('+')) {
      negative = value.startsWith('-'); value = value.substring(1);
    }
    if (value.startsWith('\$')) value = value.substring(1);
    if (!RegExp(r'^(?:\d+|[1-9]\d{0,2}(?:,\d{3})+)(?:\.\d{1,2})?$').hasMatch(value)) {
      throw const FormatException('Use USD amounts with a decimal point and at most two decimal places.');
    }
    final parts = value.replaceAll(',', '').split('.');
    final cents = BigInt.parse(parts[0]) * BigInt.from(100) + BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
    if (cents > BigInt.from(LocalLedger.maxMinor)) throw const FormatException('Amount exceeds the supported range.');
    return (negative ? -1 : 1) * cents.toInt();
  }
  static List<CsvEntry> preview(CsvTable table, CsvMapping mapping) {
    mapping.validate(table.headers.length);
    final result = <CsvEntry>[];
    for (var index = 0; index < table.records.length; index++) {
      final row = table.records[index];
      if (row.every((c) => c.trim().isEmpty)) continue;
      try {
        if (row.length != table.headers.length) throw const FormatException('Column count differs from the header.');
        var signed = 0;
        if (mapping.amountColumn >= 0) {
          signed = amount(row[mapping.amountColumn]);
          if (mapping.reverseSign) signed = -signed;
        } else {
          final debit = amount(row[mapping.debitColumn], emptyIsZero: true);
          final credit = amount(row[mapping.creditColumn], emptyIsZero: true);
          if (debit < 0 || credit < 0 || (debit != 0 && credit != 0)) throw const FormatException('Debit and credit must be nonnegative, with only one populated.');
          signed = credit - debit;
        }
        if (signed == 0) throw const FormatException('Zero-amount rows are not transactions.');
        final payee = LocalLedger.text(row[mapping.payeeColumn].replaceAll(RegExp(r'\s+'), ' '), 'Description', 150);
        result.add(CsvEntry(index + 2, {'rowNumber': index + 2,
          'date': date(row[mapping.dateColumn], mapping.dateFormat), 'signedMinor': signed, 'payee': payee,
          'reference': mapping.referenceColumn < 0 ? '' : LocalLedger.text(row[mapping.referenceColumn], 'Unique bank ID', 100, optional: true),
          'notes': mapping.notesColumn < 0 ? '' : LocalLedger.text(row[mapping.notesColumn], 'Notes', 500, optional: true)}, null));
      } on FormatException catch (error) { result.add(CsvEntry(index + 2, null, error.message)); }
    }
    if (result.isEmpty) throw const FormatException('CSV has no data rows.');
    return result;
  }
  static int effect(Json transaction, String accountId) => transaction['voided'] == true ? 0 :
    LocalLedger.rows(transaction['postings']).where((p) => p['ledgerId'] == accountId)
      .fold<int>(0, (sum, p) => sum + (p['amountMinor'] as int));
  static List<Json> candidates(Json snapshot, String accountId, Json row) =>
    LocalLedger.rows(snapshot['transactions']).where((t) => t['voided'] != true &&
      t['effectiveDate'] == row['date'] && effect(t, accountId) == row['signedMinor']).toList();
  static bool consumed(Json snapshot, String accountId, String digest, Json row) =>
    LocalLedger.rows(snapshot['imports'] ?? <Json>[]).any((r) => r['accountId'] == accountId &&
      ((r['fileHash'] == digest && r['rowNumber'] == row['rowNumber']) ||
       (row['reference'] != '' && r['reference'] == row['reference'])));
  static bool transferHint(String payee) => RegExp(r'\b(transfer|xfer|payment|autopay|pmt)\b', caseSensitive: false).hasMatch(payee);
}
