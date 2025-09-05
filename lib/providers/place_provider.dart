import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place.dart';
import '../repositories/place_repository.dart';

class PlaceProvider extends ChangeNotifier {
  final PlaceRepository repo;
  PlaceProvider(this.repo);

  final List<Place> _items = [];
  List<Place> get items => List.unmodifiable(_items);

  bool isLoading = false;
  bool hasMore = true;
  String? query;
  Timer? _debounce;

  // ---- ranking helpers ----
  int _score(Place p, String q) {
    final needle = q.toLowerCase();
    final title = p.title.toLowerCase();
    final desc  = p.description.toLowerCase();

    if (title.startsWith(needle)) return 3;      // best
    if (title.contains(needle))  return 2;
    if (desc.contains(needle))   return 1;
    return 0;                                    // worst
  }

  void _rankAndSort() {
    final q = query?.trim();
    if (q == null || q.isEmpty) return;

    _items.sort((a, b) {
      final sb = _score(b, q);
      final sa = _score(a, q);
      if (sb != sa) return sb - sa; // higher first

      // tie-breakers: newest first, then id
      final c = b.createdAt.compareTo(a.createdAt);
      if (c != 0) return c;
      return b.id.compareTo(a.id);
    });
  }
  // -------------------------

  Future<void> refresh({String? search}) async {
    query = search;
    hasMore = true;
    _items.clear();
    notifyListeners();
    await loadMore(reset: true);
  }

  Future<void> loadMore({bool reset = false}) async {
    if (isLoading || !hasMore) return;
    isLoading = true;
    notifyListeners();

    DateTime? before;
    if (_items.isNotEmpty) {
      before = _items.last.createdAt;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;

    final newItems = await repo.fetchPlaces(
      search: query,
      before: before,
      limit: 20,
      currentUserId: userId,
    );

    _items.addAll(newItems);

    // Make sure ordering is stable when there's no search
    if (before == null && (query == null || query!.trim().isEmpty)) {
      _items.sort((a, b) {
        final c = b.createdAt.compareTo(a.createdAt);
        if (c != 0) return c;
        return b.id.compareTo(a.id);
      });
    }

    // When searching, re-rank after each page so best matches stay on top
    if (query != null && query!.trim().isNotEmpty) {
      _rankAndSort();
    }

    if (newItems.length < 20) hasMore = false;

    isLoading = false;
    notifyListeners();
  }

  void debounceSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      refresh(search: text);
    });
  }

  Future<void> addPlace(Place p) async {
    _items.insert(0, p);
    // If a search is active, keep ranking consistent
    if (query != null && query!.trim().isNotEmpty) _rankAndSort();
    notifyListeners();
  }

  Future<void> replacePlace(Place p) async {
    final idx = _items.indexWhere((e) => e.id == p.id);
    if (idx != -1) {
      _items[idx] = _items[idx].copyWith(
        title: p.title,
        description: p.description,
        imageUrl: p.imageUrl,
        mapUrl: p.mapUrl,
      );
      if (query != null && query!.trim().isNotEmpty) _rankAndSort();
      notifyListeners();
    }
  }

  Future<void> removePlace(String id) async {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<void> setFavorite(String id, bool fav) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _items[idx] = _items[idx].copyWith(isFavorite: fav);
      notifyListeners();
    }
  }
}