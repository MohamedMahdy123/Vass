import 'dart:convert';

import 'package:http/http.dart' as http;

import 'catalog_photo.dart';

/// Fetches clothing from the free, no-auth FakeStore API (fakestoreapi.com).
/// Covers Tops and Outerwear (t-shirts + jackets). Best-effort: any failure
/// (offline, CORS, timeout) returns an empty list so callers keep placeholders.
/// Demo-only — real user items are never touched.
class FakeStoreService {
  FakeStoreService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://fakestoreapi.com';
  static const _categories = ["men's clothing", "women's clothing"];

  Future<List<CatalogPhoto>> clothing() async {
    final out = <CatalogPhoto>[];
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
          final cat = _mapCategory(title);
          if (cat == null) continue; // skip bags/other
          out.add(CatalogPhoto(title: title, category: cat, imageUrl: img));
        }
      } catch (_) {
        // best-effort per category
      }
    }
    return out;
  }

  /// FakeStore's clothing is t-shirts and jackets; map by title keyword. Bags
  /// (the backpack) are dropped so they don't stand in for a scarf.
  String? _mapCategory(String title) {
    final t = title.toLowerCase();
    if (t.contains('jacket') || t.contains('coat')) return 'Outerwear';
    if (t.contains('backpack') || t.contains('bag')) return null;
    return 'Tops';
  }
}
