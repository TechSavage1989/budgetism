enum ReviewView {
  all,
  needsReview,
  pending,
  linked,
  unlinked,
  ignored,
  removed,
  superseded,
}

enum ReviewOrder { newest, oldest, largest }

class ReviewFilter {
  const ReviewFilter({
    this.query = '',
    this.account = '',
    this.view = ReviewView.all,
    this.direction = 'all',
    this.order = ReviewOrder.newest,
    this.from,
    this.to,
  });
  final String query, account, direction;
  final ReviewView view;
  final ReviewOrder order;
  final String? from, to;
  ReviewFilter copyWith({
    String? query,
    String? account,
    ReviewView? view,
    String? direction,
    ReviewOrder? order,
    String? from,
    String? to,
    bool clearDates = false,
  }) => ReviewFilter(
    query: query ?? this.query,
    account: account ?? this.account,
    view: view ?? this.view,
    direction: direction ?? this.direction,
    order: order ?? this.order,
    from: clearDates ? null : from ?? this.from,
    to: clearDates ? null : to ?? this.to,
  );
  static bool reopenEligible(Map<String, dynamic> source) =>
      {'ignored', 'kept'}.contains(source['decision']) &&
      source['reviewedVersion'] == source['version'];
  static bool batchEligible(Map<String, dynamic> source) =>
      reopenEligible(source) ||
      source['needsReview'] == true &&
          (source['linkedJournalEntryId'] != null ||
              source['status'] == 'posted' && source['superseded'] != true);
  List<Map<String, dynamic>> apply(
    List<Map<String, dynamic>> sources,
    Map<dynamic, dynamic> names,
  ) {
    final words =
        query
            .trim()
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .toList();
    final result =
        sources.where((s) {
          final linked = s['linkedJournalEntryId'] != null;
          final amount = s['amountMinor'] as int?;
          if (account.isNotEmpty && s['bankAccountId'] != account) return false;
          if (direction == 'in' && (amount == null || amount <= 0) ||
              direction == 'out' && (amount == null || amount >= 0)) {
            return false;
          }
          if (!switch (view) {
            ReviewView.all => true,
            ReviewView.needsReview => s['needsReview'] == true,
            ReviewView.pending => s['status'] == 'pending',
            ReviewView.linked => linked,
            ReviewView.unlinked => !linked,
            ReviewView.ignored => s['decision'] == 'ignored',
            ReviewView.removed => s['status'] == 'removed',
            ReviewView.superseded => s['superseded'] == true,
          }) {
            return false;
          }
          final date = s['date'] as String?;
          if ((from != null || to != null) &&
              (date == null ||
                  from != null && date.compareTo(from!) < 0 ||
                  to != null && date.compareTo(to!) > 0)) {
            return false;
          }
          final haystack =
              '${s['description'] ?? ''} ${names[s['bankAccountId']] ?? ''} ${s['date'] ?? ''} ${s['status']} ${s['decision'] ?? ''}'
                  .toLowerCase();
          return words.every(haystack.contains);
        }).toList();
    result.sort((a, b) {
      int compared;
      if (order == ReviewOrder.largest) {
        compared = ((b['amountMinor'] as int? ?? 0).abs()).compareTo(
          (a['amountMinor'] as int? ?? 0).abs(),
        );
      } else {
        final ad = a['date'] as String?, bd = b['date'] as String?;
        compared =
            ad == null
                ? (bd == null ? 0 : 1)
                : bd == null
                ? -1
                : order == ReviewOrder.newest
                ? bd.compareTo(ad)
                : ad.compareTo(bd);
      }
      return compared != 0
          ? compared
          : (a['id'] as String).compareTo(b['id'] as String);
    });
    return result;
  }
}
