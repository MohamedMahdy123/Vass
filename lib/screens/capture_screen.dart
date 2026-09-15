import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/models/item.dart';
import '../services/analysis_service.dart';
import '../services/background_removal_service.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

const _categories = ['Tops', 'Bottoms', 'Outerwear', 'Footwear', 'Accessories', 'Dresses', 'Other'];

/// Batch capture: pick several photos at once, let AI tag each in the
/// background, review + tweak the essentials, then add them all. This is the
/// low-friction onboarding the whole product bets on.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _picker = ImagePicker();
  final _analysis = AnalysisService();
  final _bgRemoval = BackgroundRemovalService();
  final List<_Draft> _drafts = [];
  bool _saving = false;

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final files = await _picker.pickMultiImage(imageQuality: 82, maxWidth: 1600);
    if (files.isEmpty) return;
    for (final f in files) {
      final bytes = await f.readAsBytes();
      final draft = _Draft(bytes);
      setState(() => _drafts.add(draft));
      _analyze(draft); // fire-and-forget; card shows progress
      _removeBg(draft); // fire-and-forget; swaps in the cut-out when ready
    }
  }

  Future<void> _analyze(_Draft d) async {
    try {
      final attrs = await _analysis.analyze(d.bytes);
      if (mounted) setState(() => d.apply(attrs));
    } catch (_) {
      if (mounted) setState(() => d.markFailed());
    }
  }

  Future<void> _removeBg(_Draft d) async {
    // Best-effort: a transparent cut-out if the engine is available, else the
    // original photo stands. Never blocks tagging or saving.
    final cut = await _bgRemoval.remove(d.bytes);
    if (cut != null && mounted) setState(() => d.processedBytes = cut);
  }

  void _remove(_Draft d) {
    setState(() => _drafts.remove(d));
    d.dispose();
  }

  Future<void> _saveAll() async {
    final ready = _drafts.where((d) => !d.analyzing).toList();
    if (ready.isEmpty) return;
    setState(() => _saving = true);
    final wardrobe = context.read<WardrobeState>();
    try {
      for (final d in ready) {
        await wardrobe.commitCaptured(d.toItem(), d.bytes);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text('Added ${ready.length} '
                '${ready.length == 1 ? 'piece' : 'pieces'} to your closet')));
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Could not save. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final anyAnalyzing = _drafts.any((d) => d.analyzing);
    final readyCount = _drafts.where((d) => !d.analyzing).length;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  const VessBackButton(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scan your closet', style: serif(context, 26)),
                        Text('Snap a few pieces — AI tags them for you.',
                            style: TextStyle(
                                fontFamily: kSans, fontSize: 13, color: t.ink3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _drafts.isEmpty
                  ? _empty(context)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: _drafts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _DraftCard(
                        draft: _drafts[i],
                        onRemove: () => _remove(_drafts[i]),
                        onChanged: () => setState(() {}),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pick,
                      icon: Icon(Icons.add_a_photo_outlined, size: 18, color: t.ink),
                      label: Text(_drafts.isEmpty ? 'Add photos' : 'More',
                          style: TextStyle(
                              fontFamily: kSans, fontWeight: FontWeight.w600, color: t.ink)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        side: BorderSide(color: t.line),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  if (_drafts.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: AccentButton(
                        label: _saving
                            ? 'Saving…'
                            : anyAnalyzing
                                ? 'Tagging…'
                                : 'Add $readyCount to closet',
                        expand: true,
                        onTap: (_saving || anyAnalyzing || readyCount == 0)
                            ? null
                            : _saveAll,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: t.accentSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.auto_awesome, size: 34, color: t.accent),
            ),
            const SizedBox(height: 20),
            Text('Add your first pieces', style: serif(context, 24)),
            const SizedBox(height: 8),
            Text(
              'Pick a handful of photos. Vess identifies each item — you just '
              'confirm. Ten pieces is enough to start.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: kSans, fontSize: 14, height: 1.5, color: t.ink2),
            ),
            const SizedBox(height: 24),
            AccentButton(label: 'Add photos', trailing: Icons.add_a_photo_outlined, onTap: _pick),
          ],
        ),
      ),
    );
  }
}

