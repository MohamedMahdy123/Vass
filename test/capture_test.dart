import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vess/data/models/item.dart';
import 'package:vess/services/analysis_service.dart';
import 'package:vess/state/wardrobe_state.dart';

void main() {
  // A tiny non-empty byte buffer standing in for a photo.
  final photo = Uint8List.fromList(List<int>.filled(64, 7));

  group('AnalysisService (demo mode)', () {
    test('returns a usable attribute set for a photo', () async {
      final a = AnalysisService();
      expect(a.isLive, isFalse);

      final attrs = await a.analyze(photo);
      expect(attrs['name'], isNotNull);
      expect(attrs['category'], isNotNull);
    });

    test('rotates through varied stubs across calls', () async {
      final a = AnalysisService();
      final first = await a.analyze(photo);
      final second = await a.analyze(photo);
      // Different photos should not all collapse to one identical draft.
      expect(first['name'], isNot(second['name']));
    });
  });

  group('WardrobeState.commitCaptured (demo mode)', () {
    test('adds the reviewed piece with its photo bytes for preview', () async {
      final w = WardrobeState();
      await w.load();
      final before = w.count;

      const draft = Item(
        id: '',
        name: 'Scanned Jacket',
        category: 'Outerwear',
        color: 'Camel',
        status: ItemStatus.reviewed,
      );
      await w.commitCaptured(draft, photo);

      expect(w.count, before + 1);
      final saved = w.items.first;
      expect(saved.name, 'Scanned Jacket');
      expect(saved.status, ItemStatus.reviewed);
      expect(saved.localBytes, isNotNull);
      expect(listEquals(saved.localBytes, photo), isTrue);
    });
  });
}
