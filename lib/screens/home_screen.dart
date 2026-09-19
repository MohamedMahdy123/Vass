import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/complete_the_look_repository.dart';
import '../data/models/item.dart';
import '../data/models/product_offer.dart';
import '../services/outfit_engine.dart';
import '../state/complete_the_look_state.dart';
import '../state/recommendation_state.dart';
import '../state/stylist_state.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/item_image.dart';
import 'outfit_canvas_screen.dart';
import 'outfits_screen.dart';
import 'scheduler_sheet.dart';
import 'item_detail_screen.dart';
import 'shell.dart';

/// Home — the daily hero: "What should I wear today?". Real recommendation over
/// the user's own wardrobe ([WardrobeState]), with the AI's reason and
/// accept / try-again that feed back into the recommender.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _occasions = ['Everyday', 'Work', 'Smart', 'Casual', 'Formal'];

  // Tracks the shown outfit so we re-run gap detection only when it changes.
  String _gapKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final wardrobe = context.read<WardrobeState>();
    final rec = context.read<RecommendationState>();
    await wardrobe.load();
    if (!mounted) return;
    if (!rec.hasOutfit && !rec.generating) {
      await rec.generate(wardrobe.items);
    }
  }

  Future<void> _regenerateFor(String occasion) async {
    final wardrobe = context.read<WardrobeState>();
    final rec = context.read<RecommendationState>()..setOccasion(occasion);
    await rec.generate(wardrobe.items);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final wardrobe = context.watch<WardrobeState>();
    final rec = context.watch<RecommendationState>();

    // Re-run "complete the look" whenever the shown outfit changes.
    final complete = context.read<CompleteTheLookState>();
    if (rec.hasOutfit) {
      final key = '${rec.occasion}|${rec.todayItems.map((i) => i.id).join(",")}';
      if (key != _gapKey) {
        _gapKey = key;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          complete.analyze(rec.todayItems, context.read<WardrobeState>().items,
              occasion: rec.occasion, weather: rec.weather);
        });
      }
    } else if (_gapKey.isNotEmpty) {
      _gapKey = '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<CompleteTheLookState>().clear();
      });
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 108),
        children: [
          const SizedBox(height: 8),
          _Header(onProfile: () => Shell.of(context)?.goTo(4)),
          const SizedBox(height: 18),

          // Occasion selector — drives what the recommender optimizes for.
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _occasions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final o = _occasions[i];
                return VessChip(
                  label: o,
                  active: rec.occasion == o,
                  onTap: () => _regenerateFor(o),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          _RecommendationCard(wardrobe: wardrobe, rec: rec),
          const _CompleteTheLookCard(),
          const SizedBox(height: 14),

          const _StylistPrompt(),
          const SizedBox(height: 12),

          VessCard(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const OutfitCanvasScreen()),
            ),
            child: Row(
              children: [
                Icon(Icons.dashboard_customize_outlined, size: 20, color: t.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Build a look yourself',
                      style: TextStyle(
                          fontFamily: kSans, fontSize: 14.5, color: t.ink)),
                ),
                Icon(Icons.chevron_right, size: 20, color: t.ink3),
              ],
            ),
          ),
          const SizedBox(height: 12),

          VessCard(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            onTap: () => showSchedulerSheet(context),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 20, color: t.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Schedule an outfit',
                          style: TextStyle(
                              fontFamily: kSans, fontSize: 14.5, color: t.ink)),
                      const SizedBox(height: 1),
                      Text('Plan ahead for an occasion & get reminded',
                          style: TextStyle(
                              fontFamily: kSans, fontSize: 12, color: t.ink3)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: t.ink3),
              ],
            ),
          ),
          const SizedBox(height: 12),

          VessCard(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const OutfitsScreen()),
            ),
            child: Row(
              children: [
                Icon(Icons.style_outlined, size: 20, color: t.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('My Outfits',
                      style: TextStyle(
                          fontFamily: kSans, fontSize: 14.5, color: t.ink)),
                ),
                Icon(Icons.chevron_right, size: 20, color: t.ink3),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: VessCard(
                  padding: const EdgeInsets.all(18),
                  radius: 20,
                  onTap: () => Shell.of(context)?.goTo(1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CardLabel('Closet', t.ink3),
                      const SizedBox(height: 8),
                      Text('${wardrobe.count}',
                          style: serif(context, 34).copyWith(height: 1)),
                      const SizedBox(height: 4),
                      Text('pieces · tap to browse',
                          style: TextStyle(
                              fontFamily: kSans, fontSize: 12.5, color: t.ink2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: VessCard(
                  padding: const EdgeInsets.all(18),
                  radius: 20,
                  onTap: () => Shell.of(context)?.goTo(1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CardLabel('Add pieces', t.ink3),
                      const SizedBox(height: 8),
                      Icon(Icons.add_a_photo_outlined, size: 30, color: t.accent),
                      const SizedBox(height: 6),
                      Text('Scan or add manually',
                          style: TextStyle(
                              fontFamily: kSans, fontSize: 12.5, color: t.ink2)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onProfile});
  final VoidCallback onProfile;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String get _today {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_today,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: t.ink3,
                  )),
              const SizedBox(height: 2),
              Text(_greeting, style: serif(context, 30).copyWith(height: 1.1)),
            ],
          ),
        ),
        GestureDetector(
          onTap: onProfile,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.line),
              gradient: LinearGradient(
                begin: const Alignment(-0.8, -0.9),
                end: const Alignment(0.8, 0.9),
                colors: t.ob2,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person_outline, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }
}

/// The hero card: today's recommended outfit, its pieces, and the "why".
class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.wardrobe, required this.rec});

  final WardrobeState wardrobe;
  final RecommendationState rec;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;

    // Not enough to build a look yet.
    if (wardrobe.count < RecommendationState.minItems && !wardrobe.loading) {
      return _EmptyState(needed: RecommendationState.minItems - wardrobe.count);
    }

    if (rec.generating && !rec.hasOutfit) {
      return const _LoadingCard();
    }

    final outfit = rec.today;
    if (outfit == null) {
      return VessCard(
        radius: 24,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No look yet', style: serif(context, 22)),
            const SizedBox(height: 6),
            Text(
              rec.error ?? 'Tap below to build today\'s outfit.',
              style: TextStyle(fontFamily: kSans, fontSize: 13.5, color: t.ink2),
            ),
            const SizedBox(height: 16),
            AccentButton(
              label: 'Build my outfit',
              expand: true,
              onTap: () => rec.generate(wardrobe.items),
            ),
          ],
        ),
      );
    }

    final pieces = rec.todayItems;

    return VessCard(
      padding: EdgeInsets.zero,
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TODAY'S OUTFIT",
                          style: eyebrow(t.accent, size: 12)
                              .copyWith(letterSpacing: 1.7)),
                      const SizedBox(height: 5),
                      Text(outfit.title, style: serif(context, 24)),
                      if (rec.forecast != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                                rec.forecast!.rain
                                    ? Icons.umbrella_outlined
                                    : Icons.wb_sunny_outlined,
                                size: 14,
                                color: t.ink3),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text('Dressed for ${rec.forecast!.short}',
                                  style: TextStyle(
                                      fontFamily: kSans,
                                      fontSize: VessType.caption,
                                      color: t.ink3)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Refresh for a different valid look.
                _RoundIcon(
                  icon: Icons.refresh,
                  busy: rec.generating,
                  onTap: rec.generating ? null : () => rec.tryAgain(wardrobe.items),
                ),
              ],
            ),
          ),

          // The pieces.
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: pieces.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _PieceTile(item: pieces[i]),
            ),
          ),

          // The "why".
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.accentSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome, size: 17, color: t.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      outfit.reason,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 13.5,
                        height: 1.5,
                        color: t.ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Accept / not today.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => rec.reject(wardrobe.items),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: BorderSide(color: t.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text('Not today',
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.ink2,
                        )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AccentButton(
                    label: 'Wear it',
                    expand: true,
                    trailing: Icons.check,
                    onTap: () async {
                      // Capture before the await so we don't reach across the gap.
                      final messenger = ScaffoldMessenger.of(context);
                      await rec.accept(wardrobe.items);
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          backgroundColor: t.ink,
                          content: Text('Logged — enjoy your day',
                              style: TextStyle(fontFamily: kSans, color: t.bg)),
                        ));
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PieceTile extends StatelessWidget {
  const _PieceTile({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final slot = OutfitEngine.slotOf(item);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(itemId: item.id)),
      ),
      child: SizedBox(
        width: 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ItemImage(
                item: item,
                radius: 16,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      slot.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: kSans,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: t.ink,
                )),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return VessCard(
      radius: 26,
      padding: const EdgeInsets.symmetric(vertical: 54),
      child: Column(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: t.accent),
          ),
          const SizedBox(height: 16),
          Text('Styling your day…',
              style: TextStyle(fontFamily: kSans, fontSize: 13.5, color: t.ink2)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.needed});
  final int needed;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return VessCard(
      radius: 26,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.checkroom_outlined, size: 34, color: t.accent),
          const SizedBox(height: 14),
          Text('Let\'s fill your closet', style: serif(context, 24)),
          const SizedBox(height: 8),
          Text(
            'Add about $needed more ${needed == 1 ? 'piece' : 'pieces'} and I\'ll '
            'start recommending outfits from your own wardrobe each morning.',
            style: TextStyle(
                fontFamily: kSans, fontSize: 13.5, height: 1.5, color: t.ink2),
          ),
          const SizedBox(height: 18),
          AccentButton(
            label: 'Add pieces',
            expand: true,
            trailing: Icons.arrow_forward,
            onTap: () => Shell.of(context)?.goTo(1),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap, this.busy = false});
  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: t.accentSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: t.accent),
              )
            : Icon(icon, size: 20, color: t.accent),
      ),
    );
  }
}

