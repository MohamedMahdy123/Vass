import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'closet_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'stylist_screen.dart';
import 'tryon_screen.dart';

class _Tab {
  const _Tab(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// The five-tab container. The bar floats over the content on a blurred,
/// translucent surface (`--tab`), matching the design.
class Shell extends StatefulWidget {
  const Shell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<Shell> createState() => ShellState();

  /// Lets a nested screen switch tabs (e.g. "Open builder" from home).
  static ShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<ShellState>();
}

class ShellState extends State<Shell> {
  late int _index = widget.initialIndex;

  void goTo(int index) => setState(() => _index = index);

  static const _tabs = [
    _Tab(Icons.home_outlined, 'Home'),
    _Tab(Icons.grid_view_outlined, 'Closet'),
    _Tab(Icons.checkroom_outlined, 'Try On'),
    _Tab(Icons.chat_bubble_outline, 'Stylist'),
    _Tab(Icons.person_outline, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.vess;

    return Scaffold(
      backgroundColor: t.bg,
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          ClosetScreen(),
          TryOnScreen(),
          StylistScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: t.tab,
              border: Border(top: BorderSide(color: t.line)),
            ),
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  final active = i == _index;

                  return Expanded(
                    child: InkWell(
                      key: ValueKey('tab-${tab.label}'),
                      onTap: () => goTo(i),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tab.icon,
                                size: 21, color: active ? t.ink : t.ink3),
                            const SizedBox(height: 4),
                            Text(
                              tab.label,
                              style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: active ? t.ink : t.ink3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
