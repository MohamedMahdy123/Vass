import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'calendar_screen.dart';
import 'history_screen.dart';
import 'shopping_screen.dart';
import 'splash_screen.dart';
import 'wishlist_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Route each wardrobe row to its (now real) destination.
  void _openMenu(BuildContext context, String title) {
    Widget? dest;
    if (title == 'Calendar') {
      dest = const CalendarScreen();
    } else if (title == 'Wishlist') {
      dest = const WishlistScreen();
    } else if (title == 'Shopping') {
      dest = const ShoppingScreen();
    } else if (title == 'History') {
      dest = const HistoryScreen();
    }
    if (dest != null) {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => dest!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final state = context.watch<AppState>();

    final menu = <List<Object>>[
      [Icons.calendar_today_outlined, 'Calendar', 'Plan looks ahead'],
      [Icons.favorite_border, 'Wishlist', '${state.wishlist.length} saved pieces'],
      [Icons.shopping_bag_outlined, 'Shopping', 'Gaps in your wardrobe'],
      [Icons.history, 'History', 'Everything you have worn'],
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 108),
        children: [
          Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: const Alignment(-0.8, -0.9),
                    end: const Alignment(0.8, 0.9),
                    colors: t.ob2,
                  ),
                ),
                alignment: Alignment.center,
                child: const Text('M',
                    style: TextStyle(
                        fontFamily: kSerif, fontSize: 28, color: Colors.white)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Maya Ellis', style: serif(context, 26)),
                    const SizedBox(height: 2),
                    Text('maya@studio.co',
                        style: TextStyle(
                            fontFamily: kSans, fontSize: 13.5, color: t.ink3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _Stat(value: '${state.closet.length}', label: 'Pieces')),
              const SizedBox(width: 10),
              Expanded(child: _Stat(value: '${state.wishlist.length}', label: 'Loved')),
              const SizedBox(width: 10),
              const Expanded(child: _Stat(value: '86', label: 'Score')),
            ],
          ),
          const SizedBox(height: 26),
          Text('APPEARANCE',
              style: eyebrow(t.ink3, size: 12.5).copyWith(letterSpacing: 1.25)),
          const SizedBox(height: 12),
          VessCard(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(state.isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    size: 20, color: t.accent),
                const SizedBox(width: 13),
                Expanded(
                  child: Text('Dark mode',
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: t.ink,
                      )),
                ),
                Switch(
                  value: state.isDark,
                  activeColor: Colors.white,
                  activeTrackColor: t.accent,
                  onChanged: state.setDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text('YOUR WARDROBE',
              style: eyebrow(t.ink3, size: 12.5).copyWith(letterSpacing: 1.25)),
          const SizedBox(height: 12),
          for (final m in menu) ...[
            VessCard(
              radius: 18,
              padding: const EdgeInsets.all(15),
              onTap: () => _openMenu(context, m[1] as String),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: t.sand2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(m[0] as IconData, size: 19, color: t.ink),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m[1] as String,
                            style: TextStyle(
                              fontFamily: kSans,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: t.ink,
                            )),
                        Text(m[2] as String,
                            style: TextStyle(
                                fontFamily: kSans, fontSize: 12, color: t.ink3)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: t.ink3, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () async {
                await context.read<AuthService>().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
                    (_) => false,
                  );
                }
              },
              child: Text(
                'Sign out',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: t.ink2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(value, style: serif(context, 26).copyWith(height: 1)),
          const SizedBox(height: 4),
          Text(label.toUpperCase(),
              style: eyebrow(t.ink3, size: 9.5).copyWith(letterSpacing: 1)),
        ],
      ),
    );
  }
}
