import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/item.dart';
import '../state/outfit_state.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/item_image.dart';
import 'outfit_analysis_screen.dart';
import 'outfits_screen.dart';

/// Compose a look on a canvas: tap wardrobe pieces from the category shelves to
/// add them, tap a placed piece to remove it, then Analyse or Save. Backed by
/// [OutfitState]; works fully in demo mode.
class OutfitCanvasScreen extends StatelessWidget {
  const OutfitCanvasScreen({super.key});

  // Head-to-toe display order for the flat-lay canvas.
  static const _display = ['Outerwear', 'Top', 'Bottom', 'Shoes', 'Accessory'];

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final outfit = context.watch<OutfitState>();
    final wardrobe = context.watch<WardrobeState>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WardrobeState>().load();
    });

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: VessBackButton(),
        ),
        title: Text('Outfit Canvas', style: serif(context, 22)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const OutfitsScreen())),
            child: Text('My Outfits',
                style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: t.accent)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      outfit.isEmpty
                          ? 'Tap pieces below to build a look'
                          : '${outfit.count} pieces · tap a piece to remove',
                      style: TextStyle(fontFamily: kSans, fontSize: 13, color: t.ink3),
                    ),
                  ),
                  if (!outfit.isEmpty)
                    TextButton(
                      onPressed: context.read<OutfitState>().clearCanvas,
                      child: Text('Clear',
                          style: TextStyle(
                              fontFamily: kSans,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.ink3)),
                    ),
                ],
              ),
            ),
            Expanded(child: _Canvas(outfit: outfit)),
            if (outfit.count >= 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const OutfitAnalysisScreen())),
                        icon: Icon(Icons.insights_outlined, size: 18, color: t.accent),
                        label: Text('Analyse',
                            style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: t.accent)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
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
                        label: 'Save look',
                        expand: true,
                        onTap: () {
                          context.read<OutfitState>().saveCanvas();
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                              backgroundColor: t.ink,
                              content: Text('Saved to My Outfits',
                                  style: TextStyle(fontFamily: kSans, color: t.bg)),
                            ));
                          Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => const OutfitsScreen()));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            _Shelves(wardrobe: wardrobe),
          ],
        ),
      ),
    );
  }
}

/// The flat-lay canvas — placed pieces stacked head-to-toe on a soft ground.
class _Canvas extends StatelessWidget {
  const _Canvas({required this.outfit});
  final OutfitState outfit;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    if (outfit.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checkroom_outlined, size: 40, color: t.ink3),
            const SizedBox(height: 12),
            Text('Your canvas is empty',
                style: TextStyle(fontFamily: kSans, fontSize: 14, color: t.ink3)),
          ],
        ),
      );
    }
    final placed = [
      for (final s in OutfitCanvasScreen._display)
        if (outfit.canvas[s] != null) MapEntry(s, outfit.canvas[s]!),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.line),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            for (final e in placed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: () => context.read<OutfitState>().removeSlot(e.key),
                  child: SizedBox(
                    width: 150,
                    height: 170,
                    child: Stack(
                      children: [
                        Positioned.fill(child: ItemImage(item: e.value, radius: 16)),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: t.bg.withOpacity(0.85),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, size: 15, color: t.ink2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Category shelves — horizontal strips of wardrobe pieces to tap onto the
/// canvas.
class _Shelves extends StatelessWidget {
  const _Shelves({required this.wardrobe});
  final WardrobeState wardrobe;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final outfit = context.read<OutfitState>();
    final rows = <Widget>[];
    for (final slot in OutfitState.slots) {
      final cat = OutfitState.slotCategory[slot]!;
      final items = wardrobe.items.where((i) => i.category == cat).toList();
      if (items.isEmpty) continue;
      final chosen = context.watch<OutfitState>().canvas[slot];
      rows.add(_Shelf(label: cat, items: items, chosenId: chosen?.id,
          onTap: (i) => outfit.place(i)));
    }
    return Container(
      height: 236,
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: t.shadow,
      ),
      child: rows.isEmpty
          ? Center(
              child: Text('Add pieces to your closet first',
                  style: TextStyle(fontFamily: kSans, fontSize: 13, color: t.ink3)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
              children: rows,
            ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.label,
    required this.items,
    required this.chosenId,
    required this.onTap,
  });
  final String label;
  final List<Item> items;
  final String? chosenId;
  final ValueChanged<Item> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
          child: Text(label.toUpperCase(),
              style: eyebrow(t.ink3, size: 10).copyWith(letterSpacing: 1.1)),
        ),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = items[i];
              final active = item.id == chosenId;
              return GestureDetector(
                onTap: () => onTap(item),
                child: Container(
                  width: 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: active ? t.accent : t.line,
                        width: active ? 2 : 1),
                  ),
                  child: ItemImage(item: item, radius: 12),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
