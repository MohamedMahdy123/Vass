import 'dart:typed_data';

/// Where the garment being tried on came from.
enum GarmentSource { closet, upload, catalog }

/// Lifecycle of a try-on request.
enum TryOnStatus { pending, processing, succeeded, failed }

/// One virtual try-on — a person photo + a garment, and (once rendered) the
/// result image. Mirrors `public.tryons`.
class TryOn {
  const TryOn({
    this.id,
    required this.garmentSource,
    this.personImagePath,
    this.garmentItemId,
    this.garmentCatalogId,
    this.garmentImagePath,
    this.resultImagePath,
    this.status = TryOnStatus.pending,
    this.model,
    this.error,
    this.createdAt,
    this.personBytes,
    this.resultBytes,
  });

  final String? id;
  final GarmentSource garmentSource;
  final String? personImagePath;
  final String? garmentItemId;
  final String? garmentCatalogId;
  final String? garmentImagePath;
  final String? resultImagePath;
  final TryOnStatus status;
  final String? model;
  final String? error;
  final DateTime? createdAt;

  /// Just-captured / just-rendered bytes held in memory for instant preview
  /// (and for demo mode, which has no storage). Never persisted.
  final Uint8List? personBytes;
  final Uint8List? resultBytes;

  bool get isDone => status == TryOnStatus.succeeded;

  TryOn copyWith({
    String? id,
    String? personImagePath,
    String? resultImagePath,
    TryOnStatus? status,
    String? model,
    String? error,
    Uint8List? personBytes,
    Uint8List? resultBytes,
  }) {
    return TryOn(
      id: id ?? this.id,
      garmentSource: garmentSource,
      personImagePath: personImagePath ?? this.personImagePath,
      garmentItemId: garmentItemId,
      garmentCatalogId: garmentCatalogId,
      garmentImagePath: garmentImagePath,
      resultImagePath: resultImagePath ?? this.resultImagePath,
      status: status ?? this.status,
      model: model ?? this.model,
      error: error ?? this.error,
      createdAt: createdAt,
      personBytes: personBytes ?? this.personBytes,
      resultBytes: resultBytes ?? this.resultBytes,
    );
  }

  factory TryOn.fromMap(Map<String, dynamic> m) {
    return TryOn(
      id: m['id'] as String?,
      garmentSource: GarmentSource.values.firstWhere(
        (s) => s.name == m['garment_source'],
        orElse: () => GarmentSource.upload,
      ),
      personImagePath: m['person_image_path'] as String?,
      garmentItemId: m['garment_item_id'] as String?,
      garmentCatalogId: m['garment_catalog_id'] as String?,
      garmentImagePath: m['garment_image_path'] as String?,
      resultImagePath: m['result_image_path'] as String?,
      status: TryOnStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => TryOnStatus.pending,
      ),
      model: m['model'] as String?,
      error: m['error'] as String?,
      createdAt: m['created_at'] == null
          ? null
          : DateTime.parse(m['created_at'] as String),
    );
  }

  /// Columns the client writes to `tryons`. user_id is set server-side.
  Map<String, dynamic> toInsert() => {
        'garment_source': garmentSource.name,
        'person_image_path': personImagePath,
        'garment_item_id': garmentItemId,
        'garment_catalog_id': garmentCatalogId,
        'garment_image_path': garmentImagePath,
        'status': status.name,
        'model': model,
      };
}
