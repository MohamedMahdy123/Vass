import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vess/data/models/catalog_item.dart';
import 'package:vess/data/models/tryon.dart';
import 'package:vess/services/free_tryon_service.dart';
import 'package:vess/services/tryon_service.dart';
import 'package:vess/state/tryon_state.dart';

void main() {
  final person = Uint8List.fromList(List<int>.filled(48, 3));
  final garment = Uint8List.fromList(List<int>.filled(48, 9));

  // A TryOnService whose free engine can't reach the network — used to exercise
  // the "engine unavailable" path without any real HTTP.
  TryOnService offlineService() => TryOnService(
        freeEngine: FreeTryOnService(
          client: MockClient((_) async => http.Response('offline', 503)),
          retryDelay: Duration.zero,
        ),
      );

  // A free engine whose HTTP is stubbed to a successful render, so result/
  // history logic can be tested deterministically and offline.
  TryOnService renderingService() => TryOnService(
        freeEngine: FreeTryOnService(
          retryDelay: Duration.zero,
          client: MockClient((req) async {
            final u = req.url.toString();
            if (u.endsWith('/upload')) return http.Response('["/tmp/f.png"]', 200);
            if (u.endsWith('/call/tryon')) return http.Response('{"event_id":"e1"}', 200);
            if (u.contains('/call/tryon/e1')) {
              return http.Response(
                  'event: complete\ndata: [{"url":"https://x/file=/tmp/r.png"}]\n\n', 200);
            }
            if (u.contains('/file=')) return http.Response.bytes(<int>[1, 2, 3, 4], 200);
            return http.Response('nope', 404);
          }),
        ),
      );

  group('TryOnService', () {
    test('throws EngineUnavailable when no engine can render', () async {
      final s = offlineService();
      expect(s.isLive, isFalse);
      await expectLater(
        s.run(personBytes: person, garmentBytes: garment),
        throwsA(isA<TryOnEngineUnavailableException>()),
      );
    });

    test('returns a real render when the free engine succeeds', () async {
      final r = await renderingService().run(personBytes: person, garmentBytes: garment);
      expect(r.model, 'idm-vton');
      expect(r.bytes, [1, 2, 3, 4]);
    });
  });

  group('TryOnState (demo mode)', () {
    test('loads a demo catalog spanning multiple categories', () async {
      final st = TryOnState(service: offlineService());
      expect(st.isLive, isFalse);

      await st.loadCatalog();
      expect(st.catalog, isNotEmpty);
      final cats = st.catalog.map((c) => c.category).toSet();
      expect(cats.length, greaterThan(1));
    });

    test('run produces a result and records the garment source', () async {
      final st = TryOnState(service: renderingService());
      expect(st.hasResult, isFalse);

      await st.run(
        personBytes: person,
        garmentBytes: garment,
        source: GarmentSource.catalog,
        garmentCatalogId: 'cat-1',
      );

      expect(st.hasResult, isTrue);
      expect(st.result!.garmentSource, GarmentSource.catalog);
      expect(st.result!.garmentCatalogId, 'cat-1');
      expect(st.result!.resultBytes, isNotNull);
      expect(st.result!.status, TryOnStatus.succeeded);
    });

    test('clearResult resets the result but keeps history', () async {
      final st = TryOnState(service: renderingService());
      await st.run(
        personBytes: person,
        garmentBytes: garment,
        source: GarmentSource.upload,
      );
      expect(st.hasResult, isTrue);

      st.clearResult();
      expect(st.hasResult, isFalse);
      expect(st.result, isNull);
      // History survives so the strip still shows past renders.
      expect(st.hasHistory, isTrue);
    });

    test('each run is recorded in history, newest first', () async {
      final st = TryOnState(service: renderingService());
      expect(st.hasHistory, isFalse);

      await st.run(
          personBytes: person, garmentBytes: garment,
          source: GarmentSource.catalog, garmentCatalogId: 'cat-1');
      await st.run(
          personBytes: person, garmentBytes: garment,
          source: GarmentSource.upload);

      expect(st.history.length, 2);
      expect(st.history.first.garmentSource, GarmentSource.upload); // newest first
      expect(st.history.last.garmentCatalogId, 'cat-1');
    });

    test('surfaces a friendly error (no fake result) when engine is down',
        () async {
      final st = TryOnState(service: offlineService());
      await st.run(
        personBytes: person,
        garmentBytes: garment,
        source: GarmentSource.upload,
      );
      expect(st.hasResult, isFalse); // no stand-in masquerading as a result
      expect(st.error, isNotNull);
      expect(st.error!.toLowerCase(), contains('try again'));
    });
  });

  group('models', () {
    test('CatalogItem formats a price label', () {
      const c = CatalogItem(
        id: 'x', name: 'Shirt', imagePath: 'p', priceCents: 8900,
      );
      expect(c.priceLabel, '\$89');
    });

    test('TryOn round-trips source + status through toInsert / fromMap', () {
      const t = TryOn(
        garmentSource: GarmentSource.closet,
        garmentItemId: 'item-1',
        status: TryOnStatus.processing,
        model: 'fashn/tryon/v1.6',
      );
      final row = t.toInsert();
      expect(row['garment_source'], 'closet');
      expect(row['garment_item_id'], 'item-1');
      expect(row['status'], 'processing');

      final back = TryOn.fromMap({
        'id': 'tid',
        'garment_source': row['garment_source'],
        'garment_item_id': row['garment_item_id'],
        'status': 'succeeded',
        'model': row['model'],
      });
      expect(back.id, 'tid');
      expect(back.garmentSource, GarmentSource.closet);
      expect(back.status, TryOnStatus.succeeded);
      expect(back.isDone, isTrue);
    });
  });
}
