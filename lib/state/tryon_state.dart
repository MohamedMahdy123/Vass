import 'package:flutter/foundation.dart';

import '../core/supabase_service.dart';
import '../data/models/catalog_item.dart';
import '../data/models/tryon.dart';
import '../data/tryon_repository.dart';
import '../services/tryon_service.dart';
export '../services/tryon_service.dart' show TryOnQuotaException;

/// Drives the virtual try-on feature: browsing the catalog, running a render
/// (person photo + garment), and holding the result. Backed by Supabase when
/// configured; otherwise a walkable in-memory demo.
class TryOnState extends ChangeNotifier {
  TryOnState({TryOnService? service}) : _service = service ?? TryOnService();

  final _repo = TryOnRepository();
  final TryOnService _service;

  List<CatalogItem> _catalog = const [];
  List<TryOn> _history = [];
  bool _loadingCatalog = false;
  bool _running = false;
  bool _quotaReached = false;
  String? _error;
  TryOn? _result;

  List<CatalogItem> get catalog => List.unmodifiable(_catalog);
  List<TryOn> get history => List.unmodifiable(_history);
  bool get loadingCatalog => _loadingCatalog;
  bool get running => _running;

  /// True once the monthly free try-on limit has been hit this session.
  bool get quotaReached => _quotaReached;
  String? get error => _error;
  TryOn? get result => _result;
  bool get hasResult => _result != null && _result!.isDone;
  bool get hasHistory => _history.isNotEmpty;

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

  /// Load past try-ons for the history view. Live reads from Postgres; demo
  /// keeps whatever was rendered this session in memory.
  Future<void> loadHistory() async {
    if (!isLive) return; // demo history is already in memory
    try {
      _history = await _repo.history();
      notifyListeners();
    } catch (_) {/* non-fatal */}
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
    String? garmentDescription,
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
        garmentDescription: garmentDescription,
      );
      _quotaReached = false;

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
      _history.insert(0, tryOn); // newest first, for the history view
    } on TryOnQuotaException catch (e) {
      _quotaReached = true;
      _error = e.limit != null
          ? "You've used all ${e.limit} free try-ons this month."
          : "You've reached your monthly free try-on limit.";
    } catch (_) {
      _error = "Try-on didn't work this time. Please try again.";
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  /// A small demo catalog of real garment photos so the browse → try-on flow is
  /// walkable without a backend. (Live, these come from the `catalog` bucket.)
  static const _px = '?auto=compress&cs=tinysrgb&w=600';
  List<CatalogItem> _demoCatalog() => const [
        CatalogItem(id: 'cat-1', name: 'Blue Striped Shirt', brand: 'Vess Studio', category: 'Tops', color: 'Blue', priceCents: 6900, imagePath: 'https://images.pexels.com/photos/4428388/pexels-photo-4428388.jpeg$_px'),
        CatalogItem(id: 'cat-2', name: 'Teal Knit Sweater', brand: 'Vess Studio', category: 'Tops', color: 'Teal', priceCents: 8900, imagePath: 'https://images.pexels.com/photos/8159428/pexels-photo-8159428.jpeg$_px'),
        CatalogItem(id: 'cat-3', name: 'Chunky Knit Cardigan', brand: 'Vess Studio', category: 'Outerwear', color: 'Cream', priceCents: 14900, imagePath: 'https://images.pexels.com/photos/4374510/pexels-photo-4374510.jpeg$_px'),
        CatalogItem(id: 'cat-4', name: 'Linen Shorts', brand: 'Vess Studio', category: 'Bottoms', color: 'Blush', priceCents: 5900, imagePath: 'https://images.pexels.com/photos/5405644/pexels-photo-5405644.jpeg$_px'),
        CatalogItem(id: 'cat-5', name: 'Canvas Sneakers', brand: 'Vess Studio', category: 'Footwear', color: 'Red', priceCents: 7900, imagePath: 'https://images.pexels.com/photos/3944692/pexels-photo-3944692.jpeg$_px'),
        CatalogItem(id: 'cat-6', name: 'High-Top Sneakers', brand: 'Vess Studio', category: 'Footwear', color: 'Olive', priceCents: 8500, imagePath: 'https://images.pexels.com/photos/934069/pexels-photo-934069.jpeg$_px'),
      ];
}
