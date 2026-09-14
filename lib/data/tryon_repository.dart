import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import 'models/catalog_item.dart';
import 'models/tryon.dart';

/// Data access for virtual try-on: the platform catalog, private image storage
/// (body photos, uploaded garments, results), and the `tryons` rows. RLS scopes
/// every private read/write to the signed-in user.
class TryOnRepository {
  static const _bucket = 'tryon';
  static const _catalogBucket = 'catalog';

  Future<List<CatalogItem>> fetchCatalog() async {
    final rows = await SupabaseService.client
        .from('catalog_items')
        .select()
        .eq('active', true)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => CatalogItem.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Public URL for a catalog product image.
  String catalogImageUrl(String path) =>
      SupabaseService.client.storage.from(_catalogBucket).getPublicUrl(path);

  Future<String> _upload(String path, Uint8List bytes) async {
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return path;
  }

  Future<String> uploadBody(String tryonId, Uint8List bytes) {
    final uid = SupabaseService.client.auth.currentUser!.id;
    return _upload('$uid/$tryonId/person.jpg', bytes);
  }

  Future<String> uploadGarment(String tryonId, Uint8List bytes) {
    final uid = SupabaseService.client.auth.currentUser!.id;
    return _upload('$uid/$tryonId/garment.jpg', bytes);
  }

  Future<String> uploadResult(String tryonId, Uint8List bytes) {
    final uid = SupabaseService.client.auth.currentUser!.id;
    return _upload('$uid/$tryonId/result.jpg', bytes);
  }

  Future<String> signedUrl(String path, {int expiresIn = 3600}) {
    return SupabaseService.client.storage
        .from(_bucket)
        .createSignedUrl(path, expiresIn);
  }

  Future<TryOn> create(TryOn tryOn) async {
    final row = await SupabaseService.client
        .from('tryons')
        .insert(tryOn.toInsert())
        .select()
        .single();
    return TryOn.fromMap(row);
  }

  Future<void> update(String id, Map<String, dynamic> changes) async {
    await SupabaseService.client.from('tryons').update(changes).eq('id', id);
  }

  Future<List<TryOn>> history() async {
    final rows = await SupabaseService.client
        .from('tryons')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => TryOn.fromMap(r as Map<String, dynamic>))
        .toList();
  }
}
