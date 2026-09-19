import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;

import 'bg_remover.dart';

BgRemover createBgRemover() => _NativeBgRemover();

/// On-device background removal.
///
/// - Android: Google ML Kit **Subject Segmentation** returns a full-size
///   transparent foreground PNG.
/// - iOS: the `vess/bg_removal` method channel runs Apple's **Vision** subject
///   lifting (VNGenerateForegroundInstanceMaskRequest, iOS 17+) and returns the
///   same shape.
///
/// The foreground PNG is then tight-cropped to the subject's alpha bounding box
/// with a 10% margin, off the UI isolate. Everything is best-effort: any failure
/// yields an `attempted` outcome with no cut-out so the caller keeps the photo.
class _NativeBgRemover implements BgRemover {
  static const _iosChannel = MethodChannel('vess/bg_removal');

  @override
  Future<BgRemovalOutcome> remove(Uint8List bytes) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return BgRemovalOutcome.unsupported;
    }
    try {
      final foreground = Platform.isAndroid
          ? await _segmentAndroid(bytes)
          : await _segmentIOS(bytes);
      if (foreground == null) {
        debugPrint('[bg_removal] segmenter returned no foreground subject');
        return const BgRemovalOutcome(
            attempted: true, error: 'No clear subject found in the photo');
      }
      // Tight-crop in a background isolate to keep the UI smooth.
      final cropped = await compute(cropToSubject, foreground);
      return BgRemovalOutcome(cutout: cropped ?? foreground, attempted: true);
    } catch (e) {
      // Surface the real reason — most often the ML Kit model is still
      // downloading via Play services, or Play services is unavailable.
      debugPrint('[bg_removal] failed: $e');
      return BgRemovalOutcome(attempted: true, error: e.toString());
    }
  }

  Future<Uint8List?> _segmentAndroid(Uint8List bytes) async {
    // ML Kit's InputImage wants a file path; stage the bytes in a temp file.
    final tmp = File(
      '${Directory.systemTemp.path}/vess_seg_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await tmp.writeAsBytes(bytes, flush: true);
    final segmenter = SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundBitmap: true,
        enableForegroundConfidenceMask: false,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: false,
        ),
      ),
    );
    try {
      final result =
          await segmenter.processImage(InputImage.fromFilePath(tmp.path));
      return result.foregroundBitmap;
    } finally {
      await segmenter.close();
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {/* temp cleanup is best-effort */}
      }
    }
  }

  Future<Uint8List?> _segmentIOS(Uint8List bytes) =>
      _iosChannel.invokeMethod<Uint8List>('removeBackground', {'image': bytes});
}

/// Tight-crop a transparent cut-out to its subject's alpha bounding box, with a
/// 10% padding margin. Top-level so it can run in a `compute` isolate. Returns
/// null if the image can't be decoded or is fully transparent.
Uint8List? cropToSubject(Uint8List png) {
  final image = img.decodePng(png);
  if (image == null) return null;

  const alphaThreshold = 12; // ignore near-transparent matting fringe
  // Sub-sample large images when finding the box — the crop itself stays full-res.
  final step = (image.width > 900 || image.height > 900) ? 2 : 1;
  var minX = image.width, minY = image.height, maxX = -1, maxY = -1;
  for (var y = 0; y < image.height; y += step) {
    for (var x = 0; x < image.width; x += step) {
      if (image.getPixel(x, y).a > alphaThreshold) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return null; // nothing opaque → treat as a failure

  final boxW = maxX - minX + 1, boxH = maxY - minY + 1;
  final padX = (boxW * 0.10).round(), padY = (boxH * 0.10).round();
  final x0 = (minX - padX).clamp(0, image.width - 1);
  final y0 = (minY - padY).clamp(0, image.height - 1);
  final x1 = (maxX + padX).clamp(0, image.width - 1);
  final y1 = (maxY + padY).clamp(0, image.height - 1);

  final cropped = img.copyCrop(
    image,
    x: x0,
    y: y0,
    width: x1 - x0 + 1,
    height: y1 - y0 + 1,
  );
  return img.encodePng(cropped);
}
