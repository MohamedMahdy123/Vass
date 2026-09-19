import 'dart:typed_data';

import 'bg_removal/bg_remover.dart';

export 'bg_removal/bg_remover.dart' show BgRemovalOutcome;

/// On-device background removal for garment photos.
///
/// 100% local — Google ML Kit **Subject Segmentation** on Android and Apple
/// **Vision** subject lifting on iOS (see [BgRemover]). Zero API cost, works
/// offline, and photos never leave the device. Produces a transparent PNG
/// cropped tightly to the item with a 10% margin.
///
/// Best-effort by contract: if no clear foreground is found (or the platform has
/// no model, e.g. web), the returned [BgRemovalOutcome] carries no cut-out and
/// the caller keeps the original photo — removal is an enhancement, never a gate
/// on saving a wardrobe item.
class BackgroundRemovalService {
  BackgroundRemovalService({BgRemover? remover})
      : _remover = remover ?? makeBgRemover();

  final BgRemover _remover;

  Future<BgRemovalOutcome> remove(Uint8List bytes) => _remover.remove(bytes);
}
