import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/item.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/item_image.dart';
import 'add_item_screen.dart';

/// Real item detail, driven by [WardrobeState]. Takes an id so it always
/// reflects the current store (favourite toggles, edits) rather than a snapshot.
class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  Future<void> _confirmDelete(BuildContext context, Item item) async {
    final t = context.vess;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        title: Text('Delete “${item.name}”?',
            style: TextStyle(fontFamily: kSerif, color: t.ink)),
        content: Text('This removes it from your wardrobe.',
            style: TextStyle(fontFamily: kSans, color: t.ink2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: t.ink2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFB3453B))),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<WardrobeState>().remove(item.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final state = context.watch<WardrobeState>();

    // The item can vanish (deleted); guard so we don't throw during pop.
    final exists = state.items.any((i) => i.id == itemId);
    if (!exists) return Scaffold(backgroundColor: t.bg, body: const SizedBox());
    final item = state.byId(itemId);

    // Single-value facts render as key/value chips.
    final attrs = <List<String>>[
      if (item.category != null) ['Category', item.category!],
      if (item.subCategory != null) ['Type', item.subCategory!],
      if (item.primaryColor != null) ['Colour', item.primaryColor!],
      if (item.secondaryColor != null) ['Accent', item.secondaryColor!],
      if (item.fabric != null) ['Fabric', item.fabric!],
      if (item.pattern != null) ['Pattern', item.pattern!],
    ];

    // Multi-value tag groups render as their own labelled chip rows.
    final tagGroups = <List<dynamic>>[
      if (item.occasionTags.isNotEmpty) ['Occasions', item.occasionTags],
      if (item.seasonTags.isNotEmpty) ['Seasons', item.seasonTags],
      if (item.weatherTags.isNotEmpty) ['Weather', item.weatherTags],
    ];

    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              AspectRatio(aspectRatio: 1, child: ItemImage(item: item, radius: 0)),
              Transform.translate(
                offset: const Offset(0, -26),
                child: Container(
                  decoration: BoxDecoration(
                    color: t.bg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.brand != null)
                        Text(item.brand!.toUpperCase(),
                            style: eyebrow(t.accent, size: 12).copyWith(letterSpacing: 1.7)),
                      const SizedBox(height: 6),
                      Text(item.name, style: serif(context, 32)),
                      if (item.lastWornAt != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 15, color: t.ink3),
                            const SizedBox(width: 6),
                            Text('Worn ${item.wearCount}×',
                                style: TextStyle(
                                    fontFamily: kSans, fontSize: 13.5, color: t.ink2)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 22),
                      if (attrs.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final a in attrs) _AttrChip(label: a[0], value: a[1])],
                        ),
                      for (final g in tagGroups) ...[
                        const SizedBox(height: 20),
                        _TagGroup(label: g[0] as String, values: g[1] as List<String>),
                      ],
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: AccentButton(
                              label: 'Edit piece',
                              expand: true,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => AddItemScreen(existing: item),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _SquareButton(
                            icon: item.favorite ? Icons.favorite : Icons.favorite_border,
                            active: item.favorite,
                            onTap: () => state.toggleFavorite(item.id),
                          ),
                          const SizedBox(width: 12),
                          _SquareButton(
                            icon: Icons.delete_outline,
                            onTap: () => _confirmDelete(context, item),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            child: const VessBackButton(),
          ),
        ],
      ),
    );
  }
}

/// A labelled row of read-only tag pills for a multi-value attribute
/// (occasions, seasons, weather).
class _TagGroup extends StatelessWidget {
  const _TagGroup({required this.label, required this.values});
  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: eyebrow(t.ink3, size: 10).copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in values)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: t.accentSoft,
                  border: Border.all(color: t.accent.withOpacity(0.35)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(v,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.accent,
                    )),
              ),
          ],
        ),
      ],
    );
  }
}

class _AttrChip extends StatelessWidget {
  const _AttrChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.sand2,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${label.toUpperCase()}  ',
              style: eyebrow(t.ink3, size: 9.5).copyWith(letterSpacing: 0.8)),
          Text(value,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.ink,
              )),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.onTap, this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: active ? t.accentSoft : t.card,
          border: Border.all(color: active ? t.accent : t.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: active ? t.accent : t.ink2, size: 21),
      ),
    );
  }
}
