import 'package:flutter/foundation.dart';

import '../../domain/weather/snowfall_forecast.dart';
import '../../domain/weather/weather_forecast_repository.dart';

/// Static stand-in for demo/non-Firebase builds - there's no Cloud Functions
/// snapshot to read, so this just keeps showing the forecast the home
/// screen hero originally shipped with.
class DemoWeatherForecastRepository extends ChangeNotifier
    implements WeatherForecastRepository {
  @override
  SnowfallForecast get forecast => SnowfallForecast.demo;
}
