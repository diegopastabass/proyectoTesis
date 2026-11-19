import 'dart:convert';

import 'package:asistente_deportivo/core/activity/models.dart';
import 'package:asistente_deportivo/core/activity/steps.dart';
import 'package:asistente_deportivo/core/ai/ai_models.dart';
import 'package:asistente_deportivo/core/ai/prompts.dart';
import 'package:asistente_deportivo/core/body/energy.dart';
import 'package:asistente_deportivo/core/common/date.dart';
import 'package:asistente_deportivo/core/suggestions/alerts.dart';
import 'package:asistente_deportivo/core/suggestions/examples.dart';
import 'package:asistente_deportivo/core/suggestions/profile.dart';
import 'package:asistente_deportivo/core/suggestions/weekly_plan.dart';
import 'package:asistente_deportivo/core/training/fatigue_view.dart';
import 'package:asistente_deportivo/data/ai/gemini_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const today = '2026-11-16';

List<DailySteps> days(List<int> steps, {String end = today}) => [
      for (var i = 0; i < steps.length; i++) DailySteps(date: addDays(end, i - steps.length + 1), steps: steps[i], source: DataSource.appleHealth),
    ];

void main() {
  group('pasos', () {
    test('promedio sin el día en curso, mejor día, días con la meta y racha', () {
      final s = stepsStats(days([5000, 9000, 8500, 8000, 2000]), goal: 8000, today: today);
      expect(s.total, 32500);
      expect(s.average, 7625, reason: 'hoy (2000) aún no termina');
      expect(s.countedDays, 4);
      expect(s.best!.steps, 9000);
      expect(s.goalDays, 3);
      expect(s.streak, 3, reason: 'hoy no llega a la meta: la racha cuenta hasta ayer');
      expect(stepsStats(days([8000, 9000]), goal: 8000, today: today).streak, 2, reason: 'hoy ya la cumplió');
    });

    test('compara con el periodo anterior', () {
      final s = stepsStats(days([6000, 6000, 0]), goal: 8000, today: today, previous: days([5000, 5000], end: '2026-11-13'));
      expect(s.previousAverage, 5000);
      expect(s.change, 20);
      expect(stepsStats(const [], goal: 8000, today: today).best, isNull);
      expect(stepsStats(const [], goal: 8000, today: today).change, isNull);
    });

    test('distancia y energía estimadas según la estatura y el peso', () {
      const man = BodyProfile(heightCm: 180, sex: Sex.male);
      expect(strideMeters(man), closeTo(0.747, 0.001));
      expect(stepsKm(10000, man), closeTo(7.47, 0.01));
      expect(stepsKcal(10000, man, 80), 299);
      expect(stepsKcal(10000, man, null), isNull);
      expect(strideMeters(const BodyProfile()), 0.75);
      expect(goalProgress(4000, 8000), 0.5);
      expect(goalProgress(12000, 8000), 1);
    });
  });

  group('sección de fatiga', () {
    final ctx = exampleAlertContext(DateTime(2026, 11, 16, 10));

    test('de dónde viene la carga y sesiones de la semana', () {
      final v = fatigueView(workouts: ctx.workouts, activities: ctx.cardio, today: today);
      expect(v.series.reliable, isTrue);
      expect(v.cardio.share, greaterThan(v.strength.share));
      expect(v.strength.share + v.cardio.share, closeTo(1, 1e-9));
      expect(v.sessions.every((s) => daysBetween(s.load.date, today) < 7), isTrue);
      expect(v.sessions.first.startedAt >= v.sessions.last.startedAt, isTrue, reason: 'de la más reciente a la más antigua');
      expect(v.sessions.any((s) => s.route.startsWith('/cardio/historial/')), isTrue);
      expect(v.ratios.last.$2, isNotNull);
      expect(v.mostlyEstimated, isFalse);
    });

    test('el resumen para el asistente lleva solo cifras del motor y el plan', () {
      final v = fatigueView(workouts: ctx.workouts, activities: ctx.cardio, today: today);
      final alerts = fatigueAlerts(ctx);
      final brief = fatigueBrief(view: v, today: today, threshold: 1.3, alerts: alerts, plan: ctx.plan, deficitPct: 25);
      expect(brief['historialSuficiente'], isTrue);
      expect(brief['razonAgudaCronica'], closeTo(2.0, 0.05));
      expect(brief['zona'], contains('muy brusco'));
      expect((brief['cargaPorDia'] as List).length, 14);
      expect((brief['proximasSesionesPlan'] as List).single, containsPair('cuando', 'mañana'));
      expect((brief['alertasDelMotor'] as List).first['titulo'], contains('Pierna A'));
      expect(brief['deficitCaloricoPct'], 25);
      // Se puede enviar como JSON y no lleva nombres ni correos.
      final json = jsonEncode(brief);
      expect(json, isNot(contains('@')));
    });

    test('sin plan ni alertas también funciona', () {
      final v = fatigueView(workouts: const [], activities: const [], today: today);
      final brief = fatigueBrief(view: v, today: today, threshold: 1.3);
      expect(brief['historialSuficiente'], isFalse);
      expect(brief['razonAgudaCronica'], isNull);
      expect(brief['proximasSesionesPlan'], isEmpty);
    });

    test('lectura del resumen del asistente', () {
      final s = FatigueSummary.fromJson({
        'titular': 'Vienes cargado',
        'resumen': 'Tu carga es el doble de lo habitual.',
        'claves': ['Uno', 'Dos', 'Tres', 'Cuatro', ''],
        'sugerencia': 'Baja la pierna de mañana.',
      });
      expect(s.points, ['Uno', 'Dos', 'Tres']);
      expect(FatigueSummary.fromJson(s.toJson()).suggestion, 'Baja la pierna de mañana.');
      expect(FatigueSummary.fromJson(const {}).isEmpty, isTrue);
    });

    test('el asistente recibe los datos y el esquema del resumen', () async {
      late Map<String, dynamic> body;
      final client = MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        final data = {'titular': 'Bien', 'resumen': 'Todo en orden.', 'claves': <String>[], 'sugerencia': 'Sigue así.'};
        return http.Response(jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': jsonEncode(data)},
                ],
              },
            },
          ],
        }), 200);
      });
      final plan = buildWeeklyPlan(exampleAthlete);
      final v = fatigueView(workouts: ctx.workouts, activities: ctx.cardio, today: today);
      final summary = await GeminiAiService(apiKey: 'k', client: client).fatigueSummary(fatigueBrief(view: v, today: today, threshold: 1.3, plan: plan));
      expect(summary.headline, 'Bien');
      expect(body['generationConfig']['responseJsonSchema'], fatigueSchema);
      final prompt = ((body['contents'] as List).single['parts'] as List).last['text'] as String;
      expect(prompt, contains('razonAgudaCronica'));
      expect(body['systemInstruction']['parts'].single['text'], contains('nunca las contradigas'));
    });
  });
}
