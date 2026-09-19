import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/models/item.dart';
import '../data/models/tryon.dart';
import '../data/tryon_repository.dart';
import '../state/tryon_state.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/item_image.dart';
import 'tryon_result_screen.dart';

/// The virtual try-on tab: pick a garment (from your closet, the catalog, or an
/// upload), then a photo of yourself, and see it rendered on you.
class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

enum _Source { closet, catalog, upload }

/// The garment the user has selected, resolved to bytes at try-on time.
class _Selection {
  const _Selection({
    required this.source,
    required this.label,
    this.itemId,
    this.catalogId,
    this.bytes,
    this.imageUrl,
    this.item,
  });
  final _Source source;
  final String label;
  final String? itemId;
  final String? catalogId;
  final Uint8List? bytes; // uploads carry bytes directly
  final String? imageUrl; // catalog / live closet resolve from a URL
  final Item? item; // closet items (for swatch/localBytes preview)
}

class _TryOnScreenState extends State<TryOnScreen> {
  final _picker = ImagePicker();
  _Source _source = _Source.closet;
  _Selection? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WardrobeState>().load();
      final tryOn = context.read<TryOnState>();
      tryOn.loadCatalog();
      tryOn.loadHistory();
    });
  }

  Future<void> _pickUploadGarment() async {
    final f = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 1400);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() => _selected = _Selection(
          source: _Source.upload,
          label: 'Uploaded garment',
          bytes: bytes,
        ));
  }

  /// Resolve the selected garment to bytes (uploads already have them; catalog
  /// and live closet items are fetched from their image URL).
  Future<Uint8List?> _garmentBytes(_Selection sel) async {
    if (sel.bytes != null) return sel.bytes;
    if (sel.item?.localBytes != null) return sel.item!.localBytes;
    final url = sel.imageUrl;
    if (url != null && url.isNotEmpty) {
      try {
        final bd = await NetworkAssetBundle(Uri.parse(url)).load(url);
        return bd.buffer.asUint8List();
      } catch (_) {
        return null;
      }
    }
    return null; // demo swatch with no real photo
  }

  Future<void> _startTryOn() async {
    final sel = _selected;
    if (sel == null) return;

    final consented = await _consentGate();
    if (consented != true || !mounted) return;

    final f = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 88, maxWidth: 1400);
    if (f == null || !mounted) return;
    final personBytes = await f.readAsBytes();

    final garmentBytes = await _garmentBytes(sel) ?? personBytes;
    if (!mounted) return;

    final tryOn = context.read<TryOnState>();
    final source = sel.source == _Source.closet
        ? GarmentSource.closet
        : sel.source == _Source.catalog
            ? GarmentSource.catalog
            : GarmentSource.upload;

    // Kick off the render and show the result screen (it watches progress).
    final future = tryOn.run(
      personBytes: personBytes,
      garmentBytes: garmentBytes,
      source: source,
      garmentItemId: sel.itemId,
      garmentCatalogId: sel.catalogId,
      garmentDescription: sel.label,
    );
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TryOnResultScreen(garmentLabel: sel.label, pending: future),
    ));
  }

  Future<bool?> _consentGate() {
    final t = context.vess;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Use a photo of yourself', style: serif(context, 22)),
        content: Text(
          'Try-on works best with a clear, front-facing full-body photo. '
          'Only use photos of yourself — don\'t upload images of other people '
          'without their consent. Your photo is private to your account.',
          style: TextStyle(fontFamily: kSans, fontSize: 13.5, height: 1.5, color: t.ink2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TextStyle(fontFamily: kSans, color: t.ink3, fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: t.accent),
            child: const Text('I understand'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final tryOn = context.watch<TryOnState>();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Virtual try-on', style: serif(context, 32)),
                const SizedBox(height: 4),
                Text('Preview how a look reads on you — styling, not sizing.',
                    style: TextStyle(fontFamily: kSans, fontSize: 13.5, color: t.ink2)),
              ],
            ),
          ),
          if (tryOn.hasHistory) _HistoryStrip(history: tryOn.history),
          const SizedBox(height: 14),
          // Garment source selector.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _sourceChip('My closet', _Source.closet),
                const SizedBox(width: 8),
                _sourceChip('Catalog', _Source.catalog),
                const SizedBox(width: 8),
                _sourceChip('Upload', _Source.upload),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(child: _sourceBody()),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _sourceChip(String label, _Source s) {
    return VessChip(
      label: label,
      active: _source == s,
      // Switching source clears the prior pick so the CTA reflects the new tab.
      onTap: () => setState(() {
        if (_source != s) {
          _source = s;
          _selected = null;
        }
      }),
    );
  }

  Widget _sourceBody() {
    switch (_source) {
      case _Source.closet:
        return _closetGrid();
      case _Source.catalog:
        return _catalogGrid();
      case _Source.upload:
        return _uploadPane();
    }
  }

  Widget _closetGrid() {
    final wardrobe = context.watch<WardrobeState>();
    final items = wardrobe.items
        .where((i) => (i.category ?? '').toLowerCase() != 'accessories')
        .toList();

    if (wardrobe.loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return _hint('Add pieces to your closet to try them on.');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.72),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final active = _selected?.itemId == item.id;
        return _tappableTile(
          active: active,
          onTap: () => setState(() => _selected = _Selection(
                source: _Source.closet,
                label: item.name,
                itemId: item.id,
                item: item,
                imageUrl: null,
              )),
          child: ItemImage(item: item, radius: 14),
          caption: item.name,
        );
      },
    );
  }

  Widget _catalogGrid() {
    final tryOn = context.watch<TryOnState>();
    if (tryOn.loadingCatalog && tryOn.catalog.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = tryOn.catalog;
    if (items.isEmpty) return _hint('No catalog items yet.');

    final repo = TryOnRepository();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final c = items[i];
        final url = c.imagePath.startsWith('http')
            ? c.imagePath
            : repo.catalogImageUrl(c.imagePath);
        final active = _selected?.catalogId == c.id;
        return _tappableTile(
          active: active,
          onTap: () => setState(() => _selected = _Selection(
                source: _Source.catalog,
                label: c.name,
                catalogId: c.id,
                imageUrl: url,
              )),
          child: _NetImage(url: url, radius: 16),
          caption: c.priceLabel == null ? c.name : '${c.name} · ${c.priceLabel}',
        );
      },
    );
  }

  Widget _uploadPane() {
    final t = context.vess;
    final sel = _selected;
    final hasUpload = sel?.source == _Source.upload && sel?.bytes != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _pickUploadGarment,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: t.sand2,
                  border: Border.all(color: t.line),
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasUpload
                    ? Image.memory(sel!.bytes!, fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 40, color: t.accent),
                          const SizedBox(height: 12),
                          Text('Upload a garment photo',
                              style: TextStyle(
                                  fontFamily: kSans, fontSize: 14.5, fontWeight: FontWeight.w600, color: t.ink)),
                          const SizedBox(height: 4),
                          Text('A flat-lay or on-model shot works best',
                              style: TextStyle(fontFamily: kSans, fontSize: 12.5, color: t.ink3)),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tappableTile({
    required bool active,
    required VoidCallback onTap,
    required Widget child,
    required String caption,
  }) {
    final t = context.vess;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(active ? 16 : 14),
                border: Border.all(
                  color: active ? t.accent : Colors.transparent,
                  width: active ? 2.5 : 0,
                ),
              ),
              child: child,
            ),
          ),
          const SizedBox(height: 6),
          Text(caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? t.accent : t.ink2,
              )),
        ],
      ),
    );
  }

  Widget _hint(String text) {
    final t = context.vess;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: kSans, fontSize: 14, color: t.ink3)),
      ),
    );
  }

  Widget _bottomBar() {
    final t = context.vess;
    final ready = _selected != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 108),
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: AccentButton(
        label: ready ? 'Choose your photo & try on' : 'Select a garment first',
        expand: true,
        trailing: ready ? Icons.camera_alt_outlined : null,
        onTap: ready ? _startTryOn : null,
      ),
    );
  }
}

