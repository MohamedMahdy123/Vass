import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mock_data.dart' show kCategories;
import '../data/models/item.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/item_image.dart';
import 'add_item_screen.dart';
import 'capture_screen.dart';
import 'item_detail_screen.dart';

/// The Closet tab — real wardrobe, read/written through [WardrobeState]
/// (Postgres when signed in, an in-memory demo list otherwise).
class ClosetScreen extends StatefulWidget {
  const ClosetScreen({super.key});

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  @override
  void initState() {
    super.initState();
    // Load once the first frame is up (avoids notifying during build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WardrobeState>().load();
    });
  }

  Future<void> _addItem() async {
    final t = context.vess;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: t.line, borderRadius: BorderRadius.circular(99)),
              ),
              const SizedBox(height: 20),
              _AddOption(
                icon: Icons.auto_awesome,
                title: 'Scan photos',
                subtitle: 'Snap a few pieces — AI tags them',
                accent: true,
                onTap: () => Navigator.of(ctx).pop('scan'),
              ),
              const SizedBox(height: 10),
              _AddOption(
                icon: Icons.edit_outlined,
                title: 'Add manually',
                subtitle: 'Enter the details yourself',
                onTap: () => Navigator.of(ctx).pop('manual'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            choice == 'scan' ? const CaptureScreen() : const AddItemScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final state = context.watch<WardrobeState>();
    final items = state.visibleItems;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Digital closet', style: serif(context, 32)),
                      const SizedBox(height: 4),
                      Text(
                        '${items.length} ${items.length == 1 ? 'piece' : 'pieces'}'
                        '${state.category == 'All' ? '' : ' · ${state.category}'}',
                        style: TextStyle(
                            fontFamily: kSans, fontSize: 13.5, color: t.ink2),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _addItem,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: t.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 38,
            child: ListView.separated(
              key: const ValueKey('cat-rail'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: kCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = kCategories[i];
                return VessChip(
                  key: ValueKey('cat-$cat'),
                  label: cat,
                  active: state.category == cat,
                  onTap: () => state.setCategory(cat),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _body(context, state, items)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, WardrobeState state, List<Item> items) {
    final t = context.vess;

    if (state.loading && state.count == 0) {
      return Center(
        child: CircularProgressIndicator(
            strokeWidth: 2.6, valueColor: AlwaysStoppedAnimation(t.accent)),
      );
    }

    if (state.count == 0) {
      // Whole wardrobe empty — invite the first piece.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.checkroom_outlined, size: 44, color: t.ink3),
              const SizedBox(height: 16),
              Text('Your closet is empty', style: serif(context, 24)),
              const SizedBox(height: 8),
              Text(
                'Add your first piece and Vess starts learning your wardrobe.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: kSans, fontSize: 14, height: 1.5, color: t.ink2),
              ),
              const SizedBox(height: 22),
              AccentButton(label: 'Add a piece', trailing: Icons.add, onTap: _addItem),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      // Filtered view is empty.
      return Center(
        child: Text('Nothing in ${state.category} yet.',
            style: TextStyle(fontFamily: kSans, fontSize: 14, color: t.ink3)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 108),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.62,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => ItemTile(item: items[i]),
    );
  }
}

/// Grid tile: swatch/photo, favourite heart, name and meta.
class ItemTile extends StatelessWidget {
  const ItemTile({super.key, required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final state = context.read<WardrobeState>();
    final meta = [item.brand, item.color].where((s) => s != null && s.isNotEmpty).join(' · ');

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(itemId: item.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ItemImage(
              item: item,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: GestureDetector(
                    onTap: () => state.toggleFavorite(item.id),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.favorite ? Icons.favorite : Icons.favorite_border,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.ink,
              )),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: kSans, fontSize: 11.5, color: t.ink3)),
          ],
        ],
      ),
    );
  }
}

/// A row in the "add" bottom sheet.
class _AddOption extends StatelessWidget {
  const _AddOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.card,
          border: Border.all(color: accent ? t.accent : t.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent ? t.accentSoft : t.sand2,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 21, color: accent ? t.accent : t.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: t.ink,
                      )),
                  Text(subtitle,
                      style: TextStyle(fontFamily: kSans, fontSize: 12.5, color: t.ink3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: t.ink3, size: 20),
          ],
        ),
      ),
    );
  }
}
