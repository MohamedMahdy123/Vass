import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Free virtual try-on via the public IDM-VTON Hugging Face Space (Gradio API).
///
/// Produces a real render at no cost — used as the app's try-on engine until a
/// paid engine (FASHN via fal.ai) is configured with credits. It's slower and
/// queue-dependent (a render can take up to a minute or two on free GPUs), so
/// callers should show a patient loading state.
///
/// Protocol (Gradio 4.x): upload each image → POST /call/tryon to get an
/// event id → read the SSE stream until the `complete` event → download the
/// result image. CORS is permitted, so this runs directly from the client on
/// web and mobile alike.
class FreeTryOnService {
  FreeTryOnService({http.Client? client, Duration? retryDelay})
      : _client = client ?? http.Client(),
        _retryDelay = retryDelay ?? const Duration(seconds: 6);

  static const _host = 'https://yisol-idm-vton.hf.space';
  final http.Client _client;
  final Duration _retryDelay;

  static const engineName = 'idm-vton';

  /// Render, retrying once on a transient error (free GPUs occasionally hiccup
  /// or briefly rate-limit). A hard quota exhaustion won't recover in-window —
  /// callers fall back to the stand-in in that case.
  Future<Uint8List> render({
    required Uint8List personBytes,
    required Uint8List garmentBytes,
    String garmentDescription = 'a garment',
    int denoiseSteps = 30,
    int seed = 42,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _renderOnce(
          personBytes: personBytes,
          garmentBytes: garmentBytes,
          garmentDescription: garmentDescription,
          denoiseSteps: denoiseSteps,
          seed: seed + attempt,
        );
      } catch (e) {
        lastError = e;
        if (attempt == 0) await Future<void>.delayed(_retryDelay);
      }
    }
    throw lastError!;
  }

  Future<Uint8List> _renderOnce({
    required Uint8List personBytes,
    required Uint8List garmentBytes,
    required String garmentDescription,
    required int denoiseSteps,
    required int seed,
  }) async {
    final personPath = await _upload(personBytes, 'person.png');
    final garmentPath = await _upload(garmentBytes, 'garment.png');

    final body = jsonEncode({
      'data': [
        {
          'background': {'path': personPath, 'meta': {'_type': 'gradio.FileData'}},
          'layers': <dynamic>[],
          'composite': null,
        },
        {'path': garmentPath, 'meta': {'_type': 'gradio.FileData'}},
        garmentDescription,
        true, // auto-mask the person
        false, // don't crop
        denoiseSteps,
        seed,
      ],
    });

    final call = await _client.post(
      Uri.parse('$_host/call/tryon'),
      headers: {'content-type': 'application/json'},
      body: body,
    );
    final eventId = (jsonDecode(call.body) as Map)['event_id'] as String?;
    if (eventId == null) throw Exception('Try-on did not start');

    final resultUrl = await _awaitResult(eventId);
    final img = await _client.get(Uri.parse(resultUrl));
    return img.bodyBytes;
  }

  Future<String> _upload(Uint8List bytes, String filename) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_host/upload'))
      ..files.add(http.MultipartFile.fromBytes('files', bytes, filename: filename));
    final resp = await http.Response.fromStream(await req.send());
    final list = jsonDecode(resp.body) as List;
    return list.first as String;
  }

  /// Read the Server-Sent-Events stream until the `complete` event, and return
  /// the URL of the rendered image.
  Future<String> _awaitResult(String eventId) async {
    final req = http.Request('GET', Uri.parse('$_host/call/tryon/$eventId'));
    final resp = await _client.send(req).timeout(const Duration(seconds: 240));

    String? currentEvent;
    await for (final line in resp.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
      } else if (line.startsWith('data:') && currentEvent == 'complete') {
        final data = jsonDecode(line.substring(5).trim());
        if (data is List && data.isNotEmpty && data.first is Map) {
          final url = (data.first as Map)['url'];
          if (url is String) return url;
        }
        throw Exception('Unexpected try-on result shape');
      } else if (line.startsWith('data:') && currentEvent == 'error') {
        throw Exception('Try-on engine returned an error');
      }
    }
    throw Exception('Try-on stream ended without a result');
  }
}