/// A single captured piece being reviewed.
class _Draft {
  _Draft(this.bytes);

  final Uint8List bytes;
  Uint8List? processedBytes; // transparent cut-out, when ready
  final name = TextEditingController();
  final color = TextEditingController();
  String category = 'Tops';
  String? subCategory, material, pattern, season, occasion, brand, colorSecondary;
  List<String> occasions = const [], seasons = const [], weatherTags = const [];
  bool analyzing = true;
  bool failed = false;

  static List<String> _list(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : const [];

  void apply(Map<String, dynamic> a) {
    name.text = (a['name'] as String?) ?? '';
    color.text = (a['color_primary'] ?? a['color']) as String? ?? '';
    final cat = a['category'] as String?;
    if (cat != null && _categories.contains(cat)) category = cat;
    subCategory = a['sub_category'] as String?;
    material = (a['fabric_type'] ?? a['material']) as String?;
    pattern = a['pattern'] as String?;
    brand = a['brand'] as String?;
    colorSecondary = a['color_secondary'] as String?;
    // Rich lists, with a fallback to the legacy single values.
    occasions = _list(a['occasions']);
    if (occasions.isEmpty && a['occasion'] != null) occasions = [a['occasion'] as String];
    seasons = _list(a['seasons']);
    if (seasons.isEmpty && a['season'] != null) seasons = [a['season'] as String];
    weatherTags = _list(a['weather_tags']);
    occasion = occasions.isNotEmpty ? occasions.first : a['occasion'] as String?;
    season = seasons.isNotEmpty ? seasons.first : a['season'] as String?;
    analyzing = false;
  }

  void markFailed() {
    analyzing = false;
    failed = true;
    if (name.text.isEmpty) name.text = 'New piece';
  }

  String get summary => [color.text, material, season, occasion]
      .where((s) => s != null && s.trim().isNotEmpty)
      .join(' · ');

  Item toItem() => Item(
        id: '',
        name: name.text.trim().isEmpty ? 'Untitled' : name.text.trim(),
        category: category,
        subCategory: subCategory,
        colorPrimary: color.text.trim().isEmpty ? null : color.text.trim(),
        colorSecondary: colorSecondary,
        fabricType: material,
        pattern: pattern,
        occasions: occasions,
        seasons: seasons,
        weatherTags: weatherTags,
        brand: brand,
        status: ItemStatus.reviewed,
        processedBytes: processedBytes,
        // legacy mirrors for any single-value reader
        color: color.text.trim().isEmpty ? null : color.text.trim(),
        season: season,
        occasion: occasion,
        material: material,
      );

  void dispose() {
    name.dispose();
    color.dispose();
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.draft, required this.onRemove, required this.onChanged});

  final _Draft draft;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;

    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(draft.bytes, width: 84, height: 108, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: draft.analyzing
                ? _analyzing(context)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: draft.name,
                          style: TextStyle(
                              fontFamily: kSans,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: t.ink),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            filled: true,
                            fillColor: t.sand2,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: t.line),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: t.accent),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in _categories)
                            _MiniChip(
                              label: c,
                              active: draft.category == c,
                              onTap: () {
                                draft.category = c;
                                onChanged();
                              },
                            ),
                        ],
                      ),
                      if (draft.summary.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Detected · ${draft.summary}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: kSans, fontSize: 11.5, color: t.ink3)),
                      ],
                    ],
                  ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.close, size: 18, color: t.ink3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyzing(BuildContext context) {
    final t = context.vess;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(t.accent)),
          ),
          const SizedBox(width: 10),
          Text('Tagging with AI…',
              style: TextStyle(fontFamily: kSans, fontSize: 13.5, color: t.ink2)),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? t.ink : t.card,
          border: Border.all(color: active ? t.ink : t.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 11.5,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? t.bg : t.ink2,
            )),
      ),
    );
  }
}
