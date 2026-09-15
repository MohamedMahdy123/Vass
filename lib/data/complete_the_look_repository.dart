import '../core/supabase_service.dart';
import 'models/product_offer.dart';

/// Best-effort logging of the affiliate funnel. Live-only and never throws —
/// analytics must not get in the way of the user shopping.
class CompleteTheLookRepository {
  bool get _live =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  Future<void> logClick(ProductOffer offer) => _log('click', offer);

  Future<void> _log(String event, ProductOffer offer) async {
    if (!_live) return;
    try {
      await SupabaseService.client.from('affiliate_events').insert({
        'provider': offer.isMock ? 'mock' : 'shopstyle',
        'product_url': offer.url,
        'brand': offer.brand,
        'event': event,
      });
    } catch (_) {
      // Table may not exist yet / offline — ignore.
    }
  }
}
