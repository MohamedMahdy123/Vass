import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models/item.dart';

/// Builds a large demo wardrobe (100+ pieces) from free, no-auth product
/// catalogs so demo mode looks like a real, well-stocked closet. Every item
/// carries a real product-photo URL.
///
/// Sources: DummyJSON (cdn.dummyjson.com — clean isolated shots, multiple
/// angles per product) and FakeStore (fakestoreapi.com). Best-effort: any
/// failure returns an empty list and the caller keeps the curated seed.
///
/// Note: free catalogs only hold ~50 distinct fashion products, so to reach
/// 100+ this uses up to two photos per product (different angles). Bottoms and
/// Outerwear are sparse — no free source carries jeans or coats beyond the
/// curated seed.
class DemoCatalogService {
  DemoCatalogService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _dummyBase = 'https://dummyjson.com';
  static const _dummyCats = <String, String>{
    'mens-shirts': 'Tops',
    'tops': 'Tops',
    'womens-dresses': 'Dresses',
    'mens-shoes': 'Footwear',
    'womens-shoes': 'Footwear',
    'womens-bags': 'Accessories',
    'womens-jewellery': 'Accessories',
    'sunglasses': 'Accessories',
    'mens-watches': 'Accessories',
    'womens-watches': 'Accessories',
  };

  static const _colorWords = <String>[
    'black', 'white', 'blue', 'navy', 'grey', 'gray', 'green', 'red', 'pink',
    'brown', 'beige', 'cream', 'tan', 'olive', 'burgundy', 'khaki', 'denim',
    'yellow', 'orange', 'purple', 'silver', 'gold', 'charcoal', 'sand',
  ];

  /// Fetch and assemble the catalog. [maxPerProduct] caps how many angles of a
  /// single product become separate items (keeps the grid from filling with
  /// near-duplicates).
  Future<List<Item>> build({int maxPerProduct = 2}) async {
    final items = <Item>[];
    await _addDummyJson(items, maxPerProduct);
    await _addFakeStore(items);
    return items;
  }

  Future<void> _addDummyJson(List<Item> out, int maxPerProduct) async {
    for (final entry in _dummyCats.entries) {
      try {
        final uri = Uri.parse(
            '$_dummyBase/products/category/${entry.key}?limit=0&select=title,images,thumbnail');
        final res = await _client.get(uri).timeout(const Duration(seconds: 12));
        if (res.statusCode != 200) continue;
        final body = jsonDecode(res.body);
        final products = (body is Map ? body['products'] : null) as List? ?? const [];
        for (final p in products) {
          if (p is! Map) continue;
          final title = (p['title'] ?? 'Piece').toString();
          final imgs = <String>[];
          final arr = p['images'];
          if (arr is List) {
            for (final u in arr) {
              final s = u.toString();
              if (s.startsWith('http')) imgs.add(s);
            }
          }
          final thumb = (p['thumbnail'] ?? '').toString();
          if (imgs.isEmpty && thumb.startsWith('http')) imgs.add(thumb);
          final take = imgs.take(maxPerProduct).toList();
          for (var i = 0; i < take.length; i++) {
            out.add(_item(
              id: 'cat-dj-${entry.key}-${out.length}',
              name: take.length > 1 && i > 0 ? '$title (${i + 1})' : title,
              category: entry.value,
              imageUrl: take[i],
            ));
          }
        }
      } catch (_) {/* best-effort per category */}
    }
  }

  Future<void> _addFakeStore(List<Item> out) async {
    for (final c in const ["men's clothing", "women's clothing"]) {
      try {
        final uri = Uri.parse(
            'https://fakestoreapi.com/products/category/${Uri.encodeComponent(c)}');
        final res = await _client.get(uri).timeout(const Duration(seconds: 12));
        if (res.statusCode != 200) continue;
        final list = jsonDecode(res.body) as List;
        for (final p in list) {
          if (p is! Map) continue;
          final title = (p['title'] ?? '').toString();
          final img = (p['image'] ?? '').toString();
          if (!img.startsWith('http')) continue;
          final t = title.toLowerCase();
          if (t.contains('backpack') || t.contains('bag')) continue;
          final cat = (t.contains('jacket') || t.contains('coat')) ? 'Outerwear' : 'Tops';
          out.add(_item(
            id: 'cat-fs-${out.length}',
            name: title.length > 40 ? '${title.substring(0, 38)}…' : title,
            category: cat,
            imageUrl: img,
          ));
        }
      } catch (_) {/* best-effort */}
    }
  }

  Item _item({
    required String id,
    required String name,
    required String category,
    required String imageUrl,
  }) {
    final lower = name.toLowerCase();
    final color = _colorWords.firstWhere(lower.contains, orElse: () => '');
    final season = category == 'Outerwear'
        ? 'Winter'
        : (category == 'Dresses' ? 'Summer' : 'All');
    final occasion = category == 'Footwear' || category == 'Accessories'
        ? 'Casual'
        : 'Casual';
    return Item(
      id: id,
      name: name,
      processedImageUrl: imageUrl,
      category: category,
      color: color.isEmpty ? null : _titleCase(color),
      season: season,
      occasion: occasion,
      status: ItemStatus.reviewed,
    );
  }

  String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
