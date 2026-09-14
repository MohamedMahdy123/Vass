import '../core/supabase_service.dart';
import 'models/item.dart';
import 'models/outfit.dart';

/// Persistence for recommendations and the light-touch learning behind them.
/// RLS scopes every write to the signed-in user, so we never send user_id.
class OutfitsRepository {
  /// Save a suggested/accepted look and its members. `slotFor` maps an item id
  /// to its slot label ('Top', 'Bottom', 'Shoes', …) for `outfit_items.slot`.
  /// Returns the new outfit id.
  Future<String> save(
    OutfitSuggestion outfit, {
    Map<String, String> slotFor = const {},
  }) async {
    final row = await SupabaseService.client
        .from('outfits')
        .insert(outfit.toInsert())
        .select()
        .single();
    final id = row['id'] as String;

    if (outfit.itemIds.isNotEmpty) {
      final members = outfit.itemIds
          .map((itemId) => {
                'outfit_id': id,
                'item_id': itemId,
                'slot': slotFor[itemId],
              })
          .toList();
      await SupabaseService.client.from('outfit_items').insert(members);
    }
    return id;
  }

  Future<void> setStatus(String outfitId, OutfitStatus status) async {
    await SupabaseService.client
        .from('outfits')
        .update({'status': status.name}).eq('id', outfitId);
  }

  /// Bump wear counts + last-worn when a look is accepted (worn). Read-modify-
  /// write per item since PostgREST can't express `wear_count + 1` inline.
  Future<void> markWorn(List<Item> items) async {
    final now = DateTime.now().toUtc().toIso8601String();
    for (final i in items) {
      await SupabaseService.client.from('items').update({
        'wear_count': i.wearCount + 1,
        'last_worn_at': now,
      }).eq('id', i.id);
    }
  }

  /// Merge learning signal into the user's preferences row. A liked pairing is
  /// the accepted item ids; disliked items accumulate the rejected pieces.
  Future<void> learn({
    List<String>? likedPairing,
    List<String>? addDisliked,
  }) async {
    final client = SupabaseService.client;
    final userId = client.auth.currentUser!.id;
    final current = await client
        .from('preferences')
        .select('liked_pairings, disliked_item_ids')
        .eq('user_id', userId)
        .maybeSingle();

    final pairings = <dynamic>[
      ...((current?['liked_pairings'] as List?) ?? const []),
    ];
    final disliked = <String>{
      ...(((current?['disliked_item_ids'] as List?) ?? const [])
          .cast<String>()),
    };

    if (likedPairing != null && likedPairing.isNotEmpty) {
      pairings.add(likedPairing);
    }
    if (addDisliked != null) disliked.addAll(addDisliked);

    await client.from('preferences').upsert({
      'user_id': userId,
      'liked_pairings': pairings,
      'disliked_item_ids': disliked.toList(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
