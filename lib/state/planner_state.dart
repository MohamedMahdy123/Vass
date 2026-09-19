import 'package:flutter/foundation.dart';

import '../core/supabase_service.dart';
import '../data/outfits_repository.dart';
import 'outfit_state.dart';

/// The outfit calendar: which saved look is planned for each day. Demo-first —
/// plans live in memory (seeded so the calendar isn't empty), and round-trip to
/// Postgres when signed in. A plan only persists to the cloud when its outfit
/// is a real saved row (uuid); demo/temp outfit ids stay in memory.
class PlannerState extends ChangeNotifier {
  final _repo = OutfitsRepository();
  final Map<String, String> _plans = {}; // 'yyyy-MM-dd' -> outfit id
  bool _seeded = false;
  bool _loaded = false;

  bool get _isLive =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  static String keyFor(DateTime d) {
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// The outfit id planned for [day], or null.
  String? outfitIdFor(DateTime day) => _plans[keyFor(day)];

  int get plannedCount => _plans.length;

  /// Load plans from the cloud when signed in, else seed a couple of demo plans
  /// on upcoming days so the calendar shows something.
  Future<void> load(List<SavedOutfit> outfits) async {
    if (!_isLive) {
      _seed(outfits);
      return;
    }
    if (_loaded) return;
    _loaded = true;
    try {
      final plans = await _repo.listPlans();
      _plans
        ..clear()
        ..addAll(plans);
      notifyListeners();
    } catch (_) {
      _loaded = false;
    }
  }

  void _seed(List<SavedOutfit> outfits) {
    if (_seeded || outfits.isEmpty) return;
    _seeded = true;
    final now = DateTime.now();
    // Plan the first couple of saved looks onto the next few days.
    final picks = outfits.take(2).toList();
    for (var i = 0; i < picks.length; i++) {
      _plans[keyFor(now.add(Duration(days: i + 1)))] = picks[i].id;
    }
    if (_plans.isNotEmpty) notifyListeners();
  }

  /// Plan [outfitId] for [day] (replaces any existing plan on that day).
  void plan(DateTime day, String outfitId) {
    final key = keyFor(day);
    _plans[key] = outfitId;
    notifyListeners();
    if (_isLive && _isPersisted(outfitId)) {
      _repo.setPlan(key, outfitId).catchError((_) {});
    }
  }

  void clear(DateTime day) {
    final key = keyFor(day);
    if (_plans.remove(key) == null) return;
    notifyListeners();
    if (_isLive) _repo.clearPlan(key).catchError((_) {});
  }

  /// Only real saved-outfit rows carry a uuid; demo ('seed-') and just-saved
  /// ('look-') ids never hit the backend.
  bool _isPersisted(String outfitId) =>
      !outfitId.startsWith('seed-') && !outfitId.startsWith('look-');
}
