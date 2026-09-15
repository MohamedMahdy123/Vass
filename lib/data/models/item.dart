import 'dart:typed_data';

/// Lifecycle of a captured garment: awaiting AI tagging → tagged (unreviewed)
/// → reviewed (user-confirmed).
enum ItemStatus { pending, tagged, reviewed }

/// A single user-uploaded garment — the core of the digital wardrobe. Every
/// item is User-Generated Content: the user photographs a piece, the app
/// removes the background and the AI tags it, and it's stored per-user
/// (`public.items`, Row-Level-Security scoped).
///
/// The model is intentionally rich to drive the AI stylist, weather matching
/// and outfit assembly: multi-value [occasions] / [seasons] / [weatherTags],
/// a primary+secondary colour, and sub-category + fabric.
///
/// Legacy single-value fields (`color`, `occasion`, `season`, `material`) are
/// kept for backward compatibility and are always populated (from the rich
/// fields when a piece was tagged with the newer schema), so older call sites
/// keep working. New code should read the list-valued getters.
class ClothingItem {
  const ClothingItem({
    required this.id,
    required this.name,
    this.userId,
    this.imagePath,
    this.processedImageUrl,
    this.category,
    this.subCategory,
    this.occasions = const [],
    this.seasons = const [],
    this.weatherTags = const [],
    this.colorPrimary,
    this.colorSecondary,
    this.fabricType,
    this.pattern,
    this.brand,
    this.favorite = false,
    this.wearCount = 0,
    this.lastWornAt,
    this.status = ItemStatus.pending,
    this.localBytes,
    // ---- legacy single-value compatibility (deprecated) ----
    this.color,
    this.occasion,
    this.season,
    this.material,
  });

  final String id;
  final String? userId;
  final String name;

  /// Original uploaded photo (storage path in the `wardrobe` bucket, or a full
  /// URL for demo/seed data). Exposed as [imageUrl] under the API name.
  final String? imagePath;

  /// Background-removed (transparent) version of the photo, when processed.
  final String? processedImageUrl;

  final String? category;
  final String? subCategory;

  /// When the piece is appropriate — e.g. Casual, Work, Formal, Party.
  final List<String> occasions;

  /// Seasons the piece suits — e.g. Spring, Summer, Autumn, Winter, All.
  final List<String> seasons;

  /// Weather suitability — e.g. Hot, Warm, Cold, Rain, plus a temp range.
  final List<String> weatherTags;

  final String? colorPrimary;
  final String? colorSecondary;
  final String? fabricType;
  final String? pattern;
  final String? brand;
  final bool favorite;
  final int wearCount;
  final DateTime? lastWornAt;
  final ItemStatus status;

  /// Just-captured bytes held in memory for instant preview (and demo mode).
  /// Never persisted.
  final Uint8List? localBytes;

  // ---- legacy single-value fields (kept populated for old call sites) ----
  final String? color;
  final String? occasion;
  final String? season;
  final String? material;

  // ---- unified accessors (prefer rich, fall back to legacy) ---------------
  String? get imageUrl => imagePath;
  String? get primaryColor => colorPrimary ?? color;
  String? get secondaryColor => colorSecondary;
  String? get fabric => fabricType ?? material;

  List<String> get occasionTags => occasions.isNotEmpty
      ? occasions
      : (occasion != null && occasion!.isNotEmpty ? [occasion!] : const []);
  List<String> get seasonTags => seasons.isNotEmpty
      ? seasons
      : (season != null && season!.isNotEmpty ? [season!] : const []);

  ClothingItem copyWith({
    String? name,
    String? userId,
    String? imagePath,
    String? processedImageUrl,
    String? category,
    String? subCategory,
    List<String>? occasions,
    List<String>? seasons,
    List<String>? weatherTags,
    String? colorPrimary,
    String? colorSecondary,
    String? fabricType,
    String? pattern,
    String? brand,
    bool? favorite,
    int? wearCount,
    DateTime? lastWornAt,
    ItemStatus? status,
    Uint8List? localBytes,
    // legacy
    String? color,
    String? occasion,
    String? season,
    String? material,
  }) {
    return ClothingItem(
      id: id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      processedImageUrl: processedImageUrl ?? this.processedImageUrl,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      occasions: occasions ?? this.occasions,
      seasons: seasons ?? this.seasons,
      weatherTags: weatherTags ?? this.weatherTags,
      colorPrimary: colorPrimary ?? this.colorPrimary,
      colorSecondary: colorSecondary ?? this.colorSecondary,
      fabricType: fabricType ?? this.fabricType,
      pattern: pattern ?? this.pattern,
      brand: brand ?? this.brand,
      favorite: favorite ?? this.favorite,
      wearCount: wearCount ?? this.wearCount,
      lastWornAt: lastWornAt ?? this.lastWornAt,
      status: status ?? this.status,
      localBytes: localBytes ?? this.localBytes,
      color: color ?? this.color,
      occasion: occasion ?? this.occasion,
      season: season ?? this.season,
      material: material ?? this.material,
    );
  }

