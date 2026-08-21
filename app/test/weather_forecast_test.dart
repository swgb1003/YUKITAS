import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/app/mode_shell.dart';
import 'package:yukitas/domain/weather/snowfall_forecast.dart';
import 'package:yukitas/domain/weather/weather_forecast_repository.dart';
import 'package:yukitas/infrastructure/requests/in_memory_request_repository.dart';

class _FakeWeatherForecastRepository extends ChangeNotifier
    implements WeatherForecastRepository {
  _FakeWeatherForecastRepository(this._forecast);

  final SnowfallForecast _forecast;

  @override
  SnowfallForecast get forecast => _forecast;
}

void main() {
  testWidgets('home screen shows the real forecast instead of the '
      'placeholder 30cm/-2℃ demo values', (tester) async {
    final requestRepository = InMemoryRequestRepository(seedRequests: const []);
    addTearDown(requestRepository.dispose);
    final weatherRepository = _FakeWeatherForecastRepository(
      const SnowfallForecast(temperatureC: 1, expectedSnowfallCm: 5),
    );
    addTearDown(weatherRepository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ModeShell(
          repository: requestRepository,
          weatherForecastRepository: weatherRepository,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('明朝、5cmの降雪予報です'), findsOneWidget);
    expect(find.text('明朝、30cmの降雪予報です'), findsNothing);
  });

  test('isHeavySnowWarning matches the family-notification threshold', () {
    const light = SnowfallForecast(temperatureC: 0, expectedSnowfallCm: 10);
    const heavy = SnowfallForecast(temperatureC: -3, expectedSnowfallCm: 25);

    expect(light.isHeavySnowWarning, isFalse);
    expect(heavy.isHeavySnowWarning, isTrue);
  });
}
