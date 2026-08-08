/// The order-list filters that can be decided in SQL.
///
/// These used to be applied in Dart, inside OrderHistoryProvider's `orders`
/// getter, *after* the rows had already been fetched. That split is what made
/// the date filters impossible to paginate: a page of 200 raw rows might leave
/// 15 visible, and a 15-item list does not scroll, so nothing ever asks for the
/// next page. Deciding them in SQL means a page of 200 is ~200 matching rows.
///
/// The date filter is deliberately NOT here. `created_at` is a mixed-format text
/// column - local-naive ISO from `DateTime.now().toIso8601String()`, possibly
/// UTC from synced devices, and a legacy `local_<epochMillis>` form - so an
/// exact date comparison in SQL is not currently possible. That one stays in
/// Dart (`OrderTimeFilter.isInPeriod`) behind the ±24h buffer, which bounds the
/// leftover shrinkage to the edges of the range.
///
/// Kept free of any database or plugin import so the SQL it generates can be
/// verified headless against sqflite_common_ffi.
library;

class OrderQueryFilters {
  /// Order status. Null or 'all' means no restriction.
  final String? status;

  /// Only catering service types.
  final bool cateringOnly;

  /// Everything except catering. Ignored when [cateringOnly] is set, matching
  /// the getter's if/else-if.
  final bool excludeCatering;

  /// Only orders carrying a deposit.
  ///
  /// Currently unreachable for the paged queries, because `_resolveFetchMode`
  /// routes advanced-only to `getAdvancedOrders()` before any of this applies.
  /// Translated anyway so the two cannot disagree if that ever changes.
  final bool advancedOnly;

  /// Exact service type match. Null or empty means no restriction.
  final String? serviceType;

  const OrderQueryFilters({
    this.status,
    this.cateringOnly = false,
    this.excludeCatering = false,
    this.advancedOnly = false,
    this.serviceType,
  });

  static const OrderQueryFilters none = OrderQueryFilters();

  bool get isEmpty =>
      (status == null || status == 'all') &&
      !cateringOnly &&
      !excludeCatering &&
      !advancedOnly &&
      (serviceType == null || serviceType!.isEmpty);

  /// Compact rendering for the log, e.g. `status:pending,excludeCatering`.
  /// 'none' when nothing is set, so a trace line always says something.
  String describe() {
    final parts = <String>[];
    if (status != null && status != 'all') parts.add('status:$status');
    if (cateringOnly) parts.add('cateringOnly');
    if (excludeCatering) parts.add('excludeCatering');
    if (advancedOnly) parts.add('advancedOnly');
    if (serviceType != null && serviceType!.isNotEmpty) {
      parts.add('serviceType:$serviceType');
    }
    return parts.isEmpty ? 'none' : parts.join(',');
  }

  /// The WHERE fragments and their bound arguments.
  ///
  /// Returns conditions separately from a joined string so a caller can AND
  /// them with its own clause (a date range, say) without string surgery.
  (List<String>, List<Object?>) toConditions() {
    final conditions = <String>[];
    final args = <Object?>[];

    if (status != null && status != 'all') {
      // LOWER() on both sides mirrors the Dart
      // `o.status.toLowerCase() == _statusFilter!.toLowerCase()`.
      conditions.add('LOWER(status) = ?');
      args.add(status!.toLowerCase());
    }

    // COALESCE is not decoration. In SQL `NULL NOT LIKE '%catering%'` evaluates
    // to NULL, not true, so a row with no service_type would be silently
    // dropped from every exclude-catering listing - the exact kind of quiet row
    // loss this translation must not introduce.
    if (cateringOnly) {
      conditions.add("LOWER(COALESCE(service_type, '')) LIKE '%catering%'");
    } else if (excludeCatering) {
      conditions.add("LOWER(COALESCE(service_type, '')) NOT LIKE '%catering%'");
    }

    if (advancedOnly) {
      conditions.add('deposit_amount IS NOT NULL AND deposit_amount > 0');
    }

    if (serviceType != null && serviceType!.isNotEmpty) {
      conditions.add('LOWER(service_type) = ?');
      args.add(serviceType!.toLowerCase());
    }

    return (conditions, args);
  }

  /// Applies the same rules in Dart.
  ///
  /// This is the reference the SQL is held to. It exists so the equivalence
  /// test can assert both paths agree on a real dataset, and so any caller that
  /// cannot reach SQL still filters identically.
  bool matches({
    required String status,
    required String serviceType,
    required double? depositAmount,
  }) {
    if (this.status != null && this.status != 'all') {
      if (status.toLowerCase() != this.status!.toLowerCase()) return false;
    }

    final lowerService = serviceType.toLowerCase();
    if (cateringOnly) {
      if (!lowerService.contains('catering')) return false;
    } else if (excludeCatering) {
      if (lowerService.contains('catering')) return false;
    }

    if (advancedOnly && !(depositAmount != null && depositAmount > 0)) {
      return false;
    }

    if (this.serviceType != null && this.serviceType!.isNotEmpty) {
      if (lowerService != this.serviceType!.toLowerCase()) return false;
    }

    return true;
  }
}
