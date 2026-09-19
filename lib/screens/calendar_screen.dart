import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/outfit_state.dart';
import '../state/planner_state.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/item_image.dart';
import 'scheduler_sheet.dart';

/// The outfit calendar — plan a saved look onto any day, see the month at a
/// glance, and open the day to view or change what's planned. Backed by
/// [PlannerState] (demo-first, cloud-persisted when signed in).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  late DateTime _month; // first of the visible month
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final w = context.read<WardrobeState>();
      await w.load();
      if (!mounted) return;
      final outfits = context.read<OutfitState>();
      await outfits.load(w.items);
      if (!mounted) return;
      await context.read<PlannerState>().load(outfits.saved);
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  SavedOutfit? _lookup(List<SavedOutfit> list, String? id) {
    if (id == null) return null;
    for (final o in list) {
      if (o.id == id) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final planner = context.watch<PlannerState>();
    final outfits = context.watch<OutfitState>().saved;
    final plannedId = planner.outfitIdFor(_selected);
    final plannedLook = _lookup(outfits, plannedId);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: VessBackButton(),
        ),
        title: Text('Calendar', style: serif(context, 22)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Schedule an outfit',
            icon: Icon(Icons.auto_awesome, color: t.accent),
            onPressed: () => showSchedulerSheet(context, initialDate: _selected),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          _monthHeader(context, planner),
          const SizedBox(height: 14),
          _weekdayRow(t),
          const SizedBox(height: 6),
          _grid(context, planner),
          const SizedBox(height: 24),
          _dayPanel(context, plannedLook, outfits),
        ],
      ),
    );
  }

  Widget _monthHeader(BuildContext context, PlannerState planner) {
    final t = context.vess;
    return Row(
      children: [
        Expanded(
          child: Text('${_months[_month.month - 1]} ${_month.year}',
              style: serif(context, 22)),
        ),
        _navBtn(t, Icons.chevron_left,
            () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
        const SizedBox(width: 8),
        _navBtn(t, Icons.chevron_right,
            () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
      ],
    );
  }

  Widget _navBtn(dynamic t, IconData icon, VoidCallback onTap) {
    return Material(
      color: t.card,
      shape: CircleBorder(side: BorderSide(color: t.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
            width: 38, height: 38, child: Icon(icon, size: 20, color: t.ink)),
      ),
    );
  }

  Widget _weekdayRow(dynamic t) {
    return Row(
      children: [
        for (final d in _weekdayLabels)
          Expanded(
            child: Center(
              child: Text(d,
                  style: eyebrow(t.ink3, size: 11).copyWith(letterSpacing: 0.5)),
            ),
          ),
      ],
    );
  }

  Widget _grid(BuildContext context, PlannerState planner) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = DateTime(_month.year, _month.month, 1).weekday - 1; // Mon=0
    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_month.year, _month.month, day);
      cells.add(_dayCell(context, date, planner));
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: cells,
    );
  }

  Widget _dayCell(BuildContext context, DateTime date, PlannerState planner) {
    final t = context.vess;
    final selected = _sameDay(date, _selected);
    final today = _sameDay(date, DateTime.now());
    final planned = planner.outfitIdFor(date) != null;

    return Material(
      color: selected ? t.accent : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: today && !selected
            ? BorderSide(color: t.accent.withOpacity(0.5))
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selected = date),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${date.day}',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : t.ink,
                )),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: planned
                    ? (selected ? Colors.white : t.accent)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayPanel(
      BuildContext context, SavedOutfit? look, List<SavedOutfit> outfits) {
    final t = context.vess;
    final label = _sameDay(_selected, DateTime.now())
        ? 'Today'
        : '${_weekdayFull(_selected.weekday)}, ${_months[_selected.month - 1]} ${_selected.day}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: eyebrow(t.ink3, size: 11.5).copyWith(letterSpacing: 1.1)),
        const SizedBox(height: 12),
        if (look != null)
          _plannedCard(context, look)
        else
          _emptyDay(context, outfits),
      ],
    );
  }

  Widget _plannedCard(BuildContext context, SavedOutfit look) {
    final t = context.vess;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 72, height: 72, child: _collage(context, look)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(look.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: kSerif, fontSize: 17, color: t.ink)),
                    const SizedBox(height: 4),
                    Text('${look.tags.take(2).join('  ·  ')}  ·  ${look.score}/100',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: kSans, fontSize: 12, color: t.ink3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openPicker(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    side: BorderSide(color: t.line),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Change',
                      style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: t.ink2)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      context.read<PlannerState>().clear(_selected),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    side: BorderSide(color: t.line),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Clear',
                      style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: t.ink3)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyDay(BuildContext context, List<SavedOutfit> outfits) {
    final t = context.vess;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined, size: 32, color: t.ink3),
          const SizedBox(height: 10),
          Text('Nothing planned',
              style: TextStyle(fontFamily: kSans, fontSize: 14.5, color: t.ink2)),
          const SizedBox(height: 14),
          AccentButton(
            label: 'Schedule with AI',
            expand: true,
            trailing: Icons.auto_awesome,
            onTap: () => showSchedulerSheet(context, initialDate: _selected),
          ),
          if (outfits.isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _openPicker(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: t.line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Pick a saved look',
                  style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: t.ink2)),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text('Or build one on the Outfit Canvas and pick it here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: kSans, fontSize: 12, color: t.ink3)),
          ],
        ],
      ),
    );
  }

  void _openPicker(BuildContext context) {
    final outfits = context.read<OutfitState>().saved;
    if (outfits.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        final t = context.vess;
        return Container(
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: t.line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Plan a look', style: serif(context, 22)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: outfits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final o = outfits[i];
                    return _pickerRow(context, o);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pickerRow(BuildContext context, SavedOutfit o) {
    final t = context.vess;
    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.read<PlannerState>().plan(_selected, o.id);
          Navigator.of(context).maybePop();
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(width: 52, height: 52, child: _collage(context, o)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: kSerif, fontSize: 15.5, color: t.ink)),
                    const SizedBox(height: 2),
                    Text('${o.tags.take(2).join('  ·  ')}  ·  ${o.score}/100',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: kSans, fontSize: 11.5, color: t.ink3)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: t.ink3),
            ],
          ),
        ),
      ),
    );
  }

  /// A 2x2 collage of the look's pieces, matching the My Outfits card.
  Widget _collage(BuildContext context, SavedOutfit look) {
    final t = context.vess;
    final imgs = look.items.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.line),
      ),
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        children: [
          for (var k = 0; k < 4; k++)
            k < imgs.length
                ? ItemImage(item: imgs[k], radius: 6)
                : const SizedBox.shrink(),
        ],
      ),
    );
  }

  String _weekdayFull(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1).clamp(0, 6)];
  }
}
