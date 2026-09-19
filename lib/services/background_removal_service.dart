import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/supabase_service.dart';

/// Removes a garment photo's background, returning a transparent PNG.
///
/// Two engines, best-effort in order:
/// 1. LIVE — the `remove-bg` Edge Function (fal.ai BiRefNet), used whenever the
///    user is signed in. Reliable, fast, server-side key. This is the real path.
/// 2. DEMO — the free `not-lain/background-removal` Hugging Face Space
///    (Gradio 5), a fallback so the capture flow still cuts out backgrounds
///    before a Supabase backend is wired up.
///
/// Non-blocking by contract: on any failure (quota, downtime, network) the
/// caller keeps the original photo — background removal is an enhancement, not a
/// gate on saving a wardrobe item.
class BackgroundRemovalService {
  BackgroundRemovalService({http.Client? client, String? hfToken})
      : _client = client ?? http.Client(),
        _authHeaders = (hfToken ?? Config.hfToken).isEmpty
            ? const {}
            : {'Authorization': 'Bearer ${hfToken ?? Config.hfToken}'};

  static const _host = 'https://not-lain-background-removal.hf.space';
  final http.Client _client;
  final Map<String, String> _authHeaders;

  bool get _isLive =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  /// Returns the cut-out PNG bytes, or null if removal isn't available.
  Future<Uint8List?> remove(Uint8List bytes) async {
    if (_isLive) {
      final cut = await _removeViaFunction(bytes);
      if (cut != null) return cut;
      // Function unreachable/misconfigured — fall through to the demo engine
      // rather than leaving the photo un-cut.
    }
    return _removeViaSpace(bytes);
  }

  /// LIVE path — fal.ai BiRefNet behind the `remove-bg` Edge Function.
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
      return null;
    } catch (_) {
      return null; // best-effort — caller falls back / keeps the original
    }
  }

  /// DEMO path — free Hugging Face Space (anonymous or HF-token quota).
  Future<Uint8List?> _removeViaSpace(Uint8List bytes) async {
    try {
      final path = await _upload(bytes);
      final body = jsonEncode({
        'data': [
          {'path': path, 'meta': {'_type': 'gradio.FileData'}},
        ],
      });
      final call = await _client.post(
        Uri.parse('$_host/gradio_api/call/png'),
        headers: {'content-type': 'application/json', ..._authHeaders},
        body: body,
      );
      final eventId = (jsonDecode(call.body) as Map)['event_id'] as String?;
      if (eventId == null) return null;

      final url = await _awaitResult(eventId);
      if (url == null) return null;
      final img = await _client.get(Uri.parse(url));
      return img.bodyBytes;
    } catch (_) {
      return null; // best-effort — keep the original photo
    }
  }

  Future<String> _upload(Uint8List bytes) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_host/gradio_api/upload'))
      ..headers.addAll(_authHeaders)
      ..files.add(http.MultipartFile.fromBytes('files', bytes, filename: 'item.png'));
    final resp = await http.Response.fromStream(await _client.send(req));
    return (jsonDecode(resp.body) as List).first as String;
  }

  Future<String?> _awaitResult(String eventId) async {
    final req = http.Request('GET', Uri.parse('$_host/gradio_api/call/png/$eventId'))
      ..headers.addAll(_authHeaders);
    final resp = await _client.send(req).timeout(const Duration(seconds: 120));

    String? currentEvent;
    await for (final line in resp.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
      } else if (line.startsWith('data:') && currentEvent == 'complete') {
        return _extractUrl(jsonDecode(line.substring(5).trim()));
      } else if (line.startsWith('data:') && currentEvent == 'error') {
        return null;
      }
    }
    return null;
  }

  /// The /png endpoint returns a FileData (or a URL string), possibly nested.
  String? _extractUrl(dynamic node) {
    if (node is String) {
      return node.startsWith('http') ? node : null;
    }
    if (node is Map) {
      final u = node['url'];
      if (u is String) return u;
      return null;
    }
    if (node is List) {
      for (final n in node) {
        final u = _extractUrl(n);
        if (u != null) return u;
      }
    }
    return null;
  }
}
