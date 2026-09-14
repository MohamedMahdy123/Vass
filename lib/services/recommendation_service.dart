import '../core/supabase_service.dart';
import '../data/models/item.dart';
import '../data/models/outfit.dart';
import 'outfit_engine.dart';

/// Produces "What should I wear today?" recommendations. Live, it calls the
/// `recommend` Edge Function (Claude Sonnet picks from the user's items and
/// writes the "why"); in demo mode — or if the call fails — it falls back to
/// the local [OutfitEngine] so the user always gets a coherent look.
class RecommendationService {
  bool get isLive =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  Future<OutfitSuggestion?> recommend(
    List<Item> items, {
    String? occasion,
    String? weather,
    Set<String> dislikedIds = const {},
    int seed = 0,
  }) async {
    if (items.isEmpty) return null;

    if (isLive) {
      try {
        final payload = items
            .where((i) => !dislikedIds.contains(i.id))
            .map((i) => {
                  'id': i.id,
                  'name': i.name,
                  'category': i.category,
                  'color': i.color,
                  'material': i.material,
                  'pattern': i.pattern,
                  'season': i.season,
                  'occasion': i.occasion,
                  'wear_count': i.wearCount,
                })
            .toList();

        final res = await SupabaseService.client.functions.invoke(
          'recommend',
          body: {
            'items': payload,
            'occasion': occasion,
            'weather': weather,
          },
        );
        final data = res.data;
        if (data is Map && data['outfit'] is Map) {
          final o = Map<String, dynamic>.from(data['outfit'] as Map);
          final ids = (o['item_ids'] as List?)?.cast<String>() ?? const [];
          // Guard: the model must have chosen from the real wardrobe.
          final valid = ids.where((id) => items.any((i) => i.id == id)).toList();
          if (valid.isNotEmpty) {
            return OutfitSuggestion(
              title: (o['title'] as String?) ?? 'Your look',
              itemIds: valid,
              reason: (o['reason'] as String?) ?? '',
              occasion: occasion,
            );
          }
        }
        // Reachable but unusable (e.g. missing ANTHROPIC_API_KEY → 500):
        // fall through to the local engine rather than showing nothing.
      } catch (_) {
        // Network / function error — same graceful fallback.
      }
    }

    // Demo, or live fallback.
    await Future<void>.delayed(const Duration(milliseconds: 550));
    return OutfitEngine.build(
      items,
      occasion: occasion,
      weather: weather,
      dislikedIds: dislikedIds,
      seed: seed,
    );
  }
}
