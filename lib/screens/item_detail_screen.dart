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
                      _EditableAttr(
                        label: 'Category',
                        value: item.category,
                        options: kCategories,
                        onChanged: (v) =>
                            state.updateItem(_edited(item, category: v)),
                      ),
                      _EditableAttr(
                        label: 'Type',
                        value: item.subCategory,
                        hint: 'e.g. Overcoat',
                        onChanged: (v) =>
                            state.updateItem(_edited(item, subCategory: v)),
                      ),
                      _EditableAttr(
                        label: 'Colour',
                        value: item.primaryColor,
                        hint: 'e.g. Charcoal',
                        onChanged: (v) =>
                            state.updateItem(_edited(item, colorPrimary: v)),
                      ),
                      _EditableAttr(
                        label: 'Accent',
                        value: item.secondaryColor,
                        hint: 'Secondary colour',
                        onChanged: (v) =>
                            state.updateItem(_edited(item, colorSecondary: v)),
                      ),
                      _EditableAttr(
                        label: 'Fabric',
                        value: item.fabric,
                        hint: 'e.g. Wool',
                        onChanged: (v) =>
                            state.updateItem(_edited(item, fabricType: v)),
                      ),
                      _EditableAttr(
                        label: 'Pattern',
                        value: item.pattern,
                        hint: 'e.g. Solid',
                        onChanged: (v) =>
                            state.updateItem(_edited(item, pattern: v)),
                      ),
                      const SizedBox(height: 22),
                      _EditableTagGroup(
                        label: 'Occasions',
                        options: kOccasions,
                        selected: item.occasionTags,
                        onChanged: (next) =>
                            state.updateItem(_edited(item, occasions: next)),
                      ),
                      const SizedBox(height: 20),
                      _EditableTagGroup(
                        label: 'Seasons',
                        options: kSeasons,
                        selected: item.seasonTags,
                        onChanged: (next) =>
                            state.updateItem(_edited(item, seasons: next)),
                      ),
                      const SizedBox(height: 20),
                      _EditableTagGroup(
                        label: 'Weather',
                        options: kWeather,
                        selected: item.weatherTags,
                        onChanged: (next) =>
                            state.updateItem(_edited(item, weatherTags: next)),
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

/// Sentinel for [_edited]: distinguishes "leave this field unchanged" from
/// "set it to null" (clear it).
const Object _unset = Object();

/// Rebuild an item with selected attributes replaced, preserving every other
/// field (including the background-removed cut-out) and keeping the legacy
/// single-value mirrors coherent so older readers never show a stale value.
///
/// Any argument left at [_unset] keeps the item's current value; passing an
/// explicit value (including null) sets it.
Item _edited(
  Item e, {
  Object? category = _unset,
  Object? subCategory = _unset,
  Object? colorPrimary = _unset,
  Object? colorSecondary = _unset,
  Object? fabricType = _unset,
  Object? pattern = _unset,
  Object? occasions = _unset,
  Object? seasons = _unset,
  Object? weatherTags = _unset,
}) {
  String? str(Object? v, String? cur) => identical(v, _unset) ? cur : v as String?;
  List<String> list(Object? v, List<String> cur) =>
      identical(v, _unset) ? cur : (v as List<String>);

  final cat = str(category, e.category);
  final sub = str(subCategory, e.subCategory);
  final cp = str(colorPrimary, e.primaryColor);
  final cs = str(colorSecondary, e.colorSecondary);
  final fab = str(fabricType, e.fabric);
  final pat = str(pattern, e.pattern);
  final occ = list(occasions, e.occasionTags);
  final sea = list(seasons, e.seasonTags);
  final wea = list(weatherTags, e.weatherTags);

  return Item(
    id: e.id,
    userId: e.userId,
    name: e.name,
    imagePath: e.imagePath,
    processedImageUrl: e.processedImageUrl,
    category: cat,
    subCategory: sub,
    colorPrimary: cp,
    colorSecondary: cs,
    fabricType: fab,
    pattern: pat,
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
    color: cp,
    material: fab,
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

/// One single-value attribute, editable in place. Collapsed, it's a compact
/// label/value row with an edit affordance. Tapping opens either a single-
/// select chip picker ([options] set) or a free-text field. Each commit
/// persists via [onChanged]; an empty free-text value clears the attribute.
class _EditableAttr extends StatefulWidget {
  const _EditableAttr({
    required this.label,
    required this.value,
    required this.onChanged,
    this.options,
    this.hint,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final List<String>? options; // null → free text
  final String? hint;

  @override
  State<_EditableAttr> createState() => _EditableAttrState();
}

class _EditableAttrState extends State<_EditableAttr> {
  bool _editing = false;
  late final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _open() {
    _text.text = widget.value ?? '';
    setState(() => _editing = true);
  }

  void _commitText() {
    final v = _text.text.trim();
    setState(() => _editing = false);
    widget.onChanged(v.isEmpty ? null : v);
  }

  void _pick(String v) {
    setState(() => _editing = false);
    widget.onChanged(v == widget.value ? null : v); // tap current → clear
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 78,
                child: Text(widget.label.toUpperCase(),
                    style: eyebrow(t.ink3, size: 9.5).copyWith(letterSpacing: 0.8)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: widget.value != null
                    ? Text(widget.value!,
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ))
                    : Text('Not set',
                        style: TextStyle(
                            fontFamily: kSans, fontSize: 13.5, color: t.ink3)),
              ),
              GestureDetector(
                onTap: () => _editing ? setState(() => _editing = false) : _open(),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Icon(_editing ? Icons.close_rounded : Icons.edit_outlined,
                      size: 15, color: t.accent),
                ),
              ),
            ],
          ),
          if (_editing) ...[
            const SizedBox(height: 10),
            if (widget.options != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in widget.options!)
                    VessChip(
                      label: o,
                      active: o == widget.value,
                      onTap: () => _pick(o),
                    ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: TextField(
                        controller: _text,
                        autofocus: true,
                        onSubmitted: (_) => _commitText(),
                        style: TextStyle(fontFamily: kSans, fontSize: 14.5, color: t.ink),
                        decoration: InputDecoration(
                          hintText: widget.hint,
                          hintStyle:
                              TextStyle(fontFamily: kSans, fontSize: 14, color: t.ink3),
                          filled: true,
                          fillColor: t.card,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: t.line),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: t.accent),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _commitText,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.accentSoft,
                        border: Border.all(color: t.accent.withOpacity(0.35)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Save',
                          style: TextStyle(
                            fontFamily: kSans,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: t.accent,
                          )),
                    ),
                  ),
                ],
              ),
          ],
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
