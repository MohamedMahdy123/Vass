import 'dart:convert';

import 'package:http/http.dart' as http;

/// A real product from the free FakeStore API (fakestoreapi.com) — used in demo
/// mode to dress the sample wardrobe with genuine catalog photos.
class FakeStoreProduct {
  const FakeStoreProduct({
    required this.title,
    required this.category,
    required this.imageUrl,
  });

  final String title;

  /// Mapped to the app's own categories: Tops / Outerwear / Accessories.
  final String category;
  final String imageUrl;
}

/// Fetches clothing from the free, no-auth FakeStore API. Best-effort: any
/// failure (offline, CORS, timeout) returns an empty list so the caller keeps
/// its placeholder images. Demo-only — real user items are never touched.
class FakeStoreService {
  FakeStoreService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://fakestoreapi.com';
  static const _categories = ["men's clothing", "women's clothing"];

  Future<List<FakeStoreProduct>> clothing() async {
    final out = <FakeStoreProduct>[];
    for (final c in _categories) {
      try {
        final uri = Uri.parse('$_base/products/category/${Uri.encodeComponent(c)}');
        final res = await _client.get(uri).timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;
        final list = jsonDecode(res.body) as List;
        for (final p in list) {
          if (p is! Map) continue;
          final img = (p['image'] ?? '').toString();
          if (!img.startsWith('http')) continue;
          final title = (p['title'] ?? '').toString();
          out.add(FakeStoreProduct(
            title: title,
            category: _mapCategory(title),
            imageUrl: img,
          ));
        }
      } catch (_) {
        // best-effort per category
      }
    }
    return out;
  }

  /// FakeStore's clothing is mostly t-shirts and jackets; map by title keyword
  /// into the app's own category vocabulary.
  String _mapCategory(String title) {
    final t = title.toLowerCase();
    if (t.contains('jacket') || t.contains('coat')) return 'Outerwear';
    if (t.contains('backpack') || t.contains('bag')) return 'Accessories';
    return 'Tops';
  }
}
