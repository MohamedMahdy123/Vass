import 'package:flutter_test/flutter_test.dart';
import 'package:vess/services/weather_service.dart';

void main() {
  group('WeatherService.weatherFromTemp', () {
    test('maps temperature to the engine weather register', () {
      expect(WeatherService.weatherFromTemp(30), 'Hot');
      expect(WeatherService.weatherFromTemp(24), 'Hot');
      expect(WeatherService.weatherFromTemp(20), 'Warm');
      expect(WeatherService.weatherFromTemp(17), 'Warm');
      expect(WeatherService.weatherFromTemp(12), 'Mild');
      expect(WeatherService.weatherFromTemp(10), 'Mild');
      expect(WeatherService.weatherFromTemp(5), 'Cold');
      expect(WeatherService.weatherFromTemp(-3), 'Cold');
    });
  });

  group('WeatherService.seasonalWeather (hemisphere-aware)', () {
    final jan = DateTime(2026, 1, 15);
    final jul = DateTime(2026, 7, 15);
    test('northern hemisphere (or unknown) uses standard seasons', () {
      expect(WeatherService.seasonalWeather(jan, lat: 51), 'Cold');
      expect(WeatherService.seasonalWeather(jul, lat: 51), 'Warm');
      expect(WeatherService.seasonalWeather(jan), 'Cold'); // unknown -> northern
    });
    test('southern hemisphere flips summer/winter', () {
      expect(WeatherService.seasonalWeather(jan, lat: -33), 'Warm'); // Sydney summer
      expect(WeatherService.seasonalWeather(jul, lat: -33), 'Cold'); // Sydney winter
    });
  });
}
