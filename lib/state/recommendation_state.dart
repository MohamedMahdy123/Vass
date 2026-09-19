import 'package:flutter/foundation.dart';

import '../core/supabase_service.dart';
import '../data/models/item.dart';
import '../data/models/outfit.dart';
import '../data/outfits_repository.dart';
import '../services/outfit_engine.dart';
import '../services/recommendation_service.dart';
import '../services/weather_service.dart';

/// Drives "What should I wear today?" — asks the recommender for a look from the
/// user's own wardrobe, shows the "why", and turns accept/reject into learning.
///
/// It doesn't own the wardrobe; the caller passes the current items in (from
/// [WardrobeState]), keeping this the single place recommendation logic lives.
class RecommendationState extends ChangeNotifier {
  final _service = RecommendationService();
  final _repo = OutfitsRepository();
  final _weatherSvc = WeatherService();

  /// Below this, a look can't be coherent — nudge the user to add pieces first.
  static const minItems = 4;

  OutfitSuggestion? _today;
  List<Item> _todayItems = const [];
  bool _generating = false;
  String? _error;
  String _occasion = 'Everyday';
  String _weather = 'Mild';
  int _seed = 0;

  // Live weather: today's forecast for the user's location. Used automatically
  // unless the user manually overrides the weather.
  WeatherReading? _forecast;
  bool _weatherManual = false;
  WeatherReading? get forecast => _forecast;

  // Demo-mode learning: rejected pieces we shouldn't suggest again this session.
  final Set<String> _dislikedDemo = {};

  OutfitSuggestion? get today => _today;
  List<Item> get todayItems => List.unmodifiable(_todayItems);
  bool get generating => _generating;
  String? get error => _error;
  String get occasion => _occasion;
  String get weather => _weather;
  bool get hasOutfit => _today != null;

  bool get isLive =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  void setOccasion(String o) {
    if (o == _occasion) return;
    _occasion = o;
    notifyListeners();
  }

  void setWeather(String w) {
    _weatherManual = true; // user override — stop auto-applying the forecast
    if (w == _weather) return;
    _weather = w;
    notifyListeners();
  }

  /// Fetch today's forecast for the user's location and adopt it as the weather
  /// (unless the user has manually chosen one). Best-effort; silent on failure.
  /// Cached for the session so regenerating doesn't refetch.
  Future<void> _applyForecast() async {
    if (_weatherManual || _forecast != null) return;
    final f = await _weatherSvc.forecastFor(DateTime.now());
    if (f == null) return;
    _forecast = f;
    _weather = f.weatherForEngine; // carries the rain signal for the engine
  }

  /// Generate a fresh look for the current occasion/weather from [wardrobe].
  Future<void> generate(List<Item> wardrobe) async {
    if (_generating) return;
    if (wardrobe.length < minItems) {
      _today = null;
      _todayItems = const [];
      _error = null;
      notifyListeners();
      return;
    }

    _generating = true;
    _error = null;
    notifyListeners();

    // Make today's pick weather-aware from the real forecast.
    await _applyForecast();

    try {
      final suggestion = await _service.recommend(
        wardrobe,
        occasion: _occasion,
        weather: _weather,
        dislikedIds: _dislikedDemo,
        seed: _seed,
      );
      if (suggestion == null) {
        _today = null;
        _todayItems = const [];
        _error = "Couldn't build a full look from your closet yet.";
      } else {
        _today = suggestion;
        _todayItems = _resolve(suggestion.itemIds, wardrobe);
      }
    } catch (_) {
      _error = "Couldn't reach your stylist. Try again.";
    } finally {
      _generating = false;
      notifyListeners();
    }
  }

  /// "Try again" — a different valid look for the same context.
  Future<void> tryAgain(List<Item> wardrobe) {
    _seed++;
    return generate(wardrobe);
  }

  /// The user is wearing it: persist as accepted, bump wear counts, and learn
  /// the pairing. Then clear the card.
  Future<void> accept(List<Item> wardrobe) async {
    final outfit = _today;
    if (outfit == null) return;

    if (isLive) {
      try {
        await _repo.save(
          outfit.copyWith(status: OutfitStatus.accepted),
          slotFor: _slotLabels(_todayItems),
        );
        await _repo.markWorn(_todayItems);
        await _repo.learn(likedPairing: outfit.itemIds);
      } catch (e) {
        _error = "Saved locally, but couldn't sync. It'll retry.";
      }
    }
    _today = null;
    _todayItems = const [];
    notifyListeners();
  }

  /// Not today: record the dislike so we steer away, then offer another look.
  Future<void> reject(List<Item> wardrobe) async {
    final outfit = _today;
    if (outfit == null) return;

    // Learn from the anchor piece (top or dress), not shoes/accessories, so a
    // single "no" doesn't blacklist a neutral staple.
    final anchorId = _anchorId(_todayItems);
    if (anchorId != null) _dislikedDemo.add(anchorId);

    if (isLive) {
      try {
        await _repo.save(outfit.copyWith(status: OutfitStatus.rejected));
        if (anchorId != null) await _repo.learn(addDisliked: [anchorId]);
      } catch (_) {/* non-fatal */}
    }
    await tryAgain(wardrobe);
  }

  List<Item> _resolve(List<String> ids, List<Item> wardrobe) {
    final byId = {for (final i in wardrobe) i.id: i};
    return ids
        .map((id) => byId[id])
        .where((i) => i != null)
        .cast<Item>()
        .toList();
  }

  String? _anchorId(List<Item> items) {
    for (final i in items) {
      final slot = OutfitEngine.slotOf(i);
      if (slot == 'Dress' || slot == 'Tops') return i.id;
    }
    return items.isEmpty ? null : items.first.id;
  }

  Map<String, String> _slotLabels(List<Item> items) {
    const label = {
      'Tops': 'Top',
      'Bottoms': 'Bottom',
      'Footwear': 'Shoes',
      'Outerwear': 'Outerwear',
      'Accessories': 'Accessory',
      'Dress': 'Dress',
    };
    return {
      for (final i in items) i.id: label[OutfitEngine.slotOf(i)] ?? 'Piece',
    };
  }
}
