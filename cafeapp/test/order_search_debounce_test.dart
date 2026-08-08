// Tests for the order-list search debounce.
//
// searchOrders is a LIKE scan with a leading wildcard, so no index helps it and
// its cost grows with history - 38ms per call against 50,000 orders in
// perf_benchmark_test. It used to run on every keystroke, so typing a bill
// number got steadily laggier as a cafe's order history grew.
//
// A fake repository stands in for the database, so nothing here touches disk.
//
//   flutter test test/order_search_debounce_test.dart --no-pub

import 'package:flutter_test/flutter_test.dart';
import 'package:cafeapp/models/order.dart';
import 'package:cafeapp/models/order_history.dart' show OrderTimeFilter;
import 'package:cafeapp/providers/order_history_provider.dart';
import 'package:cafeapp/repositories/local_order_repository.dart';
import 'package:cafeapp/repositories/order_query_filters.dart';
import 'package:cafeapp/utils/logger.dart';

class _FakeOrderRepository extends LocalOrderRepository {
  final List<String> searchCalls = [];

  /// Per-query delay, so a test can make an earlier search finish last.
  Map<String, Duration> delays = {};

  /// Ids returned for a given query, so results are distinguishable.
  Map<String, List<int>> results = {};

  int pageCalls = 0;

  /// Filters each listing query was given, so tests can assert that a filter
  /// change actually reached SQL rather than only redrawing.
  final List<OrderQueryFilters> filterCalls = [];

  /// (limit, offset) per listing query, for the pagination tests.
  final List<(int?, int)> pageWindows = [];

  /// Rows the next listing query returns. Lets a test simulate a full page.
  List<int> pageResults = const [];

  @override
  Future<List<Order>> searchOrders(String query, {int limit = 200}) async {
    searchCalls.add(query);
    final delay = delays[query];
    if (delay != null) await Future<void>.delayed(delay);
    return (results[query] ?? const <int>[]).map(_order).toList();
  }

  @override
  Future<List<Order>> getOrdersPage({
    int limit = 200,
    int offset = 0,
    OrderQueryFilters filters = OrderQueryFilters.none,
  }) async {
    pageCalls++;
    filterCalls.add(filters);
    pageWindows.add((limit, offset));
    return pageResults.map(_order).toList();
  }

  @override
  Future<List<Order>> getOrdersByDateRange(
    DateTime start,
    DateTime end, {
    int? limit,
    int offset = 0,
    OrderQueryFilters filters = OrderQueryFilters.none,
  }) async {
    pageCalls++;
    filterCalls.add(filters);
    pageWindows.add((limit, offset));
    return pageResults.map(_order).toList();
  }

  @override
  Future<List<Order>> getAdvancedOrders() async {
    pageCalls++;
    return [];
  }

  // Matches the provider's default filters (pending, today) so the `orders`
  // getter does not filter these out before the assertions see them.
  static Order _order(int id) => Order(
        id: id,
        staffDeviceId: 'test',
        serviceType: 'Dining - Table 1',
        items: const [],
        subtotal: 10,
        tax: 0.5,
        discount: 0,
        total: 10.5,
        status: 'pending',
        createdAt: DateTime.now().toIso8601String(),
      );
}