/// A horizontal strip of past try-on renders, tap to view full-size.
class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip({required this.history});
  final List<TryOn> history;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('YOUR TRY-ONS',
                style: eyebrow(t.ink3, size: 11).copyWith(letterSpacing: 1.2)),
          ),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _HistoryThumb(tryOn: history[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryThumb extends StatelessWidget {
  const _HistoryThumb({required this.tryOn});
  final TryOn tryOn;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return GestureDetector(
      onTap: () => _view(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 68,
          height: 92,
          child: _image(context, fit: BoxFit.cover) ??
              Container(color: t.sand2, child: Icon(Icons.checkroom, color: t.ink3)),
        ),
      ),
    );
  }

  Widget? _image(BuildContext context, {BoxFit fit = BoxFit.cover}) {
    if (tryOn.resultBytes != null) {
      return Image.memory(tryOn.resultBytes!, fit: fit);
    }
    final path = tryOn.resultImagePath;
    if (path != null && path.isNotEmpty) {
      return FutureBuilder<String>(
        future: TryOnRepository().signedUrl(path),
        builder: (context, snap) => snap.hasData
            ? Image.network(snap.data!, fit: fit)
            : const ColoredBox(color: Color(0x11000000)),
      );
    }
    return null;
  }

  void _view(BuildContext context) {
    final img = _image(context, fit: BoxFit.contain);
    if (img == null) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: img,
        ),
      ),
    );
  }
}

/// A network image with a calm placeholder while it loads.
class _NetImage extends StatelessWidget {
  const _NetImage({required this.url, this.radius = 14});
  final String url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        color: t.sand2,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.checkroom, color: t.ink3, size: 32),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
    );
  }
}
