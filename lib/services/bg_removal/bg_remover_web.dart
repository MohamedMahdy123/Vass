import 'dart:typed_data';

import 'bg_remover.dart';

BgRemover createBgRemover() => _WebBgRemover();

/// Web / desktop has no on-device segmentation model, so removal is a no-op and
/// the original photo is kept. (Returns `unsupported`, not `failed`, so the UI
/// stays quiet rather than showing a "couldn't isolate" message.)
class _WebBgRemover implements BgRemover {
  @override
  Future<BgRemovalOutcome> remove(Uint8List bytes) async =>
      BgRemovalOutcome.unsupported;
}
