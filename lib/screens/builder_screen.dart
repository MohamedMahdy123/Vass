import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/closet_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Outfit builder: four slots, filled from a bottom sheet or by "AI fill".
class BuilderScreen extends StatelessWidget {
  const BuilderScreen({super.key});

  void _openPicker(BuildContext context, String slot) {
    final state = context.read<AppState>();
    final t = context.vess;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.bg2,
      barrierColor: t.overlay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final options = state.optionsFor(slot);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Choose a ${slot.toLowerCase()}',
                    style: serif(context, 26)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final item = options[i];
                      return GestureDetector(
                        onTap: () {
                          state.pick(slot, item);
                          Navigator.of(sheetContext).pop();
                        },
                        child: SizedBox(
                          width: 112,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Swatch(item: item, radius: 16)),
                              const SizedBox(height: 8),
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
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final state = context.watch<AppState>();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 108),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Outfit builder', style: serif(context, 32)),
                    const SizedBox(height: 4),
                    Text(
                      '${state.outfitCount} of ${AppState.slots.length} slots filled',
                      style: TextStyle(
                          fontFamily: kSans, fontSize: 13.5, color: t.ink2),
                    ),
                  ],
                ),
              ),
              if (state.outfitCount > 0)
                TextButton(
                  onPressed: state.clearOutfit,
                  child: Text('Clear',
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: t.ink3,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.78,
            children: [
              for (final slot in AppState.slots)
                _Slot(
                  slot: slot,
                  item: state.outfit[slot],
                  onTap: () => _openPicker(context, slot),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.aiFill,
                  icon: Icon(Icons.auto_awesome, size: 18, color: t.accent),
                  label: Text('AI fill',
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.accent,
                      )),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: t.accentSoft,
                    side: BorderSide(color: t.accent.withOpacity(0.35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AccentButton(
                  label: 'Save outfit',
                  expand: true,
                  onTap: state.outfitCount == 0
                      ? null
                      : () {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                              backgroundColor: t.ink,
                              content: Text('Outfit saved',
                                  style: TextStyle(
                                      fontFamily: kSans, color: t.bg)),
                            ));
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.slot, required this.item, required this.onTap});

  final String slot;
  final ClosetItem? item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final filled = item != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: filled ? null : t.sand2,
          gradient: filled ? VessTokens.itemGradient(item!.a, item!.b) : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: filled ? Colors.transparent : t.line,
            // Empty slots read as a dashed-looking outline placeholder.
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(slot.toUpperCase(),
                style: eyebrow(
                  filled
                      ? (item!.isLight ? const Color(0xFF5A5348) : Colors.white70)
                      : t.ink3,
                  size: 10,
                ).copyWith(letterSpacing: 1.2)),
            const Spacer(),
            if (filled)
              Text(item!.name,
                  maxLines: 2,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: item!.isLight
                        ? const Color(0xFF2A2724)
                        : Colors.white,
                  ))
            else
              Row(
                children: [
                  Icon(Icons.add, size: 18, color: t.ink3),
                  const SizedBox(width: 6),
                  Text('Add',
                      style: TextStyle(
                          fontFamily: kSans, fontSize: 13, color: t.ink3)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
