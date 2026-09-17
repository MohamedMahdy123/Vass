import 'package:flutter/foundation.dart';

import '../core/supabase_service.dart';
import '../data/models/item.dart';
import '../data/wardrobe_repository.dart';

/// The wardrobe, backed by Postgres when Supabase is configured and the user is
/// signed in — otherwise an in-memory demo list so the app is always usable.
///
/// This is the real state that replaces the prototype's mock `AppState` for the
/// Closet tab. Home / Builder / Stylist stay on the prototype until M3.
class WardrobeState extends ChangeNotifier {
  final _repo = WardrobeRepository();

  List<Item> _items = [];
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  String _category = 'All';

  bool get loading => _loading;
  String? get error => _error;
  String get category => _category;
  List<Item> get items => List.unmodifiable(_items);

  /// True when we're talking to the real database (vs. the demo list).
  bool get isLive =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  List<Item> get visibleItems =>
      _category == 'All' ? items : _items.where((i) => i.category == _category).toList();

  int get count => _items.length;

  Item byId(String id) => _items.firstWhere((i) => i.id == id);

  void setCategory(String c) {
    _category = c;
    notifyListeners();
  }

  /// Load the wardrobe. Safe to call repeatedly (e.g. when the Closet tab opens);
  /// the demo list is only seeded once so demo edits aren't wiped.
  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_loadedOnce && !force && !isLive) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      if (isLive) {
        _items = await _repo.fetchItems();
      } else if (!_loadedOnce) {
        // Copy into a growable list — the seed is a const (unmodifiable) list.
        _items = List.of(_demoSeed());
      }
      _loadedOnce = true;
    } catch (e) {
      _error = 'Could not load your wardrobe.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> add(Item draft) async {
    if (isLive) {
      final created = await _repo.add(draft);
      _items.insert(0, created);
    } else {
      _items.insert(0, _withLocalId(draft));
    }
    notifyListeners();
  }

  /// Persist a captured-and-reviewed piece: create the row, upload its photo,
  /// then link the two. Demo mode keeps the photo bytes in memory for preview.
  Future<void> commitCaptured(Item draft, Uint8List bytes) async {
    if (isLive) {
      final created = await _repo.add(draft);
      final path = await _repo.uploadPhoto(created.id, bytes);
      final patch = <String, dynamic>{'image_path': path};

      // If background removal produced a cut-out, upload it too and link it.
      String? processedPath;
      final cutout = draft.processedBytes;
      if (cutout != null) {
        try {
          processedPath = await _repo.uploadProcessed(created.id, cutout);
          patch['processed_image_url'] = processedPath;
        } catch (_) {
          // Best-effort — the original photo is enough to save the item.
        }
      }

      await _repo.update(created.id, patch);
      _items.insert(
        0,
        created.copyWith(
          imagePath: path,
          processedImageUrl: processedPath,
          localBytes: bytes,
          processedBytes: cutout,
        ),
      );
    } else {
      _items.insert(0, _withLocalId(draft.copyWith(localBytes: bytes)));
    }
    notifyListeners();
  }

  /// Apply edited fields to an existing item.
  Future<void> updateItem(Item edited) async {
    final i = _items.indexWhere((e) => e.id == edited.id);
    if (i == -1) return;
    _items[i] = edited; // optimistic
    notifyListeners();
    if (isLive) {
      try {
        await _repo.update(edited.id, edited.toInsert());
      } catch (_) {
        _error = 'Could not save changes.';
        notifyListeners();
      }
    }
  }

  Future<void> toggleFavorite(String id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final next = _items[i].copyWith(favorite: !_items[i].favorite);
    _items[i] = next;
    notifyListeners();
    if (isLive) {
      try {
        await _repo.update(id, {'favorite': next.favorite});
      } catch (_) {
        _error = 'Could not update favourite.';
        notifyListeners();
      }
    }
  }

  Future<void> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    if (isLive) {
      try {
        await _repo.remove(id);
      } catch (_) {
        _error = 'Could not delete the item.';
        notifyListeners();
      }
    }
  }

  int _localSeq = 0;
  // Assign a client-side id (demo mode / offline) while preserving every rich
  // field — copyWith carries occasions/seasons/weather and the rest through.
  Item _withLocalId(Item draft) => draft.copyWith(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}-${_localSeq++}',
      );

  /// A small starter closet for demo mode. Each piece carries a real, verified
  /// product-photo URL so the closet reads as a clean catalog — no item falls
  /// back to a silhouette. Photos come from license-clean free sources:
  /// FakeStore (fakestoreapi.com), DummyJSON (cdn.dummyjson.com) and Pexels
  /// (free commercial use). ItemImage still falls back to a colour silhouette
  /// only if a URL fails to load, so the grid never breaks.
  List<Item> _demoSeed() => const [
        Item(id: 'demo-1', name: 'Ribbed Wool Sweater', processedImageUrl: 'https://fakestoreapi.com/img/71-3HjGNDUL._AC_SY879._SX._UX._SY._UY_t.png', category: 'Tops', color: 'Ash', material: 'Wool', pattern: 'Solid', season: 'Winter', occasion: 'Casual', brand: 'Halden', favorite: true, status: ItemStatus.reviewed),
        Item(id: 'demo-2', name: 'Oxford Shirt', processedImageUrl: 'https://fakestoreapi.com/img/71YXzeOuslL._AC_UY879_t.png', category: 'Tops', color: 'White', material: 'Cotton', pattern: 'Solid', season: 'All', occasion: 'Work', brand: 'Nord', status: ItemStatus.reviewed),
        Item(id: 'demo-3', name: 'Cotton Tee', processedImageUrl: 'https://fakestoreapi.com/img/71z3kpMAYsL._AC_UY879_t.png', category: 'Tops', color: 'Sand', material: 'Cotton', pattern: 'Solid', season: 'Summer', occasion: 'Casual', brand: 'Lune', status: ItemStatus.reviewed),
        Item(id: 'demo-4', name: 'Chunky Knit', processedImageUrl: 'https://fakestoreapi.com/img/61pHAEJ4NML._AC_UX679_t.png', category: 'Tops', color: 'Cream', material: 'Wool', pattern: 'Solid', season: 'Winter', occasion: 'Casual', brand: 'Halden', favorite: true, status: ItemStatus.reviewed),
        Item(id: 'demo-5', name: 'Straight Jeans', processedImageUrl: 'https://images.pexels.com/photos/10133274/pexels-photo-10133274.jpeg?auto=compress&cs=tinysrgb&w=800', category: 'Bottoms', color: 'Indigo', material: 'Denim', pattern: 'Solid', season: 'All', occasion: 'Casual', brand: 'Beau', favorite: true, status: ItemStatus.reviewed),
        Item(id: 'demo-6', name: 'Washed Denim', processedImageUrl: 'https://images.pexels.com/photos/17630811/pexels-photo-17630811.jpeg?auto=compress&cs=tinysrgb&w=800', category: 'Bottoms', color: 'Blue', material: 'Denim', pattern: 'Solid', season: 'All', occasion: 'Casual', brand: 'Beau', status: ItemStatus.reviewed),
        Item(id: 'demo-7', name: 'Camel Trench', processedImageUrl: 'https://fakestoreapi.com/img/71li-ujtlUL._AC_UX679_t.png', category: 'Outerwear', color: 'Camel', material: 'Cotton', pattern: 'Solid', season: 'Spring', occasion: 'Smart', brand: 'Lune', status: ItemStatus.reviewed),
        Item(id: 'demo-8', name: 'Wool Overcoat', processedImageUrl: 'https://fakestoreapi.com/img/81XH0e8fefL._AC_UY879_t.png', category: 'Outerwear', color: 'Charcoal', material: 'Wool', pattern: 'Solid', season: 'Winter', occasion: 'Work', brand: 'Kestrel', favorite: true, status: ItemStatus.reviewed),
        Item(id: 'demo-9', name: 'Leather Loafers', processedImageUrl: 'https://cdn.dummyjson.com/product-images/mens-shoes/puma-future-rider-trainers/thumbnail.webp', category: 'Footwear', color: 'Cognac', material: 'Leather', pattern: 'Solid', season: 'All', occasion: 'Work', brand: 'Atelier', status: ItemStatus.reviewed),
        Item(id: 'demo-10', name: 'Derby Shoes', processedImageUrl: 'https://cdn.dummyjson.com/product-images/mens-shoes/nike-air-jordan-1-red-and-black/thumbnail.webp', category: 'Footwear', color: 'Brown', material: 'Leather', pattern: 'Solid', season: 'All', occasion: 'Work', brand: 'Atelier', favorite: true, status: ItemStatus.reviewed),
        Item(id: 'demo-11', name: 'Cashmere Scarf', processedImageUrl: 'https://images.unsplash.com/photo-1609803384069-19f3e5a70e75?w=800&q=80&auto=format&fit=crop', category: 'Accessories', color: 'Sage', material: 'Cashmere', pattern: 'Solid', season: 'Winter', occasion: 'Casual', brand: 'Lune', favorite: true, status: ItemStatus.reviewed),
        Item(id: 'demo-12', name: 'Linen Dress', processedImageUrl: 'https://cdn.dummyjson.com/product-images/womens-dresses/dress-pea/thumbnail.webp', category: 'Dresses', color: 'Bone', material: 'Linen', pattern: 'Solid', season: 'Summer', occasion: 'Smart', brand: 'Lune', favorite: true, status: ItemStatus.reviewed),
      ];
}
