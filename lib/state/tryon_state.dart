import 'package:flutter/foundation.dart';

import '../core/supabase_service.dart';
import '../data/models/catalog_item.dart';
import '../data/models/tryon.dart';
import '../data/tryon_repository.dart';
import '../services/tryon_service.dart';

/// Drives the virtual try-on feature: browsing the catalog, running a render
/// (person photo + garment), and holding the result. Backed by Supabase when
/// configured; otherwise a walkable in-memory demo.
class TryOnState extends ChangeNotifier {
  final _repo = TryOnRepository();
  final _service = TryOnService();

  List<CatalogItem> _catalog = const [];
  bool _loadingCatalog = false;
  bool _running = false;
  String? _error;
  TryOn? _result;

  List<CatalogItem> get catalog => List.unmodifiable(_catalog);
  bool get loadingCatalog => _loadingCatalog;
  bool get running => _running;
  String? get error => _error;
  TryOn? get result => _result;
  bool get hasResult => _result != null && _result!.isDone;

  bool get isLive =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  Future<void> loadCatalog() async {
    if (_loadingCatalog) return;
    _loadingCatalog = true;
    notifyListeners();
    try {
      _catalog = isLive ? await _repo.fetchCatalog() : _demoCatalog();
    } catch (_) {
      _catalog = _demoCatalog();
      _error = 'Could not load the catalog.';
    } finally {
      _loadingCatalog = false;
      notifyListeners();
    }
  }

  void clearResult() {
    _result = null;
    _error = null;
    notifyListeners();
  }

  /// Run a try-on. [personBytes] is a photo of the user; [garmentBytes] is the
  /// chosen garment (from their closet, an upload, or the catalog). The source
  /// ids let us record provenance when persisting.
  Future<void> run({
    required Uint8List personBytes,
    required Uint8List garmentBytes,
    required GarmentSource source,
    String? garmentItemId,
    String? garmentCatalogId,
    String category = 'auto',
  }) async {
    if (_running) return;
    _running = true;
    _error = null;
    _result = null;
    notifyListeners();

    try {
      final rendered = await _service.run(
        personBytes: personBytes,
        garmentBytes: garmentBytes,
        category: category,
      );

      var tryOn = TryOn(
        garmentSource: source,
        garmentItemId: garmentItemId,
        garmentCatalogId: garmentCatalogId,
        status: TryOnStatus.succeeded,
        model: rendered.model,
        personBytes: personBytes,
        resultBytes: rendered.bytes,
      );

      if (isLive) {
        // Persist the request + images so the user has a history.
        try {
          final created = await _repo.create(
            TryOn(garmentSource: source, garmentItemId: garmentItemId,
                garmentCatalogId: garmentCatalogId, status: TryOnStatus.processing,
                model: rendered.model),
          );
          final personPath = await _repo.uploadBody(created.id!, personBytes);
          final resultPath = await _repo.uploadResult(created.id!, rendered.bytes);
          await _repo.update(created.id!, {
            'person_image_path': personPath,
            'result_image_path': resultPath,
            'status': TryOnStatus.succeeded.name,
          });
          tryOn = tryOn.copyWith(
            id: created.id,
            personImagePath: personPath,
            resultImagePath: resultPath,
          );
        } catch (_) {
          // Keep the in-memory result even if the sync fails.
          _error = "Rendered, but couldn't save to your history.";
        }
      }

      _result = tryOn;
    } catch (_) {
      _error = "Try-on didn't work this time. Please try again.";
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  /// A small demo catalog so the browse → try-on flow works without a backend.
  List<CatalogItem> _demoCatalog() => const [
        CatalogItem(id: 'cat-1', name: 'Relaxed Linen Shirt', brand: 'Vess Studio', category: 'Tops', color: 'Bone', priceCents: 8900, imagePath: 'https://picsum.photos/seed/vess-shirt/600/800'),
        CatalogItem(id: 'cat-2', name: 'Wide-Leg Trousers', brand: 'Vess Studio', category: 'Bottoms', color: 'Charcoal', priceCents: 12900, imagePath: 'https://picsum.photos/seed/vess-trouser/600/800'),
        CatalogItem(id: 'cat-3', name: 'Cropped Blazer', brand: 'Vess Studio', category: 'Outerwear', color: 'Camel', priceCents: 18900, imagePath: 'https://picsum.photos/seed/vess-blazer/600/800'),
        CatalogItem(id: 'cat-4', name: 'Slip Dress', brand: 'Vess Studio', category: 'Dresses', color: 'Sage', priceCents: 14900, imagePath: 'https://picsum.photos/seed/vess-dress/600/800'),
        CatalogItem(id: 'cat-5', name: 'Knit Polo', brand: 'Vess Studio', category: 'Tops', color: 'Ash', priceCents: 9900, imagePath: 'https://picsum.photos/seed/vess-polo/600/800'),
        CatalogItem(id: 'cat-6', name: 'Pleated Skirt', brand: 'Vess Studio', category: 'Bottoms', color: 'Ivory', priceCents: 11900, imagePath: 'https://picsum.photos/seed/vess-skirt/600/800'),
      ];
}
