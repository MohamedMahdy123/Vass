import 'dart:typed_data';

/// A garment as stored in Postgres (`public.items`). This is the real data
/// model — distinct from the prototype's [ClosetItem], which carries gradient
/// swatch colors instead of a photo.
enum ItemStatus { pending, tagged, reviewed }

class Item {
  const Item({
    required this.id,
    required this.name,
    this.imagePath,
    this.category,
    this.color,
    this.material,
    this.pattern,
    this.season,
    this.occasion,
    this.brand,
    this.favorite = false,
    this.wearCount = 0,
    this.lastWornAt,
    this.status = ItemStatus.pending,
    this.localBytes,
  });

  final String id;
  final String name;
  final String? imagePath;
  final String? category;
  final String? color;
  final String? material;
  final String? pattern;
  final String? season;
  final String? occasion;
  final String? brand;
  final bool favorite;
  final int wearCount;
  final DateTime? lastWornAt;
  final ItemStatus status;

  /// Just-captured photo bytes, held in memory for instant preview before the
  /// upload completes (and for demo mode, which has no storage). Never persisted.
  final Uint8List? localBytes;

  Item copyWith({
    String? name,
    String? imagePath,
    String? category,
    String? color,
    String? material,
    String? pattern,
    String? season,
    String? occasion,
    String? brand,
    bool? favorite,
    int? wearCount,
    DateTime? lastWornAt,
    Uint8List? localBytes,
    ItemStatus? status,
  }) {
    return Item(
      id: id,
      imagePath: imagePath ?? this.imagePath,
      name: name ?? this.name,
      category: category ?? this.category,
      color: color ?? this.color,
      material: material ?? this.material,
      pattern: pattern ?? this.pattern,
      season: season ?? this.season,
      occasion: occasion ?? this.occasion,
      brand: brand ?? this.brand,
      favorite: favorite ?? this.favorite,
      wearCount: wearCount ?? this.wearCount,
      lastWornAt: lastWornAt ?? this.lastWornAt,
      status: status ?? this.status,
      localBytes: localBytes ?? this.localBytes,
    );
  }

  factory Item.fromMap(Map<String, dynamic> m) {
    return Item(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? 'Untitled',
      imagePath: m['image_path'] as String?,
      category: m['category'] as String?,
      color: m['color'] as String?,
      material: m['material'] as String?,
      pattern: m['pattern'] as String?,
      season: m['season'] as String?,
      occasion: m['occasion'] as String?,
      brand: m['brand'] as String?,
      favorite: (m['favorite'] as bool?) ?? false,
      wearCount: (m['wear_count'] as int?) ?? 0,
      lastWornAt: m['last_worn_at'] == null
          ? null
          : DateTime.parse(m['last_worn_at'] as String),
      status: ItemStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => ItemStatus.pending,
      ),
    );
  }

  /// Columns the client is allowed to write (user_id is set server-side via the
  /// authenticated session / RLS). Nulls are included so edits can clear fields.
  Map<String, dynamic> toInsert() => {
        'name': name,
        'image_path': imagePath,
        'category': category,
        'color': color,
        'material': material,
        'pattern': pattern,
        'season': season,
        'occasion': occasion,
        'brand': brand,
        'favorite': favorite,
        'status': status.name,
      };
}
