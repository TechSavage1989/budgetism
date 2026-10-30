// Validated read model for the private server's fictional source store.
class ServerBankState {
  ServerBankState(
    this.connection,
    this.accounts,
    this.sources,
    this.total,
    this.needsReview,
    this.hasMore, {
    this.batchSupported = false,
  });
  final Map<String, dynamic>? connection;
  final List<Map<String, dynamic>> accounts, sources;
  final int total, needsReview;
  final bool hasMore;
  final bool batchSupported;
  int get version => connection?['version'] as int? ?? 0;
  static ServerBankState parse(Map<String, dynamic> data) {
    Never invalid() => throw const FormatException('Invalid bank state');
    bool integer(dynamic x, [int min = 0, int max = 2147483647]) =>
        x is int && x >= min && x <= max;
    bool text(dynamic x, int max) =>
        x is String && x.isNotEmpty && x.length <= max;
    bool id(dynamic x) =>
        x is String &&
        RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(x);
    List<Map<String, dynamic>> rows(dynamic x, int max) {
      if (x is! List || x.length > max) invalid();
      return x.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    }

    if (data['storageReady'] != true) invalid();
    final c =
        data['connection'] == null
            ? null
            : Map<String, dynamic>.from(data['connection'] as Map);
    if (c != null &&
        (!id(c['id']) || !integer(c['version'], 1) || c['active'] is! bool)) {
      invalid();
    }
    final accounts = rows(data['accounts'], 50),
        sources = rows(data['sources'], 100);
    if (!integer(data['totalSources'], 0, 100000) ||
        !integer(data['needsReviewCount'], 0, 100000) ||
        data['hasMore'] is! bool) {
      invalid();
    }
    final accountIds = <String>{}, sourceIds = <String>{};
    for (final a in accounts) {
      if (!id(a['id']) ||
          !accountIds.add(a['id'] as String) ||
          !text(a['name'], 100) ||
          !text(a['type'], 30) ||
          !text(a['currency'], 3) ||
          a['supported'] is! bool ||
          a['available'] is! bool ||
          a['balanceIssue'] is! bool ||
          (a['ledgerAccountId'] != null && !id(a['ledgerAccountId']))) {
        invalid();
      }
      for (final key in ['reportedBalanceMinor', 'availableBalanceMinor']) {
        if (a[key] != null &&
            !integer(a[key], -99999999999999, 99999999999999)) {
          invalid();
        }
      }
      if (a['mask'] != null && !text(a['mask'], 16)) invalid();
    }
    for (final s in sources) {
      if (!id(s['id']) ||
          !sourceIds.add(s['id'] as String) ||
          !accountIds.contains(s['bankAccountId']) ||
          !integer(s['version'], 1) ||
          !{'posted', 'pending', 'removed'}.contains(s['status']) ||
          s['superseded'] is! bool ||
          s['needsReview'] is! bool ||
          (s['linkedJournalEntryId'] != null &&
              !id(s['linkedJournalEntryId'])) ||
          (s['description'] != null && !text(s['description'], 500))) {
        invalid();
      }
      if (s['amountMinor'] != null &&
          !integer(s['amountMinor'], -99999999999999, 99999999999999)) {
        invalid();
      }
      final date = s['date'];
      if (date != null) {
        final parsed = date is String ? DateTime.tryParse(date) : null;
        if (parsed == null ||
            parsed.toIso8601String().substring(0, 10) != date) {
          invalid();
        }
      }
      if (s['status'] != 'removed' &&
          (date == null ||
              s['amountMinor'] == null ||
              s['description'] == null)) {
        invalid();
      }
    }
    return ServerBankState(
      c,
      accounts,
      sources,
      data['totalSources'] as int,
      data['needsReviewCount'] as int,
      data['hasMore'] as bool,
      batchSupported: data['batchReviewSupported'] == true,
    );
  }
}
