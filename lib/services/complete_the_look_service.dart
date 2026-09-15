import 'dart:async';

import '../core/supabase_service.dart';
import '../data/models/missing_item.dart';
import '../data/models/product_offer.dart';

/// Turns a detected [MissingItem] into shoppable product offers.
///
/// Live, this will call a `complete-the-look` Edge Function that queries an
/// affiliate provider (server-side key). Until that's wired, it returns
/// plausible mock offers so the whole loop is walkable — priced within the
/// gap's hint band and pointing at a shop search for the query.
class CompleteTheLookService {
  bool get isLive =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  Future<List<ProductOffer>> offersFor(MissingItem gap) async {
    if (isLive) {
      try {
        final res = await SupabaseService.client.functions.invoke(
          'complete-the-look',
          body: {
            'query': gap.query,
            'slot': gap.slot,
            'reason': gap.reason,
            'descriptor': gap.descriptor.toMap(),
            'priceMin': gap.priceHint.min,
            'priceMax': gap.priceHint.max,
          },
        );
        final data = res.data;
        if (data is Map && data['offers'] is List) {
          final list = (data['offers'] as List)
              .whereType<Map>()
              .map(_fromMap)
              .where((o) => o.url.isNotEmpty)
              .toList();
          if (list.isNotEmpty) return list; // real provider offers
        }
        // configured:false or no results → fall through to mock.
      } catch (_) {
        // Network / function error — mock keeps the loop walkable.
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 450));
    return _mockOffers(gap);
  }

  ProductOffer _fromMap(Map o) => ProductOffer(
        title: (o['title'] as String?) ?? '',
        brand: (o['brand'] as String?) ?? '',
        retailer: (o['retailer'] as String?) ?? '',
        priceCents: (o['price_cents'] as num?)?.toInt() ?? 0,
        imageUrl: o['image_url'] as String?,
        url: (o['url'] as String?) ?? '',
        isMock: false,
      );

  List<ProductOffer> _mockOffers(MissingItem gap) {
    const brands = ['Everlane', 'COS', 'Mango', 'Massimo Dutti', 'Uniqlo', 'Arket'];
    final band = gap.priceHint;
    final title = _titleCase(gap.query);

    return List.generate(3, (i) {
      final t = i / 2; // 0, .5, 1 across the price band
      final price = (band.min + (band.max - band.min) * t).round();
      final brand = brands[i % brands.length];
      final q = Uri.encodeComponent('$brand ${gap.query}');
      return ProductOffer(
        title: title,
        brand: brand,
        retailer: brand,
        priceCents: price * 100,
        url: 'https://www.google.com/search?tbm=shop&q=$q',
        isMock: true,
      );
    });
  }

  String _titleCase(String s) => s
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
