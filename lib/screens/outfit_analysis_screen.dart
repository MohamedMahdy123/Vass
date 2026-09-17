import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/item.dart';
import '../state/outfit_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/item_image.dart';

/// The AI outfit read-out: colour harmony, the Vess AI Score, style-match tags
/// and a short written analysis. Runs on a local, explainable heuristic so it
/// works without an AI key. Analyses the current canvas unless [items] is given
/// (e.g. opened from a saved look).
class OutfitAnalysisScreen extends StatelessWidget {
  const OutfitAnalysisScreen({super.key, this.items, this.title});

  final List<Item>? items;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final state = context.watch<OutfitState>();
    final pieces = items ?? state.canvasItems;
    final a = state.analyze(pieces);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: VessBackButton(),
        ),
        title: Text('Outfit Analysis', style: serif(context, 22)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Preview(items: pieces),
              const SizedBox(width: 16),
              Expanded(child: _HarmonyCard(percent: a.colorHarmony, score: a.score)),
            ],
          ),
          const SizedBox(height: 16),
          VessCard(
            radius: 20,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STYLE MATCH',
                    style: eyebrow(t.ink3, size: 10.5).copyWith(letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final tag in a.styleTags) _StyleTag(label: tag)],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          VessCard(
            radius: 20,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ANALYSIS',
                    style: eyebrow(t.ink3, size: 10.5).copyWith(letterSpacing: 1.2)),
                const SizedBox(height: 10),
                Text(a.text,
                    style: TextStyle(
                        fontFamily: kSans, fontSize: 14.5, height: 1.55, color: t.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.items});
  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final show = items.take(4).toList();
    return Container(
      width: 128,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          for (final i in show)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: SizedBox(height: 56, child: ItemImage(item: i, radius: 10)),
            ),
        ],
      ),
    );
  }
}

class _HarmonyCard extends StatelessWidget {
  const _HarmonyCard({required this.percent, required this.score});
  final int percent;
  final int score;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return VessCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('AI COLOUR HARMONY',
              style: eyebrow(t.ink3, size: 9.5).copyWith(letterSpacing: 1.0)),
          const SizedBox(height: 14),
          SizedBox(
            width: 108,
            height: 108,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 108,
                  height: 108,
                  child: CircularProgressIndicator(
                    value: percent / 100,
                    strokeWidth: 9,
                    backgroundColor: t.line,
                    valueColor: AlwaysStoppedAnimation(t.accent),
                  ),
                ),
                Text('$percent%',
                    style: TextStyle(
                        fontFamily: kSerif, fontSize: 26, color: t.ink)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_outlined, size: 16, color: t.accent),
              const SizedBox(width: 6),
              Text('$score/100',
                  style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.ink)),
            ],
          ),
          Text('Vess AI Score',
              style: TextStyle(fontFamily: kSans, fontSize: 11.5, color: t.ink3)),
        ],
      ),
    );
  }
}

class _StyleTag extends StatelessWidget {
  const _StyleTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final l = label.toLowerCase();
    IconData icon = Icons.style_outlined;
    if (l.contains('warm')) {
      icon = Icons.wb_sunny_outlined;
    } else if (l.contains('cool') || l.contains('cold')) {
      icon = Icons.ac_unit;
    } else if (l.contains('refined') || l.contains('elegance')) {
      icon = Icons.diamond_outlined;
    } else if (l.contains('work')) {
      icon = Icons.work_outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: t.accentSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: t.accent),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.accent)),
        ],
      ),
    );
  }
}
