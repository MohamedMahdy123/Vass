import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/item.dart';
import '../data/models/outfit.dart';
import '../data/outfits_repository.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/item_image.dart';

/// Manually compose an outfit from your real wardrobe — four slots, filled from
/// a bottom sheet or "AI fill", then saved to your looks. Backed by
/// [WardrobeState]; saves to Postgres when live, otherwise confirms locally.
class BuilderScreen extends StatefulWidget {
  const BuilderScreen({super.key});

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  static const _slots = ['Top', 'Bottom', 'Outerwear', 'Shoes'];
  static const _slotCategory = {
    'Top': 'Tops',
    'Bottom': 'Bottoms',
    'Outerwear': 'Outerwear',
    'Shoes': 'Footwear',
  };

  final _outfit = <String, Item>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<WardrobeState>().load());
  }

  List<Item> _optionsFor(String slot) {
    final cat = _slotCategory[slot];
    return context
        .read<WardrobeState>()
        .items
        .where((i) => i.category == cat)
        .toList();
  }

  void _openPicker(String slot) {
    final t = context.vess;
    final options = _optionsFor(slot);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.bg2,
      barrierColor: t.overlay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: t.line, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 18),
              Text('Choose a ${slot.toLowerCase()}', style: serif(context, 26)),
              const SizedBox(height: 16),
              if (options.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No ${slot.toLowerCase()} in your closet yet. Add some from the Closet tab.',
                    style: TextStyle(fontFamily: kSans, fontSize: 14, color: t.ink3),
                  ),
                )
              else
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final item = options[i];
                      return GestureDetector(
                        onTap: () {
                          setState(() => _outfit[slot] = item);
                          Navigator.of(sheetContext).pop();
                        },
                        child: SizedBox(
                          width: 112,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: ItemImage(item: item, radius: 16)),
                              const SizedBox(height: 8),
                              Text(item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: kSans, fontSize: 12,
                                    fontWeight: FontWeight.w600, color: t.ink)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _aiFill() {
    setState(() {
      for (final slot in _slots) {
        if (_outfit.containsKey(slot)) continue;
        final options = _optionsFor(slot);
        if (options.isNotEmpty) _outfit[slot] = options.first;
      }
    });
  }

  Future<void> _save() async {
    if (_outfit.isEmpty || _saving) return;
    final t = context.vess;
    final wardrobe = context.read<WardrobeState>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);
    try {
      if (wardrobe.isLive) {
        final items = _outfit.values.toList();
        final slotFor = {
          for (final e in _outfit.entries) e.value.id: e.key,
        };
        await OutfitsRepository().save(
          OutfitSuggestion(
            title: 'My outfit',
            itemIds: items.map((i) => i.id).toList(),
            reason: 'Built by you.',
            status: OutfitStatus.accepted,
          ),
          slotFor: slotFor,
        );
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          backgroundColor: t.ink,
          content: Text('Outfit saved',
              style: TextStyle(fontFamily: kSans, color: t.bg)),
        ));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          backgroundColor: t.ink,
          content: Text("Couldn't save — try again",
              style: TextStyle(fontFamily: kSans, color: t.bg)),
        ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    context.watch<WardrobeState>(); // rebuild as the closet loads

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: VessBackButton(),
        ),
        title: Text('Build a look', style: serif(context, 22)),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    '${_outfit.length} of ${_slots.length} slots filled',
                    style: TextStyle(fontFamily: kSans, fontSize: 13.5, color: t.ink2),
                  ),
                ),
                if (_outfit.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(_outfit.clear),
                    child: Text('Clear',
                        style: TextStyle(
                          fontFamily: kSans, fontSize: 13.5,
                          fontWeight: FontWeight.w600, color: t.ink3)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.78,
              children: [
                for (final slot in _slots)
                  _Slot(
                    slot: slot,
                    item: _outfit[slot],
                    onTap: () => _openPicker(slot),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _aiFill,
                    icon: Icon(Icons.auto_awesome, size: 18, color: t.accent),
                    label: Text('AI fill',
                        style: TextStyle(
                          fontFamily: kSans, fontSize: 14,
                          fontWeight: FontWeight.w600, color: t.accent)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: t.accentSoft,
                      side: BorderSide(color: t.accent.withOpacity(0.35)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AccentButton(
                    label: _saving ? 'Saving…' : 'Save outfit',
                    expand: true,
                    onTap: _outfit.isEmpty || _saving ? null : _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.slot, required this.item, required this.onTap});

  final String slot;
  final Item? item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final filled = item != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: filled ? null : t.sand2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: filled ? Colors.transparent : t.line, width: 1),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (filled) ItemImage(item: item!, radius: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: filled
                  ? BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                      ),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slot.toUpperCase(),
                      style: eyebrow(
                        filled ? Colors.white70 : t.ink3, size: 10,
                      ).copyWith(letterSpacing: 1.2)),
                  const Spacer(),
                  if (filled)
                    Text(item!.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: kSans, fontSize: 13,
                          fontWeight: FontWeight.w600, height: 1.25,
                          color: Colors.white))
                  else
                    Row(
                      children: [
                        Icon(Icons.add, size: 18, color: t.ink3),
                        const SizedBox(width: 6),
                        Text('Add',
                            style: TextStyle(
                              fontFamily: kSans, fontSize: 13, color: t.ink3)),
                      ],
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
