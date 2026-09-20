import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/supabase_service.dart';
import 'bg_removal/bg_remover.dart';

export 'bg_removal/bg_remover.dart' show BgRemovalOutcome;

/// Background removal for garment photos, on-device first with a cloud fallback.
///
/// 1. LOCAL (default, free, offline) — Google ML Kit **Subject Segmentation** on
///    Android and Apple **Vision** on iOS (see [BgRemover]). Produces a tight,
///    transparent PNG. Photos never leave the device.
/// 2. CLOUD FALLBACK — when the local model produces nothing (the ML Kit model
///    hasn't downloaded via Play services, no clear subject, or an unsupported
///    platform) AND the user is signed in, the `remove-bg` Edge Function
///    (fal.ai BiRefNet) removes the background server-side, so the feature works
///    on every device.
///
/// Best-effort by contract: if neither path yields a cut-out, the caller keeps
/// the original photo — removal is an enhancement, never a gate on saving.
class BackgroundRemovalService {
  BackgroundRemovalService({BgRemover? remover})
      : _remover = remover ?? makeBgRemover();

  final BgRemover _remover;

  bool get _isLive =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  Future<BgRemovalOutcome> remove(Uint8List bytes) async {
    final local = await _remover.remove(bytes);
    if (local.cutout != null) return local;

    // Local model gave us nothing usable — try the server-side remover.
    if (_isLive) {
      final cut = await _removeViaFunction(bytes);
      if (cut != null) return BgRemovalOutcome(cutout: cut, attempted: true);
    }
    return local; // keep the local outcome (its error/attempted flags stand)
  }

  /// fal.ai BiRefNet via the `remove-bg` Edge Function. Returns transparent PNG
  /// bytes, or null on any failure (best-effort).
  Future<Uint8List?> _removeViaFunction(Uint8List bytes) async {
    try {
      final res = await SupabaseService.client.functions.invoke(
        'remove-bg',
        body: {'imageBase64': base64Encode(bytes), 'mediaType': 'image/jpeg'},
      );
      final data = res.data;
      if (data is Map && data['imageBase64'] is String) {
        return base64Decode(data['imageBase64'] as String);
      }
      if (data is Map && data['error'] != null) {
        debugPrint('[bg_removal] cloud fallback error: ${data['error']}');
      }
      return null;
    } catch (e) {
      debugPrint('[bg_removal] cloud fallback failed: $e');
      return null;
    }
  }
}
