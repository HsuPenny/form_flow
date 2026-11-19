import 'package:flutter/foundation.dart';

/// One batch of a longer list, plus how many items there are in all.
class PageResult<T> {
  const PageResult(this.items, this.total);

  /// Batch size lists ask for unless they have a reason not to.
  static const size = 20;

  final List<T> items;
  final int total;
}

/// 分批載入的列表：先載第一批，列表滑到底時再呼叫 [loadMore] 接著載
/// 下一批。資料從哪來由建構時給的函式決定，所以任何列表都能共用；
/// 畫面端搭配 `ListPageBody.onNearEnd` 與 `PagedFeedFooter`。
class PagedFeed<T> extends ChangeNotifier {
  PagedFeed(this._load);

  /// Fetches the batch that starts at the given offset.
  final Future<PageResult<T>> Function(int offset) _load;

  final List<T> _items = [];
  int? _total;
  bool _loading = false;
  bool _refreshing = false;
  Object? _error;

  /// Bumped by [reload] and [refresh], so a batch requested before it is
  /// dropped.
  int _generation = 0;

  /// The page can go away while a batch is loading.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<T> get items => List.unmodifiable(_items);

  /// How many items there are in all; null until the first batch arrives.
  int? get total => _total;
  bool get isLoading => _loading;

  /// True while [refresh] fetches the first batch again.
  bool get isRefreshing => _refreshing;

  /// Why the last batch failed; cleared by the next attempt.
  Object? get error => _error;
  bool get hasMore => _total == null || _items.length < _total!;

  /// Starts over from the first batch, e.g. after a new search: the list
  /// empties and shows its loading footer. Failures end up in [error]
  /// instead of being thrown.
  Future<void> reload() {
    _generation++;
    _items.clear();
    _total = null;
    _loading = false;
    _refreshing = false;
    _error = null;
    return loadMore();
  }

  /// Fetches the first batch again for pull-to-refresh. The current items
  /// stay on screen until it arrives and are then replaced, and lists hide
  /// their own spinner meanwhile ([isRefreshing]): the pull indicator
  /// already shows progress.
  Future<void> refresh() {
    _generation++;
    _refreshing = true;
    _loading = false;
    _error = null;
    return _fetch(replace: true);
  }

  /// Loads the next batch, unless one is on its way, the last one failed
  /// (pass [retry] to try again), or everything is loaded.
  Future<void> loadMore({bool retry = false}) async {
    if (_loading || !hasMore || (_error != null && !retry)) return;
    return _fetch(replace: false);
  }

  /// Fetches the batch after the current items, or the first batch in their
  /// place when [replace] is set.
  Future<void> _fetch({required bool replace}) async {
    final generation = _generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _load(replace ? 0 : _items.length);
      if (generation != _generation) return;
      if (replace) _items.clear();
      _items.addAll(page.items);
      _total = page.total;
      // An empty batch means the list ended early, e.g. items changed while
      // paging; stop rather than ask again for nothing.
      if (page.items.isEmpty) _total = _items.length;
    } catch (e) {
      if (generation != _generation) return;
      debugPrint('Could not load the next batch: $e');
      _error = e;
    } finally {
      if (generation == _generation && !_disposed) {
        _loading = false;
        _refreshing = false;
        notifyListeners();
      }
    }
  }
}
