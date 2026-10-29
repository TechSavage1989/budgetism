/// Detached fictional server data. Never a ledger transaction or local import.
class SandboxPreview {
  SandboxPreview._(this.ready, List<SandboxActivity> activity)
    : activity = List.unmodifiable(activity);
  final bool ready;
  final List<SandboxActivity> activity;

  factory SandboxPreview.fromJson(Object? input) {
    if (input is! Map ||
        input['fictional'] != true ||
        input['ready'] is! bool ||
        input['changes'] is! List) {
      throw const FormatException('Invalid fictional preview.');
    }
    final changes = input['changes'] as List;
    if (changes.length > 50000 ||
        (input['ready'] == false && changes.isNotEmpty)) {
      throw const FormatException('Invalid preview batch.');
    }
    return SandboxPreview._(
      input['ready'] as bool,
      changes.map(SandboxActivity.fromJson).toList(),
    );
  }
}

class SandboxActivity {
  const SandboxActivity._(
    this.kind,
    this.accountId,
    this.sourceId,
    this.amountMinor,
    this.date,
    this.description,
    this.pending,
    this.pendingSourceId,
  );
  final String kind, accountId, sourceId;
  final int? amountMinor;
  final String? date, description, pendingSourceId;
  final bool? pending;

  factory SandboxActivity.fromJson(Object? input) {
    if (input is! Map) throw const FormatException('Invalid preview row.');
    String text(String key, int max) {
      final value = input[key];
      if (value is! String || value.trim().isEmpty || value.length > max) {
        throw const FormatException('Invalid preview field.');
      }
      return value;
    }

    final kind = text('kind', 10);
    if (!const ['added', 'modified', 'removed'].contains(kind)) {
      throw const FormatException('Invalid preview change.');
    }
    final account = text('accountId', 256), source = text('sourceId', 256);
    if (kind == 'removed') {
      if (const [
        'amountMinor',
        'date',
        'description',
        'pending',
        'pendingSourceId',
      ].any((field) => input[field] != null)) {
        throw const FormatException('Invalid removal tombstone.');
      }
      return SandboxActivity._(
        kind,
        account,
        source,
        null,
        null,
        null,
        null,
        null,
      );
    }
    final amount = input['amountMinor'];
    if (amount is! int ||
        amount < -99999999999999 ||
        amount > 99999999999999 ||
        input['pending'] is! bool) {
      throw const FormatException(
        'Invalid exact-cent preview amount or status.',
      );
    }
    final date = text('date', 10);
    final parsed = DateTime.tryParse(date);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        parsed == null ||
        parsed.year < 1 ||
        parsed.toIso8601String().substring(0, 10) != date) {
      throw const FormatException('Invalid preview date.');
    }
    final predecessor =
        input['pendingSourceId'] == null ? null : text('pendingSourceId', 256);
    return SandboxActivity._(
      kind,
      account,
      source,
      amount,
      date,
      text('description', 500),
      input['pending'] as bool,
      predecessor,
    );
  }
}
