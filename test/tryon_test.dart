import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vess/data/models/catalog_item.dart';
import 'package:vess/data/models/tryon.dart';
import 'package:vess/services/tryon_service.dart';
import 'package:vess/state/tryon_state.dart';

void main() {
  final person = Uint8List.fromList(List<int>.filled(48, 3));
  final garment = Uint8List.fromList(List<int>.filled(48, 9));

  group('TryOnService (demo mode)', () {
    test('returns a walkable stand-in flagged as demo', () async {
      final s = TryOnService();
      expect(s.isLive, isFalse);

      final r = await s.run(personBytes: person, garmentBytes: garment);
      expect(r.isDemo, isTrue);
      expect(r.model, 'demo');
      expect(r.bytes, isNotEmpty);
    });
  });

  group('TryOnState (demo mode)', () {
    test('loads a demo catalog spanning multiple categories', () async {
      final st = TryOnState();
      expect(st.isLive, isFalse);

      await st.loadCatalog();
      expect(st.catalog, isNotEmpty);
      final cats = st.catalog.map((c) => c.category).toSet();
      expect(cats.length, greaterThan(1));
    });

    test('run produces a result and records the garment source', () async {
      final st = TryOnState();
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

    test('clearResult resets between try-ons', () async {
      final st = TryOnState();
      await st.run(
        personBytes: person,
        garmentBytes: garment,
        source: GarmentSource.upload,
      );
      expect(st.hasResult, isTrue);

      st.clearResult();
      expect(st.hasResult, isFalse);
      expect(st.result, isNull);
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
