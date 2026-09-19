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
}
