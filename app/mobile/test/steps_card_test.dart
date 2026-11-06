import 'package:asistente_deportivo/core/activity/models.dart';
import 'package:asistente_deportivo/core/common/date.dart';
import 'package:asistente_deportivo/features/activity/steps_card.dart';
import 'package:asistente_deportivo/platform/capability.dart';
import 'package:asistente_deportivo/platform/health/health_service.dart';
import 'package:asistente_deportivo/platform/platform_providers.dart';
import 'package:asistente_deportivo/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Apple Salud de mentira: empieza sin permiso y, al pedirlo, entrega pasos.
class _FakeHealth implements HealthService {
  CapabilityStatus current = CapabilityStatus.notDetermined;
  int requests = 0;

  @override
  String get providerName => 'Apple Salud';

  @override
  Future<CapabilityStatus> status() async => current;

  @override
  Future<CapabilityStatus> requestAccess(Set<HealthMetric> metrics) async {
    requests++;
    return current = CapabilityStatus.granted;
  }

  @override
  Future<List<DailySteps>> dailySteps({required String from, required String to}) async => [
        for (var d = from, i = 0; d.compareTo(to) <= 0; d = addDays(d, 1), i++)
          DailySteps(date: d, steps: 1000 * (i + 1), source: DataSource.appleHealth),
      ];

  @override
  Future<List<HeartRateSample>> heartRate({required DateTime from, required DateTime to}) async => const [];

  @override
  Future<List<ActivitySession>> sessions({required DateTime from, required DateTime to}) async => const [];
}

void main() {
  testWidgets('pide el permiso y muestra los pasos del día', (tester) async {
    final health = _FakeHealth();
    await tester.pumpWidget(ProviderScope(
      overrides: [healthServiceProvider.overrideWithValue(health)],
      child: MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: StepsCard(date: todayKey()))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Conectar Apple Salud'), findsOneWidget);
    await tester.tap(find.text('Conectar Apple Salud'));
    await tester.pumpAndSettle();

    expect(health.requests, 1);
    // Último de los 7 días = hoy = 7000 pasos.
    expect(find.text('7000'), findsOneWidget);
    expect(find.text('pasos hoy'), findsOneWidget);
  });

  testWidgets('no se muestra donde no hay Apple Salud', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [healthServiceProvider.overrideWithValue(const UnavailableHealthService(currentStatus: CapabilityStatus.unsupported))],
      child: MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: StepsCard(date: todayKey()))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Pasos'), findsNothing);
  });
}
