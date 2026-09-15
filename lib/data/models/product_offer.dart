/// A shoppable product for a detected gap. In demo mode these are plausible
/// mock offers; live, they come from an affiliate provider (Skimlinks /
/// ShopStyle) with real deep links carrying the tracking sub-id.
class ProductOffer {
  const ProductOffer({
    required this.title,
    required this.brand,
    required this.retailer,
    required this.url,
    required this.priceCents,
    this.imageUrl,
    this.isMock = false,
  });

  final String title;
  final String brand;
  final String retailer;

  /// Where a tap goes — an affiliate deep link live; a shop search in demo.
  final String url;
  final int priceCents;
  final String? imageUrl;
  final bool isMock;

  String get priceLabel => '\$${(priceCents / 100).round()}';
}
