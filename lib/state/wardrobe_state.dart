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
      await _repo.update(created.id, {'image_path': path});
      _items.insert(0, created.copyWith(imagePath: path, localBytes: bytes));
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
  Item _withLocalId(Item draft) => Item(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}-${_localSeq++}',
        name: draft.name,
        imagePath: draft.imagePath,
        category: draft.category,
        color: draft.color,
        material: draft.material,
        pattern: draft.pattern,
        season: draft.season,
        occasion: draft.occasion,
        brand: draft.brand,
        favorite: draft.favorite,
        status: draft.status,
        localBytes: draft.localBytes,
      );

  /// A small, real-looking starter closet for demo mode.
  List<Item> _demoSeed() => const [
        Item(id: 'demo-1', name: 'Ribbed Wool Sweater', category: 'Tops', color: 'Ash', material: 'Wool', pattern: 'Solid', season: 'Winter', occasion: 'Casual', brand: 'Halden', favorite: true, status: ItemStatus.reviewed),
        Item(id: 'demo-2', name: 'Oxford Shirt', category: 'Tops', color: 'Ivory', material: 'Cotton', pattern: 'Solid', season: 'All', occasion: 'Work', brand: 'Nord', status: ItemStatus.reviewed),
        Item(id: 'demo-3', name: 'Silk Blouse', category: 'Tops', color: 'Sand', material: 'Silk', pattern: 'Solid', season: 'Spring', occasion: 'Work', brand: 'Lune', favorite: true, status: ItemStatus.reviewed),
        Item(id: 'demo-4', name: 'Tailored Trousers', category: 'Bottoms', color: 'Charcoal', material: 'Wool', pattern: 'Solid', season: 'All', occasion: 'Work', brand: 'Atelier', status: ItemStatus.reviewed),
        Item(id: 'demo-5', name: 'Straight Jeans', category: 'Bottoms', color: 'Indigo', material: 'Denim', pattern: 'Solid', season: 'All', occasion: 'Casual', brand: 'Beau', favorite: true, status: ItemStatus.reviewed),
        Item(id: 'demo-6', name: 'Wool Overcoat', category: 'Outerwear', color: 'Taupe', material: 'Wool', pattern: 'Solid', season: 'Winter', occasion: 'Work', brand: 'Kestrel', favorite: true, status: ItemStatus.reviewed),
        Item(id: 'demo-7', name: 'Cropped Trench', category: 'Outerwear', color: 'Camel', material: 'Cotton', pattern: 'Solid', season: 'Spring', occasion: 'Smart', brand: 'Lune', status: ItemStatus.reviewed),
        Item(id: 'demo-8', name: 'Minimal Sneakers', category: 'Footwear', color: 'Chalk', material: 'Leather', pattern: 'Solid', season: 'All', occasion: 'Casual', brand: 'Beau', favorite: true, status: ItemStatus.reviewed),
        Item(id: 'demo-9', name: 'Leather Loafers', category: 'Footwear', color: 'Cognac', material: 'Leather', pattern: 'Solid', season: 'All', occasion: 'Work', brand: 'Atelier', status: ItemStatus.reviewed),
        Item(id: 'demo-10', name: 'Emerald Knit', category: 'Tops', color: 'Emerald', material: 'Wool', pattern: 'Solid', season: 'Winter', occasion: 'Casual', brand: 'Halden', favorite: true, status: ItemStatus.reviewed),
        Item(id: 'demo-11', name: 'Cashmere Scarf', category: 'Accessories', color: 'Sage', material: 'Cashmere', pattern: 'Solid', season: 'Winter', occasion: 'Casual', brand: 'Lune', favorite: true, status: ItemStatus.reviewed),
        Item(id: 'demo-12', name: 'Linen Dress', category: 'Dresses', color: 'Bone', material: 'Linen', pattern: 'Solid', season: 'Summer', occasion: 'Smart', brand: 'Lune', favorite: true, status: ItemStatus.reviewed),
      ];
}
