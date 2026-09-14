/// A platform-provided garment from `public.catalog_items` — something the user
/// can try on without owning it (the "try before you buy" path). Distinct from
/// [Item] (the user's own wardrobe) and [ClosetItem] (the demo prototype).
class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.imagePath,
    this.brand,
    this.category,
    this.color,
    this.priceCents,
    this.currency = 'USD',
  });

  final String id;
  final String name;

  /// Path in the public `catalog` storage bucket (or a full URL in demo mode).
  final String imagePath;
  final String? brand;
  final String? category;
  final String? color;
  final int? priceCents;
  final String currency;

  String? get priceLabel {
    if (priceCents == null) return null;
    final v = (priceCents! / 100).toStringAsFixed(0);
    final symbol = currency == 'USD' ? '\$' : '$currency ';
    return '$symbol$v';
  }

  factory CatalogItem.fromMap(Map<String, dynamic> m) {
    return CatalogItem(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? 'Untitled',
      imagePath: (m['image_path'] as String?) ?? '',
      brand: m['brand'] as String?,
      category: m['category'] as String?,
      color: m['color'] as String?,
      priceCents: m['price_cents'] as int?,
      currency: (m['currency'] as String?) ?? 'USD',
    );
  }
}
