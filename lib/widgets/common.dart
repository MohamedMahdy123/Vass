import 'package:flutter/material.dart';

import '../models/closet_item.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The gradient block that stands in for garment photography.
class Swatch extends StatelessWidget {
  const Swatch({super.key, required this.item, this.radius = 18, this.child});

  final ClosetItem item;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: VessTokens.itemGradient(item.a, item.b),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Rounded outline button used for back navigation across screens.
class VessBackButton extends StatelessWidget {
  const VessBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return InkWell(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: t.card,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.chevron_left, color: t.ink, size: 22),
      ),
    );
  }
}

/// Pill button in the accent colour, with the design's coloured drop shadow.
class AccentButton extends StatelessWidget {
  const AccentButton({
    super.key,
    required this.label,
    required this.onTap,
    this.trailing,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? trailing;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: t.accent.withOpacity(0.28),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: Colors.white,
          minimumSize: expand ? const Size.fromHeight(54) : null,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: kSans,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Flexible so a narrow (Expanded) button ellipsizes instead of
            // overflowing when the label + icon exceed the available width.
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 9),
              Icon(trailing, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

/// Selectable filter pill (categories, occasions).
class VessChip extends StatelessWidget {
  const VessChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: active ? t.ink : t.card,
          border: Border.all(color: active ? t.ink : t.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? t.bg : t.ink2,
          ),
        ),
      ),
    );
  }
}

/// Card surface used for every raised block in the app.
class VessCard extends StatelessWidget {
  const VessCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: t.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
