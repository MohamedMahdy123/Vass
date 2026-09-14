import 'dart:convert';
import 'dart:typed_data';

import '../core/supabase_service.dart';

/// The result of a try-on render.
class TryOnResult {
  const TryOnResult({required this.bytes, required this.model, required this.isDemo});
  final Uint8List bytes;
  final String model;

  /// True when produced by the local demo stand-in rather than the real engine.
  final bool isDemo;
}

/// Thrown when the user has hit their monthly free try-on limit (HTTP 429 from
/// the Edge Function). Carries the numbers so the UI can be specific.
class TryOnQuotaException implements Exception {
  const TryOnQuotaException({this.used, this.limit});
  final int? used;
  final int? limit;

  @override
  String toString() => 'TryOnQuotaException(used: $used, limit: $limit)';
}

/// Runs a virtual try-on. Live, it calls the `try-on` Edge Function (FASHN via
/// fal.ai, key server-side); in demo mode — or if the engine isn't configured
/// yet — it returns a stand-in so the whole capture → result flow is walkable.
class TryOnService {
  bool get isLive =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  Future<TryOnResult> run({
    required Uint8List personBytes,
    required Uint8List garmentBytes,
    String category = 'auto',
  }) async {
    if (isLive) {
      try {
        final res = await SupabaseService.client.functions.invoke(
          'try-on',
          body: {
            'personImageBase64': base64Encode(personBytes),
            'garmentImageBase64': base64Encode(garmentBytes),
            'category': category,
          },
        );
        final data = res.data;
        // 429 = monthly free limit reached: surface it, don't silently fake it.
        if (res.status == 429) {
          final d = data is Map ? data : const {};
          throw TryOnQuotaException(
            used: d['used'] as int?,
            limit: d['limit'] as int?,
          );
        }
        if (data is Map && data['resultImageBase64'] is String) {
          return TryOnResult(
            bytes: base64Decode(data['resultImageBase64'] as String),
            model: (data['model'] as String?) ?? 'fashn',
            isDemo: false,
          );
        }
        // Reachable but unusable (e.g. FAL_KEY not set → 500): fall through to
        // the demo stand-in rather than blocking the flow.
      } on TryOnQuotaException {
        rethrow; // let the state show the quota message
      } catch (_) {
        // Network / function error — graceful demo fallback below.
      }
    }

    // Demo / fallback: we can't synthesize a real render locally, so we return
    // the person photo as a stand-in and flag it, so the UI is honest about it.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return TryOnResult(bytes: personBytes, model: 'demo', isDemo: true);
  }
}
