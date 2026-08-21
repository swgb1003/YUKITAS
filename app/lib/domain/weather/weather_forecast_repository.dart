import 'package:flutter/foundation.dart';

import 'snowfall_forecast.dart';

abstract interface class WeatherForecastRepository implements Listenable {
  SnowfallForecast get forecast;
}
