import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vess/services/background_removal_service.dart';

void main() {
  group('BackgroundRemovalService — best effort', () {
    final png = Uint8List.fromList(const [137, 80, 78, 71]);

    test('returns null when the upload call fails', () async {
      final svc = BackgroundRemovalService(
        client: MockClient((_) async => http.Response('boom', 500)),
      );
      expect(await svc.remove(png), isNull);
    });

    test('returns null when the call yields no event_id', () async {
      final svc = BackgroundRemovalService(
        client: MockClient((req) async {
          if (req.url.path.endsWith('/upload')) {
            return http.Response(jsonEncode(['/tmp/item.png']), 200);
          }
          return http.Response(jsonEncode({'detail': 'no quota'}), 200);
        }),
      );
      expect(await svc.remove(png), isNull);
    });

    test('never throws on network error — returns null', () async {
      final svc = BackgroundRemovalService(
        client: MockClient((_) async => throw Exception('offline')),
      );
      expect(await svc.remove(png), isNull);
    });
  });
}
