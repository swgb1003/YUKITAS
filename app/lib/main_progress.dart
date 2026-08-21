import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/mode_shell.dart';
import 'core/theme/yukitas_theme.dart';
import 'domain/requests/snow_request.dart';
import 'infrastructure/requests/in_memory_request_repository.dart';

void main() {
  final repository = InMemoryRequestRepository(
    seedRequests: [
      SnowRequest(
        id: 'demo-progress-001',
        ownerId: 'demo-owner-progress',
        placeName: '新潟の実家',
        approximateAddress: '新潟市中央区',
        latitude: 37.9161,
        longitude: 139.0364,
        workAreas: const ['玄関', '駐車場'],
        areaSqm: 18,
        snowDepthCm: 28,
        difficulty: 3,
        estimatedMinutes: 45,
        priceYen: 3200,
        isSos: true,
        sosReason: '高齢の家族宅',
        beforeImageAsset: 'assets/images/before_driveway.png',
        status: RequestStatus.working,
        workerId: 'demo-worker-takumi',
        workerName: '佐藤 拓海さん',
        acceptedAt: DateTime(2026, 8, 13, 9),
        movingAt: DateTime(2026, 8, 13, 9, 3),
        arrivedAt: DateTime(2026, 8, 13, 9, 11),
        startedAt: DateTime(2026, 8, 13, 9, 15),
        createdAt: DateTime(2026, 8, 13, 8, 50),
      ),
    ],
  );
  runApp(
    MaterialApp(
      title: 'YUKITAS',
      debugShowCheckedModeBanner: false,
      theme: YukitasTheme.light,
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ModeShell(repository: repository),
    ),
  );
}
