import '../core/supabase_service.dart';
import 'models/item.dart';
import 'models/outfit.dart';

/// A saved canvas look as stored in `outfits` (source='canvas') with its member
/// item ids. Score and style tags are not persisted — they're recomputed from
/// the members via [OutfitState.analyze], which is deterministic.
class CanvasLookRow {
  const CanvasLookRow({
    required this.id,
    required this.title,
    required this.itemIds,
    this.occasion,
  });

  final String id;
  final String title;
  final List<String> itemIds;
  final String? occasion;
}

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

  // --- Canvas "My Outfits" (source = 'canvas') ------------------------------

  /// Persist a look the user composed on the Outfit Canvas. Tagged
  /// `source: 'canvas'` so [listCanvasLooks] can return only user-saved looks,
  /// never recommendation history. Returns the new outfit id.
  Future<String> saveCanvasLook({
    required String title,
    String? occasion,
    required List<String> itemIds,
    Map<String, String> slotFor = const {},
  }) async {
    final row = await SupabaseService.client
        .from('outfits')
        .insert({
          'title': title,
          'occasion': occasion,
          'status': OutfitStatus.accepted.name,
          'source': 'canvas',
        })
        .select()
        .single();
    final id = row['id'] as String;

    if (itemIds.isNotEmpty) {
      final members = itemIds
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

  /// The user's saved canvas looks, newest first. Each row carries its member
  /// item ids in canvas order; the caller resolves them against the wardrobe
  /// and recomputes score/tags locally (they're deterministic).
  Future<List<CanvasLookRow>> listCanvasLooks() async {
    final rows = await SupabaseService.client
        .from('outfits')
        .select('id, title, occasion, outfit_items(item_id)')
        .eq('source', 'canvas')
        .order('created_at', ascending: false);

    return (rows as List).map((r) {
      final itemIds = (((r as Map)['outfit_items'] as List?) ?? const [])
          .map((m) => (m as Map)['item_id'] as String)
          .toList();
      return CanvasLookRow(
        id: r['id'] as String,
        title: (r['title'] as String?) ?? 'Your look',
        occasion: r['occasion'] as String?,
        itemIds: itemIds,
      );
    }).toList();
  }

  /// Delete a saved look; `outfit_items` rows cascade.
  Future<void> deleteOutfit(String outfitId) async {
    await SupabaseService.client.from('outfits').delete().eq('id', outfitId);
  }

  // --- Outfit calendar (planned_outfits) ------------------------------------

  /// Every planned day → the outfit id planned for it (`yyyy-MM-dd` keys).
  Future<Map<String, String>> listPlans() async {
    final rows = await SupabaseService.client
        .from('planned_outfits')
        .select('plan_date, outfit_id');
    final out = <String, String>{};
    for (final r in (rows as List)) {
      final date = (r as Map)['plan_date'] as String?;
      final outfitId = r['outfit_id'] as String?;
      if (date != null && outfitId != null) {
        // Postgres `date` serializes as 'yyyy-MM-dd' (optionally with time).
        out[date.split('T').first] = outfitId;
      }
    }
    return out;
  }

  /// Plan [outfitId] for [dateKey] (`yyyy-MM-dd`), replacing any prior plan.
  Future<void> setPlan(String dateKey, String outfitId) async {
    await SupabaseService.client.from('planned_outfits').upsert(
      {'plan_date': dateKey, 'outfit_id': outfitId},
      onConflict: 'user_id,plan_date',
    );
  }

  Future<void> clearPlan(String dateKey) async {
    await SupabaseService.client
        .from('planned_outfits')
        .delete()
        .eq('plan_date', dateKey);
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
