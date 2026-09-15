import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/item.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/item_image.dart';

const _categories = ['Tops', 'Bottoms', 'Outerwear', 'Footwear', 'Accessories', 'Dresses', 'Other'];
const _seasons = ['Spring', 'Summer', 'Autumn', 'Winter', 'All'];
const _occasions = ['Casual', 'Work', 'Smart', 'Formal', 'Active'];
const _weather = ['Hot', 'Warm', 'Mild', 'Cool', 'Cold', 'Rain'];

/// Manual add / edit form. Photo capture + AI tagging arrive in M2; for now this
/// is how a piece enters the wardrobe, and how any piece is edited.
class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key, this.existing});

  final Item? existing;

  bool get isEdit => existing != null;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  late final TextEditingController _name;
  late final TextEditingController _color;
  late final TextEditingController _material;
  late final TextEditingController _pattern;
  late final TextEditingController _brand;

  late String _category;
  final Set<String> _seasonSel = {};
  final Set<String> _occasionSel = {};
  final Set<String> _weatherSel = {};
  late bool _favorite;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name == 'Untitled' ? '' : e?.name ?? '');
    _color = TextEditingController(text: e?.color ?? '');
    _material = TextEditingController(text: e?.material ?? '');
    _pattern = TextEditingController(text: e?.pattern ?? '');
    _brand = TextEditingController(text: e?.brand ?? '');
    _category = e?.category != null && _categories.contains(e!.category) ? e.category! : 'Tops';
    _seasonSel.addAll(e?.seasonTags ?? const []);
    _occasionSel.addAll(e?.occasionTags ?? const []);
    _weatherSel.addAll(e?.weatherTags ?? const []);
    _favorite = e?.favorite ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    _material.dispose();
    _pattern.dispose();
    _brand.dispose();
    super.dispose();
  }

  String? _clean(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  void _toggle(Set<String> set, String value) {
    if (!set.remove(value)) set.add(value);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _toast('Give the piece a name.');
      return;
    }
    setState(() => _saving = true);
    final state = context.read<WardrobeState>();
    final seasons = _seasonSel.toList();
    final occasions = _occasionSel.toList();
    final weather = _weatherSel.toList();
    final color = _clean(_color);
    final material = _clean(_material);
    try {
      if (widget.isEdit) {
        final e = widget.existing!;
        final edited = Item(
          id: e.id,
          userId: e.userId,
          imagePath: e.imagePath,
          processedImageUrl: e.processedImageUrl,
          name: _name.text.trim(),
          category: _category,
          subCategory: e.subCategory,
          colorPrimary: color,
          colorSecondary: e.colorSecondary,
          fabricType: material,
          occasions: occasions,
          seasons: seasons,
          weatherTags: weather,
          pattern: _clean(_pattern),
          brand: _clean(_brand),
          favorite: _favorite,
          wearCount: e.wearCount,
          lastWornAt: e.lastWornAt,
          status: e.status,
          localBytes: e.localBytes,
          processedBytes: e.processedBytes,
          // legacy mirrors for single-value readers (swatch, older screens)
          color: color,
          material: material,
          season: seasons.isNotEmpty ? seasons.first : null,
          occasion: occasions.isNotEmpty ? occasions.first : null,
        );
        await state.updateItem(edited);
      } else {
        await state.add(Item(
          id: '',
          name: _name.text.trim(),
          category: _category,
          colorPrimary: color,
          fabricType: material,
          occasions: occasions,
          seasons: seasons,
          weatherTags: weather,
          pattern: _clean(_pattern),
          brand: _clean(_brand),
          favorite: _favorite,
          status: ItemStatus.reviewed,
          // legacy mirrors for single-value readers
          color: color,
          material: material,
          season: seasons.isNotEmpty ? seasons.first : null,
          occasion: occasions.isNotEmpty ? occasions.first : null,
        ));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _toast('Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final preview = swatchColor(_color.text);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  const VessBackButton(),
                  const SizedBox(width: 14),
                  Text(widget.isEdit ? 'Edit piece' : 'Add piece',
                      style: serif(context, 26)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  // Live color preview (a real photo replaces this in M2).
                  Center(
                    child: Container(
                      width: 130,
                      height: 168,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: const Alignment(-0.72, -0.94),
                          end: const Alignment(0.72, 0.94),
                          colors: [preview, Color.lerp(preview, Colors.black, 0.28)!],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: t.shadow,
                      ),
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text('Photo comes in M2',
                            style: TextStyle(
                              fontFamily: kSans,
                              fontSize: 10.5,
                              color: Colors.white.withOpacity(0.75),
                            )),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Field(label: 'Name', controller: _name, hint: 'Ribbed Wool Sweater'),
                  const SizedBox(height: 18),
                  const _Label('Category'),
                  const SizedBox(height: 10),
                  _ChipRow(
                    options: _categories,
                    value: _category,
                    onSelect: (v) => setState(() => _category = v),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Field(
                          label: 'Color',
                          controller: _color,
                          hint: 'Charcoal',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _Field(label: 'Brand', controller: _brand, hint: 'Optional')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _Field(label: 'Material', controller: _material, hint: 'Wool')),
                      const SizedBox(width: 12),
                      Expanded(child: _Field(label: 'Pattern', controller: _pattern, hint: 'Solid')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _MultiLabel('Occasion', 'Pick every setting it works for'),
                  const SizedBox(height: 10),
                  _MultiChipRow(
                    options: _occasions,
                    selected: _occasionSel,
                    onToggle: (v) => setState(() => _toggle(_occasionSel, v)),
                  ),
                  const SizedBox(height: 18),
                  const _MultiLabel('Season', 'Add all that apply'),
                  const SizedBox(height: 10),
                  _MultiChipRow(
                    options: _seasons,
                    selected: _seasonSel,
                    onToggle: (v) => setState(() => _toggle(_seasonSel, v)),
                  ),
                  const SizedBox(height: 18),
                  const _MultiLabel('Weather', 'When it keeps you comfortable'),
                  const SizedBox(height: 10),
                  _MultiChipRow(
                    options: _weather,
                    selected: _weatherSel,
                    onToggle: (v) => setState(() => _toggle(_weatherSel, v)),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Favourite',
                        style: TextStyle(
                            fontFamily: kSans,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: t.ink)),
                    value: _favorite,
                    activeColor: Colors.white,
                    activeTrackColor: t.accent,
                    onChanged: (v) => setState(() => _favorite = v),
                  ),
                  const SizedBox(height: 20),
                  AccentButton(
                    label: _saving
                        ? 'Saving…'
                        : (widget.isEdit ? 'Save changes' : 'Add to closet'),
                    expand: true,
                    onTap: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontFamily: kSans,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: context.vess.ink2,
        ),
      );
}

/// Label with a short helper line, for multi-select groups where "more than
/// one" isn't obvious from a single-select control.
class _MultiLabel extends StatelessWidget {
  const _MultiLabel(this.text, this.hint);
  final String text;
  final String hint;
  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        _Label(text),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            hint,
            style: TextStyle(fontFamily: kSans, fontSize: 11.5, color: t.ink3),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Multi-select chip group — any number of options can be active at once.
class _MultiChipRow extends StatelessWidget {
  const _MultiChipRow({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          VessChip(
            label: o,
            active: selected.contains(o),
            onTap: () => onToggle(o),
          ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: TextStyle(fontFamily: kSans, fontSize: 15, color: t.ink),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontFamily: kSans, fontSize: 15, color: t.ink3),
              filled: true,
              fillColor: t.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: t.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: t.accent),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.options, required this.value, required this.onSelect});

  final List<String> options;
  final String? value;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          VessChip(label: o, active: value == o, onTap: () => onSelect(o)),
      ],
    );
  }
}
