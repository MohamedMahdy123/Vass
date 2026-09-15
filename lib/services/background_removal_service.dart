import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/config.dart';

/// Removes a garment photo's background, returning a transparent PNG.
///
/// Uses the free `not-lain/background-removal` Hugging Face Space (Gradio 5).
/// Best-effort and non-blocking: on any failure (quota, downtime, network) the
/// caller keeps the original photo — background removal is an enhancement, not a
/// gate on saving a wardrobe item. A signed-in HF token ([Config.hfToken])
/// raises the free ZeroGPU quota; without it, anonymous runs are limited.
class BackgroundRemovalService {
  BackgroundRemovalService({http.Client? client, String? hfToken})
      : _client = client ?? http.Client(),
        _authHeaders = (hfToken ?? Config.hfToken).isEmpty
            ? const {}
            : {'Authorization': 'Bearer ${hfToken ?? Config.hfToken}'};

  static const _host = 'https://not-lain-background-removal.hf.space';
  final http.Client _client;
  final Map<String, String> _authHeaders;

  /// Returns the cut-out PNG bytes, or null if removal isn't available.
  Future<Uint8List?> remove(Uint8List bytes) async {
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
