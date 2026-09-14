import 'dart:convert';
import 'dart:typed_data';

import '../core/supabase_service.dart';
import 'free_tryon_service.dart';

/// The result of a try-on render.
class TryOnResult {
  const TryOnResult({required this.bytes, required this.model});
  final Uint8List bytes;
  final String model;
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

/// Thrown when no engine could produce a render — the paid engine isn't
/// configured and the free engine is down or over its (free-GPU) limit. The UI
/// asks the user to try again later rather than showing a fake result.
class TryOnEngineUnavailableException implements Exception {
  const TryOnEngineUnavailableException();
  @override
  String toString() => 'TryOnEngineUnavailableException';
}

/// Runs a virtual try-on. It prefers the paid FASHN engine (via the `try-on`
/// Edge Function) when live and funded, then falls back to a free real render
/// (IDM-VTON on Hugging Face), and finally to an honest stand-in. So the
/// feature produces a real render even in demo mode, at no cost.
class TryOnService {
  TryOnService({FreeTryOnService? freeEngine})
      : _free = freeEngine ?? FreeTryOnService();

  final FreeTryOnService _free;

  bool get isLive =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  Future<TryOnResult> run({
    required Uint8List personBytes,
    required Uint8List garmentBytes,
    String category = 'auto',
    String? garmentDescription,
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
          );
        }
        // Reachable but unusable (e.g. FAL_KEY not set → 500): fall through to
        // the demo stand-in rather than blocking the flow.
      } on TryOnQuotaException {
        rethrow; // let the state show the quota message
      } catch (_) {
        // Network / function error — fall through to the free engine.
      }
    }

    // Free engine: a real render via IDM-VTON (Hugging Face) at no cost. This
    // is what powers try-on until a paid engine (FASHN) has credits — including
    // demo mode, so the feature actually works out of the box.
    try {
      final bytes = await _free.render(
        personBytes: personBytes,
        garmentBytes: garmentBytes,
        garmentDescription: garmentDescription ?? 'a garment',
      );
      return TryOnResult(bytes: bytes, model: FreeTryOnService.engineName);
    } catch (_) {
      // Both engines unavailable — tell the user honestly instead of faking a
      // result with their own photo.
      throw const TryOnEngineUnavailableException();
    }
  }
}