  static List<String> _strList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String && v.trim().isNotEmpty) return [v];
    return const [];
  }

  /// Build from a Supabase row (snake_case). Reads the rich columns and falls
  /// back to the legacy single-value columns for older rows; also back-fills
  /// the legacy fields so every accessor resolves.
  factory ClothingItem.fromJson(Map<String, dynamic> j) {
    final occasions = _strList(j['occasions']);
    final seasons = _strList(j['seasons']);
    final colorPrimary = j['color_primary'] as String? ?? j['color'] as String?;
    final fabric = j['fabric_type'] as String? ?? j['material'] as String?;
    return ClothingItem(
      id: j['id'] as String,
      userId: j['user_id'] as String?,
      name: (j['name'] as String?) ?? 'Untitled',
      imagePath: (j['image_url'] ?? j['image_path']) as String?,
      processedImageUrl: j['processed_image_url'] as String?,
      category: j['category'] as String?,
      subCategory: j['sub_category'] as String?,
      occasions: occasions,
      seasons: seasons,
      weatherTags: _strList(j['weather_tags']),
      colorPrimary: colorPrimary,
      colorSecondary: j['color_secondary'] as String?,
      fabricType: fabric,
      pattern: j['pattern'] as String?,
      brand: j['brand'] as String?,
      favorite: (j['favorite'] as bool?) ?? false,
      wearCount: (j['wear_count'] as int?) ?? 0,
      lastWornAt: j['last_worn_at'] == null
          ? null
          : DateTime.parse(j['last_worn_at'] as String),
      status: ItemStatus.values.firstWhere(
        (s) => s.name == j['status'],
        orElse: () => ItemStatus.pending,
      ),
      // keep legacy fields resolving
      color: colorPrimary,
      material: fabric,
      occasion: occasions.isNotEmpty ? occasions.first : j['occasion'] as String?,
      season: seasons.isNotEmpty ? seasons.first : j['season'] as String?,
    );
  }

  /// Full serialization (snake_case, matching the schema). `user_id` is set
  /// server-side via RLS and omitted here.
  Map<String, dynamic> toJson() => {
        'name': name,
        'image_url': imagePath,
        'processed_image_url': processedImageUrl,
        'category': category,
        'sub_category': subCategory,
        'occasions': occasionTags,
        'seasons': seasonTags,
        'weather_tags': weatherTags,
        'color_primary': primaryColor,
        'color_secondary': colorSecondary,
        'fabric_type': fabric,
        'pattern': pattern,
        'brand': brand,
        'favorite': favorite,
        'wear_count': wearCount,
        'status': status.name,
        // legacy mirrors so downstream single-value readers keep working
        'color': primaryColor,
        'occasion': occasionTags.isNotEmpty ? occasionTags.first : null,
        'season': seasonTags.isNotEmpty ? seasonTags.first : null,
        'material': fabric,
      };

  // ---- backward-compatible aliases used by existing data access ----------
  factory ClothingItem.fromMap(Map<String, dynamic> m) => ClothingItem.fromJson(m);

  /// Columns the client is allowed to write (user_id is server-set). Writes the
  /// rich columns and the legacy mirrors. `image_path` is kept as the stored
  /// column name for the original photo.
  Map<String, dynamic> toInsert() => {
        'name': name,
        'image_path': imagePath,
        'processed_image_url': processedImageUrl,
        'category': category,
        'sub_category': subCategory,
        'occasions': occasionTags,
        'seasons': seasonTags,
        'weather_tags': weatherTags,
        'color_primary': primaryColor,
        'color_secondary': colorSecondary,
        'fabric_type': fabric,
        'pattern': pattern,
        'brand': brand,
        'favorite': favorite,
        'status': status.name,
        // legacy mirror columns
        'color': primaryColor,
        'occasion': occasionTags.isNotEmpty ? occasionTags.first : null,
        'season': seasonTags.isNotEmpty ? seasonTags.first : null,
        'material': fabric,
      };
}

/// Transitional alias — the wardrobe's garment type is now [ClothingItem].
/// Existing references to `Item` continue to resolve unchanged.
typedef Item = ClothingItem;