void main() {
  late _FakeOrderRepository repo;
  late OrderHistoryProvider provider;
  late List<String> listingLines;
  final originalDebounce = OrderHistoryProvider.searchDebounce;
  final originalReloadDebounce = OrderHistoryProvider.filterReloadDebounce;

  setUp(() {
    repo = _FakeOrderRepository();
    provider = OrderHistoryProvider(repository: repo);
    OrderHistoryProvider.searchDebounce = const Duration(milliseconds: 40);
    OrderHistoryProvider.filterReloadDebounce =
        const Duration(milliseconds: 20);
    // Order-list tracing defaults to the real Documents crash log on Windows.
    listingLines = [];
    OrderHistoryProvider.listingLogWriter =
        (line) async => listingLines.add(line);
  });

  tearDown(() {
    OrderHistoryProvider.searchDebounce = originalDebounce;
    OrderHistoryProvider.filterReloadDebounce = originalReloadDebounce;
    OrderHistoryProvider.listingLogWriter = logErrorToFile;
    provider.dispose();
  });

  test('typing a bill number costs one query, not one per character', () async {
    // The regression this exists to prevent: five keystrokes used to mean five
    // full-table LIKE scans.
    for (final partial in ['0', '00', '004', '0042']) {
      provider.searchOrdersByBillNumber(partial);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(repo.searchCalls, ['0042']);
  });

  test('a pause between words runs both searches', () async {
    provider.searchOrdersByBillNumber('004');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    provider.searchOrdersByBillNumber('0042');
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(repo.searchCalls, ['004', '0042']);
  });

  test('clearing the box is immediate, not debounced', () async {
    // Waiting 300ms to get the full list back feels broken.
    provider.searchOrdersByBillNumber('');
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(repo.pageCalls, greaterThan(0));
  });

  test('a slow earlier search cannot overwrite a newer one', () async {
    // The classic race: "004" takes 200ms, "0042" takes 10ms, so the stale
    // result lands last and the list shows the wrong orders while the box
    // reads 0042.
    repo.delays = {
      '004': const Duration(milliseconds: 200),
      '0042': const Duration(milliseconds: 10),
    };
    repo.results = {
      '004': [1, 2, 3],
      '0042': [42],
    };

    provider.searchOrdersByBillNumber('004');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    provider.searchOrdersByBillNumber('0042');

    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(repo.searchCalls, ['004', '0042']);
    expect(provider.orders.map((o) => o.id).toList(), [42],
        reason: 'the newest query owns the list');
  });

  group('filters reach SQL', () {
    setUp(() {
      OrderHistoryProvider.filterReloadDebounce =
          const Duration(milliseconds: 20);
    });

    test('changing a filter refetches instead of only redrawing', () async {
      // The hazard of moving filters into SQL: these setters used to call only
      // notifyListeners(), because the getter re-filtered in memory. A setter
      // that does not refetch is a filter that silently stops working.
      repo.pageCalls = 0;
      repo.filterCalls.clear();

      provider.setStatusFilter('completed');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(repo.pageCalls, 1);
      expect(repo.filterCalls.single.status, 'completed');
    });

    test('excludeCatering and cateringOnly both refetch', () async {
      repo.pageCalls = 0;

      provider.setExcludeCatering(true);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(repo.filterCalls.last.excludeCatering, isTrue);

      provider.setCateringOnly(true);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(repo.filterCalls.last.cateringOnly, isTrue);
      // Setting one clears the other, as the provider's setters intend.
      expect(repo.filterCalls.last.excludeCatering, isFalse);

      expect(repo.pageCalls, 2);
    });

    test('a burst of filter changes coalesces into one query', () async {
      // Screen init sets several filters in a row; without coalescing that is
      // three or four queries on every open.
      repo.pageCalls = 0;

      provider.setStatusFilter('pending');
      provider.setExcludeCatering(true);
      provider.setStatusFilter('completed');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(repo.pageCalls, 1);
      // The last value wins.
      expect(repo.filterCalls.single.status, 'completed');
      expect(repo.filterCalls.single.excludeCatering, isTrue);
    });

    test('an explicit loadOrders absorbs a scheduled reload', () async {
      repo.pageCalls = 0;

      provider.setStatusFilter('pending');
      await provider.loadOrders();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(repo.pageCalls, 1, reason: 'must not query twice');
    });
  });

  group('date-range pagination', () {
    test('a full first page leaves hasMore set, and loadMore pages on',
        () async {
      // Before this change the dateRange branch set _hasMore = false and loaded
      // the entire period - the Yearly filter pulled ~22k rows in one query.
      repo.pageResults = List.generate(200, (i) => i + 1);

      provider.setTimeFilter(OrderTimeFilter.yearly);
      await provider.loadOrders();

      expect(provider.hasMore, isTrue);
      expect(repo.pageWindows.last, (200, 0), reason: 'first page is bounded');

      await provider.loadMoreOrders();
      expect(repo.pageWindows.last, (200, 200), reason: 'second page follows');
    });

    test('a short page ends pagination', () async {
      repo.pageResults = List.generate(30, (i) => i + 1);

      provider.setTimeFilter(OrderTimeFilter.monthly);
      await provider.loadOrders();

      expect(provider.hasMore, isFalse);

      final before = repo.pageCalls;
      await provider.loadMoreOrders();
      expect(repo.pageCalls, before, reason: 'nothing left to fetch');
    });

    test('search suspends pagination', () async {
      repo.pageResults = List.generate(200, (i) => i + 1);
      provider.setTimeFilter(OrderTimeFilter.yearly);
      await provider.loadOrders();

      provider.searchOrdersByBillNumber('0042');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final before = repo.pageCalls;
      await provider.loadMoreOrders();
      expect(repo.pageCalls, before,
          reason: 'search results are not paginated');
    });
  });

  group('order-list tracing', () {
    test('a listing logs one greppable line naming filters and page', () async {
      repo.pageResults = List.generate(200, (i) => i + 1);

      provider.setTimeFilter(OrderTimeFilter.yearly);
      provider.setStatusFilter('pending');
      await provider.loadOrders();

      final line = listingLines.single;
      // Pins the grep the customer-log verification depends on.
      expect(line, startsWith('⏱️ orders[dateRange:yearly]'));
      expect(line, contains('rows=200'));
      expect(line, contains('page=0'));
      expect(line, contains('hasMore=true'));
      expect(line, contains('filters=status:pending'));
    });

    test('a repeated identical query is not logged again', () async {
      // loadOrders also runs on a 30-second auto-refresh. Logging every call
      // would add thousands of lines a day and evict payment history from the
      // capped log.
      await provider.loadOrders();
      expect(listingLines.length, 1);

      await provider.loadOrders();
      await provider.loadOrders();
      expect(listingLines.length, 1, reason: 'same query, nothing new to say');
    });

    test('changing the filter logs again', () async {
      await provider.loadOrders();
      provider.setStatusFilter('completed');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(listingLines.length, 2);
      expect(listingLines.last, contains('filters=status:completed'));
    });

    test('every load-more is logged, with its page number', () async {
      repo.pageResults = List.generate(200, (i) => i + 1);
      await provider.loadOrders();
      listingLines.clear();

      await provider.loadMoreOrders();

      // The only positive proof in a customer log that paging works.
      expect(listingLines.single, contains('page=1'));
    });
  });

  test('a pending search does not fire after dispose', () async {
    // notifyListeners() on a disposed ChangeNotifier throws, so a timer that
    // outlives the screen would crash the app on navigate-away.
    provider.searchOrdersByBillNumber('0042');
    provider.dispose();

    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(repo.searchCalls, isEmpty);

    // tearDown disposes again; make that a no-op rather than a double-dispose.
    provider = OrderHistoryProvider(repository: repo);
  });
}
