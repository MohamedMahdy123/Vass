import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/item.dart';
import '../services/outfit_engine.dart';
import '../state/outfit_state.dart';
import '../state/planner_state.dart';
import '../state/reminder_service.dart';
import '../state/wardrobe_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/item_image.dart';

/// Opens the Smart Outfit Scheduler. Pick a date + occasion + weather, let the
/// stylist assemble a look from the real closet, then schedule it — which saves
/// the look, plans it on the calendar, and sets a reminder notification.
Future<void> showSchedulerSheet(BuildContext context, {DateTime? initialDate}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SchedulerSheet(initialDate: initialDate),
  );
}

/// Display occasion -> the engine's occasion register.
const _occasions = <String, String>{
  'Work Meeting': 'Work',
  'Dinner Date': 'Smart',
  'Wedding': 'Formal',
  'Formal Event': 'Formal',
  'Casual Hangout': 'Casual',
  'Weekend': 'Casual',
};

const _weatherOptions = ['Auto', 'Warm', 'Mild', 'Cold'];
const _reminderOptions = ['Night before', 'Morning of'];

class _SchedulerSheet extends StatefulWidget {
  const _SchedulerSheet({this.initialDate});
  final DateTime? initialDate;

  @override
  State<_SchedulerSheet> createState() => _SchedulerSheetState();
}

class _SchedulerSheetState extends State<_SchedulerSheet> {
  late DateTime _date;
  String _occasion = 'Work Meeting';
  String _weather = 'Auto';
  String _reminder = 'Night before';
  int _seed = 0;
  List<Item>? _look; // generated preview
  bool _generating = false;

