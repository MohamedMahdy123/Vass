import 'dart:convert';

import 'package:http/http.dart' as http;

/// A resolved forecast for a specific day, mapped to the outfit engine's
/// weather vocabulary (Hot / Warm / Mild / Cold).
class WeatherReading {
  const WeatherReading({
    required this.engineWeather,
    required this.tempC,
    this.city,
    this.rain = false,
  });

  final String engineWeather; // 'Hot' | 'Warm' | 'Mild' | 'Cold'
  final double tempC; // mid of the day's max/min
  final String? city;
  final bool rain; // high precipitation chance

  String get short {
    final t = '${tempC.round()}°';
    final where = (city == null || city!.isEmpty) ? '' : '$city · ';
    final wet = rain ? ' · rain likely' : '';
    return '$where$t · $engineWeather$wet';
  }

  /// Weather string for the outfit engine — carries the rain signal so the
  /// engine can nudge outerwear even when it isn't cold.
  String get weatherForEngine => rain ? '$engineWeather rain' : engineWeather;
}

class _Loc {
  const _Loc(this.lat, this.lon, this.city);
  final double lat;
  final double lon;
  final String? city;
}

/// Real weather by location — 100% free, no API key.
///
/// Location: IP geolocation (ipwho.is) — no GPS permission, works on web and
/// mobile. Forecast: Open-Meteo (no key), fetched for the *target date* so the
/// scheduler dresses for that day, not today. Open-Meteo covers ~16 days ahead;
/// beyond that (or on any failure) this returns null and the caller falls back
/// to a season-by-month estimate.
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _timeout = Duration(seconds: 8);

  /// Latitude from the last successful location lookup (any this session).
  /// Lets the seasonal fallback flip hemisphere even when the forecast call
  /// itself failed or the date was out of range.
  double? lastLat;

  /// Map a temperature (°C) to the engine's weather register.
  static String weatherFromTemp(double c) {
    if (c >= 24) return 'Hot';
    if (c >= 17) return 'Warm';
    if (c >= 10) return 'Mild';
    return 'Cold';
  }

  /// Hemisphere-aware season-by-month estimate — the fallback when there's no
  /// live forecast (offline, or the date is beyond the ~16-day range). Southern
  /// hemisphere (lat < 0) has its seasons flipped; unknown latitude assumes
  /// northern.
  static String seasonalWeather(DateTime date, {double? lat}) {
    final south = (lat ?? 0) < 0;
    final m = date.month;
    final decFeb = m == 12 || m <= 2;
    final junAug = m >= 6 && m <= 8;
    final isWinter = south ? junAug : decFeb;
    final isSummer = south ? decFeb : junAug;
    if (isWinter) return 'Cold';
    if (isSummer) return 'Warm';
    return 'Mild';
  }

  Future<WeatherReading?> forecastFor(DateTime date) async {
    try {
      final loc = await _location();
      if (loc == null) return null;

      final d = _ymd(date);
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${loc.lat}&longitude=${loc.lon}'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max'
        '&timezone=auto&start_date=$d&end_date=$d',
      );
      final res = await _client.get(url).timeout(_timeout);
      if (res.statusCode != 200) return null; // e.g. date beyond forecast range

      final daily = (jsonDecode(res.body) as Map)['daily'];
      if (daily is! Map) return null;
      final tmax = _firstNum(daily['temperature_2m_max']);
      final tmin = _firstNum(daily['temperature_2m_min']);
      if (tmax == null || tmin == null) return null;
      final mid = (tmax + tmin) / 2;
      final pop = _firstNum(daily['precipitation_probability_max']) ?? 0;

      return WeatherReading(
        engineWeather: weatherFromTemp(mid),
        tempC: mid,
        city: loc.city,
        rain: pop >= 50,
      );
    } catch (_) {
      return null; // best-effort — caller uses a seasonal estimate
    }
  }

  Future<_Loc?> _location() async {
    final res =
        await _client.get(Uri.parse('https://ipwho.is/')).timeout(_timeout);
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map;
    if (j['success'] == false) return null;
    final lat = (j['latitude'] as num?)?.toDouble();
    final lon = (j['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    lastLat = lat; // remembered for the hemisphere-aware seasonal fallback
    return _Loc(lat, lon, j['city'] as String?);
  }

  static double? _firstNum(dynamic list) {
    if (list is List && list.isNotEmpty && list.first is num) {
      return (list.first as num).toDouble();
    }
    return null;
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
