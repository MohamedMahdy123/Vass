import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/outfit_state.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/item_image.dart';
import 'outfit_analysis_screen.dart';
import 'outfit_canvas_screen.dart';

/// The saved-looks gallery ("My Outfits"): outfit cards with a filter row, each
/// a small collage of its pieces with its tags and Vess AI Score. Backed by
/// [OutfitState]; seeded with a couple of demo looks so it's never empty.
class OutfitsScreen extends StatefulWidget {
  const OutfitsScreen({super.key});

  @override
  State<OutfitsScreen> createState() => _OutfitsScreenState();
}

class _OutfitsScreenState extends State<OutfitsScreen> {
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final w = context.read<WardrobeState>();
      context.read<OutfitState>().seedFrom(w.items);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final outfits = context.watch<OutfitState>().saved;
    final filters = <String>{
      'All',
      ...outfits.map((o) => o.occasion ?? 'Casual'),
    }.toList();
    final shown = _filter == 'All'
        ? outfits
        : outfits.where((o) => (o.occasion ?? 'Casual') == _filter).toList();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: VessBackButton(),
        ),
        title: Text('My Outfits', style: serif(context, 22)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: t.accent,
        onPressed: () {
          context.read<OutfitState>().clearCanvas();
          Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const OutfitCanvasScreen()));
        },
        icon: const Icon(Icons.add, color: Colors.white, size: 20),
        label: const Text('New look',
            style: TextStyle(
                fontFamily: kSans, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => VessChip(
                label: filters[i],
                active: _filter == filters[i],
                onTap: () => setState(() => _filter = filters[i]),
              ),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.style_outlined, size: 40, color: t.ink3),
                        const SizedBox(height: 12),
                        Text('No looks yet',
                            style: TextStyle(
                                fontFamily: kSans, fontSize: 14, color: t.ink3)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 18,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: shown.length,
                    itemBuilder: (context, i) => _OutfitCard(outfit: shown[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OutfitCard extends StatelessWidget {
  const _OutfitCard({required this.outfit});
  final SavedOutfit outfit;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final imgs = outfit.items.take(4).toList();
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            OutfitAnalysisScreen(items: outfit.items, title: outfit.title),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.line),
              ),
              child: Stack(
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1,
                    children: [
                      for (var k = 0; k < 4; k++)
                        k < imgs.length
                            ? ItemImage(item: imgs[k], radius: 12)
                            : const SizedBox.shrink(),
                    ],
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.ink.withOpacity(0.86),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${outfit.score}',
                          style: TextStyle(
                              fontFamily: kSans,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: t.bg)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(outfit.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: kSerif, fontSize: 15.5, color: t.ink)),
          const SizedBox(height: 3),
          Text(outfit.tags.take(2).join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: kSans, fontSize: 11.5, color: t.ink3)),
        ],
      ),
    );
  }
}
