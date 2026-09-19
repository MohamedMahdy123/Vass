import 'dart:typed_data';

import 'bg_remover_web.dart'
    if (dart.library.io) 'bg_remover_io.dart' as impl;

/// The result of an on-device background-removal attempt.
class BgRemovalOutcome {
  const BgRemovalOutcome({this.cutout, this.attempted = false});

  /// The cropped, transparent PNG cut-out — or null if none was produced.
  final Uint8List? cutout;

  /// True when segmentation was actually attempted on this platform
  /// (Android / iOS). False on web or desktop, where no on-device model exists.
  final bool attempted;

  /// Attempted but produced nothing usable (no clear foreground). The caller
  /// should keep the original photo and may tell the user.
  bool get failed => attempted && cutout == null;

  /// Platform can't segment at all — silently keep the original, no message.
  static const unsupported = BgRemovalOutcome();
}

/// On-device foreground / subject segmentation for garment photos.
///
/// The concrete backend is chosen at compile time via a conditional import:
/// a real ML Kit + Apple Vision implementation on mobile (dart:io), and a
/// no-op on web — so the web build never imports the native plugin and stays
/// buildable (same pattern as the reminder scheduler).
abstract class BgRemover {
  Future<BgRemovalOutcome> remove(Uint8List bytes);
}

BgRemover makeBgRemover() => impl.createBgRemover();