/// "Complete the look" — the missing-item → closet-first → shop loop, rendered
/// under the recommendation when a finishing gap is detected.
class _CompleteTheLookCard extends StatelessWidget {
  const _CompleteTheLookCard();

  IconData _iconFor(String slot) {
    switch (slot) {
      case 'Bag':
        return Icons.shopping_bag_outlined;
      case 'Belt':
        return Icons.straighten;
      default:
        return Icons.checkroom_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final s = context.watch<CompleteTheLookState>();
    if (!s.hasSuggestion) return const SizedBox.shrink();
    final gap = s.gap!;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: VessCard(
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFor(gap.slot), size: 17, color: t.accent),
                const SizedBox(width: 8),
                Text('COMPLETE THE LOOK',
                    style: eyebrow(t.accent, size: 11.5).copyWith(letterSpacing: 1.4)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              s.closetMatch != null
                  ? 'You already own the finishing piece'
                  : 'Add a ${gap.slot.toLowerCase()}',
              style: serif(context, 21),
            ),
            const SizedBox(height: 6),
            Text(gap.reason,
                style: TextStyle(
                    fontFamily: kSans, fontSize: 13.5, height: 1.5, color: t.ink2)),
            const SizedBox(height: 14),
            if (s.closetMatch != null)
              _ClosetMatch(item: s.closetMatch!)
            else if (s.loading)
              Row(children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: t.accent)),
                const SizedBox(width: 10),
                Text('Finding options…',
                    style: TextStyle(fontFamily: kSans, fontSize: 13, color: t.ink3)),
              ])
            else if (s.offers.isNotEmpty) ...[
              Row(
                children: [
                  for (final o in s.offers) ...[
                    Expanded(child: _OfferTile(offer: o, icon: _iconFor(gap.slot))),
                    if (o != s.offers.last) const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text('Vess may earn a commission from purchases.',
                  style: TextStyle(
                      fontFamily: kSans, fontSize: 11, fontStyle: FontStyle.italic, color: t.ink3)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClosetMatch extends StatelessWidget {
  const _ClosetMatch({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(width: 46, height: 58, child: ItemImage(item: item, radius: 10)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: kSans, fontSize: 14, fontWeight: FontWeight.w600, color: t.ink)),
                const SizedBox(height: 2),
                Text('Already in your closet',
                    style: TextStyle(fontFamily: kSans, fontSize: 12, color: t.accent)),
              ],
            ),
          ),
          Icon(Icons.check_circle, size: 20, color: t.accent),
        ],
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.offer, required this.icon});
  final ProductOffer offer;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return GestureDetector(
      onTap: () async {
        // Log the click (best-effort) and open the shop / affiliate link.
        CompleteTheLookRepository().logClick(offer);
        final uri = Uri.tryParse(offer.url);
        var opened = false;
        if (uri != null) {
          try {
            opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {/* fall through to feedback */}
        }
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              backgroundColor: t.ink,
              content: Text('Couldn\'t open ${offer.brand} — try again',
                  style: TextStyle(fontFamily: kSans, color: t.bg)),
            ));
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _offerImage(context),
            ),
          ),
          const SizedBox(height: 7),
          Text(offer.brand,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: kSans, fontSize: 11.5, color: t.ink3)),
          Text(offer.priceLabel,
              style: TextStyle(
                  fontFamily: 'Geist Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.ink)),
        ],
      ),
    );
  }

  /// The real product photo (e.g. a ShopStyle catalog image) when the offer
  /// carries one, falling back to a neutral icon tile for mock offers or a
  /// broken URL — so the shop row shows real garments once live.
  Widget _offerImage(BuildContext context) {
    final t = context.vess;
    final url = offer.imageUrl;
    final placeholder = Container(
      color: t.sand2,
      alignment: Alignment.center,
      child: Icon(icon, size: 26, color: t.ink3),
    );
    if (url == null || !(url.startsWith('http://') || url.startsWith('https://'))) {
      return placeholder;
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : Container(color: t.sand2),
    );
  }
}

class _CardLabel extends StatelessWidget {
  const _CardLabel(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontFamily: kSans,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: color,
        ),
      );
}

/// A real quick-ask box: type a styling question here and it's sent straight
/// into the stylist conversation, then jumps to the Stylist tab to show the
/// reply (with any actionable deep-link card).
class _StylistPrompt extends StatefulWidget {
  const _StylistPrompt();

  @override
  State<_StylistPrompt> createState() => _StylistPromptState();
}

class _StylistPromptState extends State<_StylistPrompt> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final wardrobe = context.read<WardrobeState>().items;
    context.read<StylistState>().send(text, wardrobe);
    _controller.clear();
    FocusScope.of(context).unfocus();
    // Jump to the Stylist tab so the answer (and its action card) is visible.
    Shell.of(context)?.goTo(3);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: t.shadow,
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 20, color: t.accent),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: TextStyle(fontFamily: kSans, fontSize: 14.5, color: t.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Ask your stylist anything…',
                hintStyle: TextStyle(
                    fontFamily: kSans, fontSize: 14.5, color: t.ink3),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Ask the stylist',
            child: Material(
              color: t.accent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _send,
                child: const SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
