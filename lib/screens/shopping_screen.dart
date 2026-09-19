import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/missing_item.dart';
import '../data/models/product_offer.dart';
import '../services/complete_the_look_service.dart';
import '../services/wardrobe_gaps.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// "Gaps in your wardrobe" — runs the finishing-piece detector over looks built
/// from the real closet, drops any gap you can already fill from what you own,
/// and surfaces the rest as shoppable suggestions with a reason and price band.
class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final _service = CompleteTheLookService();
  bool _loading = true;
  List<MissingItem> _gaps = const [];
  final Map<String, List<ProductOffer>> _offers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
  }

  String _key(MissingItem g) => '${g.slot}|${g.descriptor.category}';

  Future<void> _analyze() async {
    final w = context.read<WardrobeState>();
    await w.load();
    if (!mounted) return;
    final gaps = WardrobeGaps.detect(w.items);
    setState(() {
      _gaps = gaps;
      _loading = false;
    });
    // Fetch shoppable offers per gap (mock, price-banded, in demo).
    for (final g in gaps) {
      try {
        final offers = await _service.offersFor(g);
        if (!mounted) return;
        setState(() => _offers[_key(g)] = offers);
      } catch (_) {/* leave the gap without offers */}
    }
  }

  Future<void> _openOffer(ProductOffer offer) async {
    final uri = Uri.tryParse(offer.url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Could not open the shop link')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: VessBackButton(),
        ),
        title: Text('Shopping', style: serif(context, 22)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _gaps.isEmpty
              ? _complete(context)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                  children: [
                    Text('Pieces that would complete your looks',
                        style: TextStyle(
                            fontFamily: kSans, fontSize: 13.5, color: t.ink3)),
                    const SizedBox(height: 14),
                    for (final g in _gaps) ...[
                      _GapCard(
                        gap: g,
                        offers: _offers[_key(g)],
                        onOffer: _openOffer,
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
    );
  }

  Widget _complete(BuildContext context) {
    final t = context.vess;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 40, color: t.accent),
            const SizedBox(height: 12),
            Text('Your wardrobe looks complete',
                style: TextStyle(fontFamily: kSans, fontSize: 14.5, color: t.ink2)),
            const SizedBox(height: 6),
            Text('No obvious finishing pieces missing from your looks right now.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: kSans, fontSize: 13, color: t.ink3)),
          ],
        ),
      ),
    );
  }
}

class _GapCard extends StatelessWidget {
  const _GapCard({required this.gap, required this.offers, required this.onOffer});

  final MissingItem gap;
  final List<ProductOffer>? offers;
  final ValueChanged<ProductOffer> onOffer;

  IconData get _icon {
    switch (gap.slot) {
      case 'Outerwear':
        return Icons.checkroom_outlined;
      case 'Belt':
        return Icons.line_weight;
      case 'Bag':
        return Icons.shopping_bag_outlined;
    }
    return Icons.add_shopping_cart_outlined;
  }

  String get _title {
    final c = gap.descriptor.category;
    return c.isEmpty ? gap.slot : 'A ${c[0].toUpperCase()}${c.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: t.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, size: 20, color: t.accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title,
                        style: TextStyle(
                            fontFamily: kSerif, fontSize: 17, color: t.ink)),
                    const SizedBox(height: 2),
                    Text('Typically \$${gap.priceHint.min}–\$${gap.priceHint.max}',
                        style: TextStyle(
                            fontFamily: kSans, fontSize: 12, color: t.ink3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(gap.reason,
              style: TextStyle(
                  fontFamily: kSans, fontSize: 13.5, height: 1.5, color: t.ink2)),
          if (offers != null && offers!.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: offers!.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final o = offers![i];
                  return _OfferChip(offer: o, onTap: () => onOffer(o));
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfferChip extends StatelessWidget {
  const _OfferChip({required this.offer, required this.onTap});
  final ProductOffer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Material(
      color: t.bg2,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${offer.brand} · ${offer.priceLabel}',
                  style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: t.ink)),
              const SizedBox(width: 6),
              Icon(Icons.north_east, size: 13, color: t.accent),
            ],
          ),
        ),
      ),
    );
  }
}
