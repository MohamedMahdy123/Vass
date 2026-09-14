import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import 'models/item.dart';

/// Data access for the wardrobe, backed by Supabase (Postgres + storage).
/// RLS scopes every query to the signed-in user, so we never filter by user_id
/// here — the database enforces it.
///
/// Requires a configured Supabase project. In demo mode the screens still use
/// the in-memory prototype store; this repository is wired into the UI in M1.
class WardrobeRepository {
  static const _bucket = 'wardrobe';

  /// All of the user's items, newest first.
  Future<List<Item>> fetchItems() async {
    final rows = await SupabaseService.client
        .from('items')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Item.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Upload a photo to the caller's folder and return its storage path.
  Future<String> uploadPhoto(String itemId, Uint8List bytes) async {
    final userId = SupabaseService.client.auth.currentUser!.id;
    final path = '$userId/$itemId.jpg';
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return path;
  }

  /// A short-lived URL for displaying a stored photo.
  Future<String> signedUrl(String path, {int expiresIn = 3600}) {
    return SupabaseService.client.storage
        .from(_bucket)
        .createSignedUrl(path, expiresIn);
  }

  Future<Item> add(Item item) async {
    final row = await SupabaseService.client
        .from('items')
        .insert(item.toInsert())
        .select()
        .single();
    return Item.fromMap(row);
  }

  Future<void> update(String id, Map<String, dynamic> changes) async {
    await SupabaseService.client.from('items').update(changes).eq('id', id);
  }

  Future<void> remove(String id) async {
    await SupabaseService.client.from('items').delete().eq('id', id);
  }
}
