import 'dart:convert';

import 'package:http/http.dart' as http;

import 'catalog_photo.dart';

/// Fetches clothing from the free, no-auth DummyJSON API (dummyjson.com). It
/// covers the categories FakeStore lacks — Footwear (mens/womens shoes),
/// Dresses, and Accessories (bags) — plus more Tops. Best-effort: any failure
/// returns an empty list so callers keep placeholders. Demo-only.
class DummyJsonService {
  DummyJsonService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://dummyjson.com';

  /// DummyJSON category slug → the app's own category.
  static const _slugs = <String, String>{
    'mens-shirts': 'Tops',
    'tops': 'Tops',
    'mens-shoes': 'Footwear',
    'womens-shoes': 'Footwear',
    'womens-dresses': 'Dresses',
    'womens-bags': 'Accessories',
  };

  Future<List<CatalogPhoto>> clothing() async {
    final out = <CatalogPhoto>[];
    for (final entry in _slugs.entries) {
      try {
        final uri = Uri.parse(
            '$_base/products/category/${entry.key}?limit=10&select=title,thumbnail');
        final res = await _client.get(uri).timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;
        final body = jsonDecode(res.body);
        final list = (body is Map ? body['products'] : null) as List? ?? const [];
        for (final p in list) {
          if (p is! Map) continue;
          final img = (p['thumbnail'] ?? '').toString();
          if (!img.startsWith('http')) continue;
          out.add(CatalogPhoto(
            title: (p['title'] ?? '').toString(),
            category: entry.value,
            imageUrl: img,
          ));
        }
      } catch (_) {
        // best-effort per category
      }
    }
    return out;
  }
}
