/// A real catalog product photo pulled from a free demo API (FakeStore /
/// DummyJSON), already mapped to the app's own category vocabulary. Used to
/// dress the demo wardrobe with genuine clothing photos.
class CatalogPhoto {
  const CatalogPhoto({required this.category, required this.imageUrl, this.title = ''});

  /// One of the app's categories: Tops / Outerwear / Footwear / Dresses /
  /// Accessories (Bottoms is unmapped — no free source covers trousers).
  final String category;
  final String imageUrl;
  final String title;
}
