/// A suggested / accepted / rejected look, as stored in `public.outfits`
/// (with its members in `public.outfit_items`). This is the real recommendation
/// model — the AI's pick plus the "why" that makes it trustworthy.
enum OutfitStatus { suggested, accepted, rejected }

class OutfitSuggestion {
  const OutfitSuggestion({
    this.id,
    required this.title,
    required this.itemIds,
    required this.reason,
    this.occasion,
    this.status = OutfitStatus.suggested,
    this.forDate,
  });

  /// Null until persisted (demo mode never persists).
  final String? id;
  final String title;
  final List<String> itemIds;

  /// The one warm, concrete paragraph on why this look works today. Both the
  /// differentiator and the trust safety-net — never empty.
  final String reason;
  final String? occasion;
  final OutfitStatus status;
  final DateTime? forDate;

  OutfitSuggestion copyWith({
    String? id,
    String? title,
    List<String>? itemIds,
    String? reason,
    String? occasion,
    OutfitStatus? status,
    DateTime? forDate,
  }) {
    return OutfitSuggestion(
      id: id ?? this.id,
      title: title ?? this.title,
      itemIds: itemIds ?? this.itemIds,
      reason: reason ?? this.reason,
      occasion: occasion ?? this.occasion,
      status: status ?? this.status,
      forDate: forDate ?? this.forDate,
    );
  }

  factory OutfitSuggestion.fromMap(Map<String, dynamic> m, List<String> itemIds) {
    return OutfitSuggestion(
      id: m['id'] as String?,
      title: (m['title'] as String?) ?? 'Your look',
      itemIds: itemIds,
      reason: (m['reason'] as String?) ?? '',
      occasion: m['occasion'] as String?,
      status: OutfitStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => OutfitStatus.suggested,
      ),
      forDate: m['for_date'] == null
          ? null
          : DateTime.parse(m['for_date'] as String),
    );
  }

  /// Columns the client writes to `outfits`. user_id is set server-side via the
  /// authenticated session (DEFAULT auth.uid()), so it's never sent here.
  Map<String, dynamic> toInsert() => {
        'title': title,
        'occasion': occasion,
        'reason': reason,
        'status': status.name,
      };
}
