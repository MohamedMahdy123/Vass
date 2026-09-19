import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/closet_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// The pieces the user has loved (favourited). Backed by [AppState.wishlist] —
/// the same source the Profile "Loved" stat counts.
class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final items = context.watch<AppState>().wishlist;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: VessBackButton(),
        ),
        title: Text('Wishlist', style: serif(context, 22)),
        centerTitle: true,
      ),
      body: items.isEmpty
          ? _empty(context)
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 18,
                childAspectRatio: 0.78,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => _WishCard(item: items[i]),
            ),
    );
  }

  Widget _empty(BuildContext context) {
    final t = context.vess;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, size: 40, color: t.ink3),
            const SizedBox(height: 12),
            Text('Nothing loved yet',
                style: TextStyle(fontFamily: kSans, fontSize: 14.5, color: t.ink2)),
            const SizedBox(height: 6),
            Text('Tap the heart on pieces you love and they’ll gather here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: kSans, fontSize: 13, color: t.ink3)),
          ],
        ),
      ),
    );
  }
}

class _WishCard extends StatelessWidget {
  const _WishCard({required this.item});
  final ClosetItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              Positioned.fill(child: Swatch(item: item, radius: 20)),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: t.bg.withOpacity(0.9),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.read<AppState>().toggleFav(item.id),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(Icons.favorite, size: 17, color: t.accent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: kSerif, fontSize: 15.5, color: t.ink)),
        const SizedBox(height: 2),
        Text(item.brand,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: kSans, fontSize: 11.5, color: t.ink3)),
      ],
    );
  }
}