  static const _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final base = widget.initialDate ?? now.add(const Duration(days: 1));
    _date = DateTime(base.year, base.month, base.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WardrobeState>().load();
      // Warm up notification permissions on platforms that support them.
      context.read<ReminderService>().init();
    });
  }

  /// The engine weather string for the chosen option; 'Auto' derives from the
  /// date's month (northern-hemisphere seasons) as an honest expected default.
  String? get _engineWeather {
    switch (_weather) {
      case 'Warm':
        return 'Warm';
      case 'Cold':
        return 'Cold';
      case 'Mild':
        return 'Mild';
      default:
        final m = _date.month;
        if (m == 12 || m <= 2) return 'Cold';
        if (m >= 6 && m <= 8) return 'Warm';
        return 'Mild';
    }
  }

  String get _dateLabel {
    final wd = _weekdaysShort[(_date.weekday - 1).clamp(0, 6)];
    return '$wd, ${_monthsShort[_date.month - 1]} ${_date.day}';
  }

  void _generate() {
    final wardrobe = context.read<WardrobeState>().items;
    setState(() => _generating = true);
    final look = OutfitEngine.build(
      wardrobe,
      occasion: _occasions[_occasion],
      weather: _engineWeather,
      seed: _seed,
    );
    final items = look == null
        ? <Item>[]
        : look.itemIds
            .map((id) => wardrobe.firstWhere((i) => i.id == id,
                orElse: () => wardrobe.first))
            .toList();
    setState(() {
      _look = items;
      _generating = false;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
        _look = null; // date changed -> regenerate for the new weather
      });
    }
  }

  DateTime get _reminderTime => _reminder == 'Morning of'
      ? DateTime(_date.year, _date.month, _date.day, 7)
      : DateTime(_date.year, _date.month, _date.day, 20)
          .subtract(const Duration(days: 1));

  Future<void> _schedule() async {
    final items = _look;
    if (items == null || items.isEmpty) return;

    final outfits = context.read<OutfitState>();
    final planner = context.read<PlannerState>();
    final reminders = context.read<ReminderService>();

    // 1. Save the generated look. 2. Plan it on the date. 3. Set the reminder.
    final id = outfits.saveLook(
      items: items,
      title: '$_occasion · $_dateLabel',
      occasion: _occasions[_occasion],
    );
    if (id == null) return;
    planner.plan(_date, id);

    final when = _reminderTime;
    final os = await reminders.schedule(
      id: PlannerState.keyFor(_date).hashCode & 0x7fffffff,
      when: when,
      occasion: _occasion,
      dateLabel: _dateLabel,
      title: 'Outfit ready for your ${_occasion.toLowerCase()}',
      body: 'Your look for $_dateLabel is planned. Tap to see it.',
    );

    if (!mounted) return;
    final t = context.vess;
    Navigator.of(context).maybePop();
    final msg = os
        ? 'Scheduled — you\'ll be reminded ${_reminder.toLowerCase()}.'
        : reminders.osSupported
            ? 'Planned for $_dateLabel. (Reminder time already passed.)'
            : 'Planned for $_dateLabel. Reminders fire on the mobile app.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: t.ink,
        content: Text(msg, style: TextStyle(fontFamily: kSans, color: t.bg)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(VessRadius.lg)),
        ),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
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
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 20, color: t.accent),
                  const SizedBox(width: 10),
                  Text('Schedule an outfit', style: serif(context, 24)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Plan a look for a day ahead and get reminded.',
                  style: TextStyle(
                      fontFamily: kSans,
                      fontSize: VessType.bodySm,
                      color: t.ink3)),
              const SizedBox(height: 20),

              _label(t, 'DATE'),
              _dateRow(t),
              const SizedBox(height: 18),

              _label(t, 'OCCASION'),
              _chips(_occasions.keys.toList(), _occasion,
                  (v) => setState(() {
                        _occasion = v;
                        _look = null;
                      })),
              const SizedBox(height: 18),

              _label(t, 'WEATHER'),
              _chips(_weatherOptions, _weather, (v) => setState(() {
                    _weather = v;
                    _look = null;
                  })),
              const SizedBox(height: 18),

              _label(t, 'REMIND ME'),
              _chips(_reminderOptions, _reminder,
                  (v) => setState(() => _reminder = v)),
              const SizedBox(height: 22),

              _preview(t),
              const SizedBox(height: 20),

              if (_look == null || _look!.isEmpty)
                AccentButton(
                  label: _generating ? 'Styling…' : 'Generate outfit',
                  expand: true,
                  trailing: Icons.auto_awesome,
                  onTap: _generating ? null : _generate,
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _seed++;
                          _generate();
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          side: BorderSide(color: t.line),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(VessRadius.md)),
                        ),
                        child: Text('Regenerate',
                            style: TextStyle(
                                fontFamily: kSans,
                                fontSize: VessType.body,
                                fontWeight: FontWeight.w600,
                                color: t.ink2)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AccentButton(
                        label: 'Schedule',
                        expand: true,
                        trailing: Icons.notifications_active_outlined,
                        onTap: _schedule,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateRow(dynamic t) {
    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(VessRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(VessRadius.sm),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 18, color: t.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_dateLabel,
                    style: TextStyle(
                        fontFamily: kSans,
                        fontSize: VessType.body,
                        fontWeight: FontWeight.w600,
                        color: t.ink)),
              ),
              Text('Change',
                  style: TextStyle(
                      fontFamily: kSans,
                      fontSize: VessType.label,
                      fontWeight: FontWeight.w600,
                      color: t.accent)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(dynamic t) {
    if (_look == null) {
      return Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: t.bg2,
          borderRadius: BorderRadius.circular(VessRadius.md),
          border: Border.all(color: t.line),
        ),
        alignment: Alignment.center,
        child: Text('Your styled look will appear here',
            style: TextStyle(
                fontFamily: kSans, fontSize: VessType.bodySm, color: t.ink3)),
      );
    }
    if (_look!.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: t.bg2,
          borderRadius: BorderRadius.circular(VessRadius.md),
          border: Border.all(color: t.line),
        ),
        child: Column(
          children: [
            Icon(Icons.checkroom_outlined, size: 30, color: t.ink3),
            const SizedBox(height: 10),
            Text("Couldn't assemble a full look for that",
                style: TextStyle(
                    fontFamily: kSans, fontSize: VessType.bodySm, color: t.ink2)),
            const SizedBox(height: 4),
            Text('Add a few more pieces to your closet, or loosen the weather.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: kSans, fontSize: VessType.caption, color: t.ink3)),
          ],
        ),
      );
    }
    // Ghost-mannequin flat-lay: the pieces stacked head-to-toe, transparent.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(VessRadius.md),
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          for (final item in _look!.take(5))
            SizedBox(height: 96, child: ItemImage(item: item, radius: 12)),
          const SizedBox(height: 6),
          Text('${_look!.length} pieces · ${_occasion.toLowerCase()}',
              style: TextStyle(
                  fontFamily: kSans, fontSize: VessType.caption, color: t.ink3)),
        ],
      ),
    );
  }

  Widget _label(dynamic t, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: eyebrow(t.ink3, size: 10.5).copyWith(letterSpacing: 1.2)),
      );

  Widget _chips(List<String> options, String selected, ValueChanged<String> onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          VessChip(label: o, active: selected == o, onTap: () => onPick(o)),
      ],
    );
  }
}
