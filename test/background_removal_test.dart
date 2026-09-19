import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vess/services/background_removal_service.dart';
import 'package:vess/services/bg_removal/bg_remover.dart';
import 'package:vess/services/bg_removal/bg_remover_io.dart';

/// A stand-in segmenter so we can test the service contract without a device.
class _FakeRemover implements BgRemover {
  _FakeRemover(this.outcome);
  final BgRemovalOutcome outcome;
  @override
  Future<BgRemovalOutcome> remove(Uint8List bytes) async => outcome;
}

void main() {
  group('BackgroundRemovalService — delegates to the on-device remover', () {
    final bytes = Uint8List.fromList(const [1, 2, 3, 4]);

    test('passes through a produced cut-out', () async {
      final cut = Uint8List.fromList(const [9, 9, 9]);
      final svc = BackgroundRemovalService(
        remover: _FakeRemover(BgRemovalOutcome(cutout: cut, attempted: true)),
      );
      final out = await svc.remove(bytes);
      expect(out.cutout, cut);
      expect(out.failed, isFalse);
    });

    test('reports failure when nothing usable is produced', () async {
      final svc = BackgroundRemovalService(
        remover: _FakeRemover(const BgRemovalOutcome(attempted: true)),
      );
      final out = await svc.remove(bytes);
      expect(out.cutout, isNull);
      expect(out.failed, isTrue); // caller keeps the original + can toast
    });

    test('unsupported platform is quiet (not a failure)', () async {
      final svc = BackgroundRemovalService(
        remover: _FakeRemover(BgRemovalOutcome.unsupported),
      );
      final out = await svc.remove(bytes);
      expect(out.cutout, isNull);
      expect(out.failed, isFalse);
      expect(out.attempted, isFalse);
    });
  });

  group('cropToSubject — tight crop with 10% padding', () {
    test('crops a transparent image to its opaque subject + margin', () {
      // 100x100 transparent canvas with a 21x21 opaque square at (40,40)-(60,60).
      final image = img.Image(width: 100, height: 100, numChannels: 4);
      img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
      img.fillRect(image,
          x1: 40, y1: 40, x2: 60, y2: 60, color: img.ColorRgba8(200, 30, 30, 255));

      final cropped = cropToSubject(img.encodePng(image));
      expect(cropped, isNotNull);

      final out = img.decodePng(cropped!)!;
      // box = 21px; padding = round(21*0.10)=2 each side → 21 + 4 = 25.
      expect(out.width, 25);
      expect(out.height, 25);
    });

    test('returns null for a fully transparent image', () {
      final image = img.Image(width: 40, height: 40, numChannels: 4);
      img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
      expect(cropToSubject(img.encodePng(image)), isNull);
    });

    test('padding clamps at the image edge (no out-of-bounds)', () {
      // Opaque block flush against the top-left corner: padding can't go < 0.
      final image = img.Image(width: 80, height: 80, numChannels: 4);
      img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
      img.fillRect(image,
          x1: 0, y1: 0, x2: 19, y2: 19, color: img.ColorRgba8(10, 120, 200, 255));

      final out = img.decodePng(cropToSubject(img.encodePng(image))!)!;
      // box = 20px; pad = round(20*0.10)=2, but left/top clamp to 0 → 20 + 2.
      expect(out.width, 22);
      expect(out.height, 22);
    });

    test('bounding box spans multiple opaque regions', () {
      // Two blobs — the crop must cover both, not just one.
      final image = img.Image(width: 100, height: 100, numChannels: 4);
      img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
      img.fillRect(image,
          x1: 10, y1: 10, x2: 20, y2: 20, color: img.ColorRgba8(255, 0, 0, 255));
      img.fillRect(image,
          x1: 70, y1: 60, x2: 80, y2: 80, color: img.ColorRgba8(0, 255, 0, 255));

      final out = img.decodePng(cropToSubject(img.encodePng(image))!)!;
      // bbox x:10..80 (71), y:10..80 (71); pad round(71*.1)=7 each side, clamped.
      // x: 3..87 → 85 wide;  y: 3..87 → 85 tall.
      expect(out.width, 85);
      expect(out.height, 85);
    });

    test('ignores a near-transparent matting fringe (alpha <= 12)', () {
      // A faint fringe (alpha 8) should NOT expand the box; only the solid
      // subject (alpha 255) counts.
      final image = img.Image(width: 60, height: 60, numChannels: 4);
      img.fill(image, color: img.ColorRgba8(0, 0, 0, 8)); // whole-canvas haze
      img.fillRect(image,
          x1: 25, y1: 25, x2: 34, y2: 34, color: img.ColorRgba8(200, 200, 200, 255));

      final out = img.decodePng(cropToSubject(img.encodePng(image))!)!;
      // box = 10px; pad = round(10*.1)=1 → 12. If the haze counted, it'd be ~60.
      expect(out.width, 12);
      expect(out.height, 12);
    });
  });
}
