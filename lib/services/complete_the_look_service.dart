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
    // TODO(go-live): when a provider is configured, invoke the Edge Function
    // and return real affiliate offers here.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return _mockOffers(gap);
  }

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
