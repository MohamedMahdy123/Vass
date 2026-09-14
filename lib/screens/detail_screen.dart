import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Item detail. Takes an id rather than the item so it always reflects the
/// current store (e.g. the favourite toggling underneath it).
class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final state = context.watch<AppState>();
    final item = state.itemById(itemId);

    final attrs = <List<String>>[
      ['Category', item.cat],
      ['Colour', item.color],
      ['Season', item.season],
      ['Occasion', item.occ],
    ];

    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              // Full-bleed swatch standing in for the garment photo.
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: VessTokens.itemGradient(item.a, item.b),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -26),
                child: Container(
                  decoration: BoxDecoration(
                    color: t.bg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.brand.toUpperCase(),
                          style: eyebrow(t.accent, size: 12)
                              .copyWith(letterSpacing: 1.7)),
                      const SizedBox(height: 6),
                      Text(item.name, style: serif(context, 32)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 15, color: t.ink3),
                          const SizedBox(width: 6),
                          Text('Last worn ${item.worn}',
                              style: TextStyle(
                                  fontFamily: kSans,
                                  fontSize: 13.5,
                                  color: t.ink2)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          for (final a in attrs) ...[
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: t.sand2,
                                  border: Border.all(color: t.line),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  children: [
                                    Text(a[0].toUpperCase(),
                                        style: eyebrow(t.ink3, size: 8.5)
                                            .copyWith(letterSpacing: 0.8)),
                                    const SizedBox(height: 5),
                                    Text(a[1],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: kSans,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: t.ink,
                                        )),
                                  ],
                                ),
                              ),
                            ),
                            if (a != attrs.last) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      const SizedBox(height: 26),
                      Text('PAIRS WELL WITH',
                          style: eyebrow(t.ink3, size: 12.5)
                              .copyWith(letterSpacing: 1.25)),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 104,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 4,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            // Simple stand-in pairing: other categories.
                            final others = state.closet
                                .where((e) => e.cat != item.cat)
                                .toList();
                            final pair = others[i % others.length];
                            return SizedBox(
                              width: 80,
                              child: Swatch(item: pair, radius: 14),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: AccentButton(
                              label: 'Style this piece',
                              onTap: () => Navigator.of(context).pop(),
                              expand: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => state.toggleFav(item.id),
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: item.fav ? t.accentSoft : t.card,
                                border: Border.all(
                                    color: item.fav ? t.accent : t.line),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                item.fav ? Icons.favorite : Icons.favorite_border,
                                color: item.fav ? t.accent : t.ink2,
                                size: 21,
                              ),
                            ),
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
