import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/item.dart';
import '../data/tag_options.dart';
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
                      const SizedBox(height: 20),
                      _EditableTagGroup(
                        label: 'Occasions',
                        options: kOccasions,
                        selected: item.occasionTags,
                        onChanged: (next) =>
                            state.updateItem(_withTags(item, occasions: next)),
                      ),
                      const SizedBox(height: 20),
                      _EditableTagGroup(
                        label: 'Seasons',
                        options: kSeasons,
                        selected: item.seasonTags,
                        onChanged: (next) =>
                            state.updateItem(_withTags(item, seasons: next)),
                      ),
                      const SizedBox(height: 20),
                      _EditableTagGroup(
                        label: 'Weather',
                        options: kWeather,
                        selected: item.weatherTags,
                        onChanged: (next) =>
                            state.updateItem(_withTags(item, weatherTags: next)),
                      ),
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

/// Rebuild an item with one tag list replaced, preserving every other field
/// (including the background-removed cut-out) and keeping the legacy
/// single-value mirrors coherent so older readers don't show a stale value.
Item _withTags(
  Item e, {
  List<String>? occasions,
  List<String>? seasons,
  List<String>? weatherTags,
}) {
  final occ = occasions ?? e.occasionTags;
  final sea = seasons ?? e.seasonTags;
  final wea = weatherTags ?? e.weatherTags;
  return Item(
    id: e.id,
    userId: e.userId,
    name: e.name,
    imagePath: e.imagePath,
    processedImageUrl: e.processedImageUrl,
    category: e.category,
    subCategory: e.subCategory,
    colorPrimary: e.primaryColor,
    colorSecondary: e.colorSecondary,
    fabricType: e.fabric,
    pattern: e.pattern,
    brand: e.brand,
    occasions: occ,
    seasons: sea,
    weatherTags: wea,
    favorite: e.favorite,
    wearCount: e.wearCount,
    lastWornAt: e.lastWornAt,
    status: e.status,
    localBytes: e.localBytes,
    processedBytes: e.processedBytes,
    // legacy mirrors
    color: e.primaryColor,
    material: e.fabric,
    occasion: occ.isNotEmpty ? occ.first : null,
    season: sea.isNotEmpty ? sea.first : null,
  );
}

/// A labelled tag group that edits in place. Collapsed, it shows the selected
/// pills (or an "Add" hint when empty); tapping the pencil reveals every option
/// as a toggle, and each toggle persists immediately via [onChanged].
class _EditableTagGroup extends StatefulWidget {
  const _EditableTagGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_EditableTagGroup> createState() => _EditableTagGroupState();
}

class _EditableTagGroupState extends State<_EditableTagGroup> {
  bool _editing = false;

  void _toggle(String value) {
    final next = List<String>.from(widget.selected);
    if (!next.remove(value)) next.add(value);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final selected = widget.selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label.toUpperCase(),
                style: eyebrow(t.ink3, size: 10).copyWith(letterSpacing: 1.2)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _editing = !_editing),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Icon(_editing ? Icons.check_rounded : Icons.edit_outlined,
                        size: 15, color: t.accent),
                    const SizedBox(width: 4),
                    Text(_editing ? 'Done' : 'Edit',
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: t.accent,
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_editing)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in widget.options)
                VessChip(
                  label: o,
                  active: selected.contains(o),
                  onTap: () => _toggle(o),
                ),
            ],
          )
        else if (selected.isEmpty)
          GestureDetector(
            onTap: () => setState(() => _editing = true),
            behavior: HitTestBehavior.opaque,
            child: Text('Add ${widget.label.toLowerCase()}',
                style: TextStyle(
                    fontFamily: kSans, fontSize: 13, color: t.ink3)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in selected)
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
