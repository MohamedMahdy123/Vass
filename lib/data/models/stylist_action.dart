/// The kinds of in-app navigation the stylist can trigger from a chat turn.
enum StylistActionType {
  /// Open a specific composed look in the analysis view (carries [itemIds]).
  viewOutfit,

  /// Open the Outfit Canvas to compose/edit a look.
  openCanvas,

  /// Open the saved-looks gallery ("My Outfits").
  openOutfits,

  /// Open one wardrobe item's detail (carries [itemId]).
  openItem,

  /// Switch to the Try-On tab.
  openTryOn,

  /// Switch to the Closet tab.
  openCloset,
}

/// A structured, tappable action returned alongside a stylist reply — the
/// intent-routing contract. The chat renders it as an action card; tapping it
/// deep-links into the matching screen. Mirrors the JSON the `stylist` Edge
/// Function returns (`{ reply, action }`) so live and local paths are identical.
class StylistAction {
  const StylistAction({
    required this.type,
    required this.label,
    this.itemIds = const [],
    this.itemId,
    this.occasion,
  });

  final StylistActionType type;

  /// The action-card button label, e.g. "See this look".
  final String label;

  /// Members of the proposed look (for [StylistActionType.viewOutfit]).
  final List<String> itemIds;

  /// The wardrobe item to open (for [StylistActionType.openItem]).
  final String? itemId;

  /// Optional occasion context to carry into the destination.
  final String? occasion;

  static StylistActionType? _typeFromName(String? name) {
    switch (name) {
      case 'view_outfit':
        return StylistActionType.viewOutfit;
      case 'open_canvas':
        return StylistActionType.openCanvas;
      case 'open_outfits':
        return StylistActionType.openOutfits;
      case 'open_item':
        return StylistActionType.openItem;
      case 'open_tryon':
        return StylistActionType.openTryOn;
      case 'open_closet':
        return StylistActionType.openCloset;
    }
    return null;
  }

  /// Parse the Edge Function's `action` object; returns null when absent or
  /// unrecognized (a plain text reply with no routing).
  static StylistAction? fromJson(dynamic json) {
    if (json is! Map) return null;
    final type = _typeFromName(json['type'] as String?);
    if (type == null) return null;
    return StylistAction(
      type: type,
      label: (json['label'] as String?)?.trim().isNotEmpty == true
          ? json['label'] as String
          : _defaultLabel(type),
      itemIds: (json['item_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      itemId: json['item_id'] as String?,
      occasion: json['occasion'] as String?,
    );
  }

  static String _defaultLabel(StylistActionType type) {
    switch (type) {
      case StylistActionType.viewOutfit:
        return 'See this look';
      case StylistActionType.openCanvas:
        return 'Open the canvas';
      case StylistActionType.openOutfits:
        return 'View My Outfits';
      case StylistActionType.openItem:
        return 'View item';
      case StylistActionType.openTryOn:
        return 'Try it on';
      case StylistActionType.openCloset:
        return 'Open my closet';
    }
  }
}
