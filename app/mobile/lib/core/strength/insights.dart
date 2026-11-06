/// Mensajes de motivación al terminar una sesión.
library;

import 'dart:math' as math;

import '../common/date.dart';
import '../common/numbers.dart';
import 'calendar.dart';
import 'models.dart';
import 'stats.dart';

enum InsightKind { first, record, weight, reps, sets, volume, streak, week, milestone, fresh }

class Insight {
  const Insight({required this.kind, required this.text, this.exerciseId, required this.priority});

  final InsightKind kind;
  final String text;
  final String? exerciseId;

  /// Mayor = más relevante.
  final int priority;
}

const _milestones = [5, 10, 25, 50, 75, 100, 150, 200, 300, 500];

String formatKg(num n) => formatNumber(n, maxFractionDigits: 2);

String _plural(num n, String one, String many) => n == 1 ? one : many;

/// "ayer", "la semana pasada", "hace 12 días"…
String sinceText(String from, String to) {
  final days = daysBetween(from, to);
  if (days <= 0) return 'hoy más temprano';
  if (days == 1) return 'ayer';
  if (days >= 6 && days <= 8) return 'la semana pasada';
  return 'hace $days días';
}

String _reps(double r) => plain(r);

/// Mejor mensaje para un ejercicio comparado con su historial previo.
Insight? _exerciseInsight(String name, String id, ExerciseSession cur, List<ExerciseSession> history) {
  final prev = history.lastOrNull;
  if (prev == null) return null;
  final bestKg = history.map((h) => h.maxKg).reduce(math.max);
  final best1RM = history.map((h) => h.best1RM).reduce(math.max);
  final since = sinceText(prev.date, cur.date);

  if (cur.maxKg > 0 && cur.maxKg > bestKg) {
    return Insight(
      kind: InsightKind.record,
      priority: 100,
      exerciseId: id,
      text: 'Nuevo récord en $name: ${formatKg(cur.maxKg)} kg × ${_reps(cur.repsAtMax)}.',
    );
  }
  if (cur.maxKg > prev.maxKg) {
    return Insight(
      kind: InsightKind.weight,
      priority: 80,
      exerciseId: id,
      text: 'Subiste el peso en $name: ${formatKg(cur.maxKg)} kg (antes ${formatKg(prev.maxKg)} kg).',
    );
  }
  if (cur.maxKg > 0 && cur.maxKg == prev.maxKg && cur.repsAtMax > prev.repsAtMax) {
    return Insight(
      kind: InsightKind.reps,
      priority: 70,
      exerciseId: id,
      text: 'Más repeticiones en $name con ${formatKg(cur.maxKg)} kg: ${_reps(cur.repsAtMax)} (antes ${_reps(prev.repsAtMax)}).',
    );
  }
  if (cur.maxKg == 0 && prev.maxKg == 0 && cur.maxReps > prev.maxReps) {
    return Insight(
      kind: InsightKind.reps,
      priority: 70,
      exerciseId: id,
      text: 'Más repeticiones en $name: ${_reps(cur.maxReps)} (antes ${_reps(prev.maxReps)}).',
    );
  }
  if (cur.best1RM > 0 && cur.best1RM > best1RM + 0.05) {
    return Insight(
      kind: InsightKind.record,
      priority: 90,
      exerciseId: id,
      text: 'Mejor 1RM estimado en $name: ${formatKg(round1(cur.best1RM))} kg.',
    );
  }
  if (cur.sets > prev.sets) {
    final n = cur.sets - prev.sets;
    return Insight(
      kind: InsightKind.sets,
      priority: 60,
      exerciseId: id,
      text: 'Hoy hiciste $n ${_plural(n, 'serie', 'series')} más de $name que la última vez ($since).',
    );
  }
  if (prev.volume > 0 && cur.volume >= prev.volume * 1.05) {
    final pct = jsRound((cur.volume / prev.volume - 1) * 100);
    return Insight(kind: InsightKind.volume, priority: 40, exerciseId: id, text: 'Moviste $pct % más volumen en $name que la última vez.');
  }
  return null;
}

/// Mensajes de motivación de una sesión, comparándola solo con las sesiones
/// anteriores a ella. Solo destaca avances: lo que bajó se ve en el resumen.
List<Insight> workoutInsights(Workout current, List<Workout> all, {int limit = 6}) {
  final before = all.where((w) => w.id != current.id && w.startedAt < current.startedAt).toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  if (before.isEmpty) {
    return const [
      Insight(kind: InsightKind.first, priority: 100, text: '¡Primer entrenamiento registrado! Desde ahora verás aquí cómo avanzas.'),
    ];
  }

  final out = <Insight>[];
  final fresh = <String>[];

  for (final e in current.exercises) {
    if (e.sets.isEmpty) continue;
    final history = [
      for (final w in before)
        for (final x in w.exercises)
          if (x.exerciseId == e.exerciseId && x.sets.isNotEmpty) summarizeExercise(w, x),
    ];
    if (history.isEmpty) {
      fresh.add(e.name);
      continue;
    }
    final insight = _exerciseInsight(e.name, e.exerciseId, summarizeExercise(current, e), history);
    if (insight != null) out.add(insight);
  }

  if (fresh.isNotEmpty) {
    out.add(Insight(
      kind: InsightKind.fresh,
      priority: 30,
      text: fresh.length == 1
          ? 'Primera vez registrando ${fresh.first}.'
          : 'Sumaste ${fresh.length} ejercicios nuevos: ${fresh.join(', ')}.',
    ));
  }

  // Volumen contra la última vez que se hizo la misma rutina.
  final same = before
      .where((w) => current.routineId != null ? w.routineId == current.routineId : w.name == current.name)
      .lastOrNull;
  if (same != null) {
    final cur = workoutVolume(current);
    final prev = workoutVolume(same);
    if (prev > 0 && cur > prev) {
      final pct = jsRound((cur / prev - 1) * 100);
      if (pct >= 1) {
        out.add(Insight(
          kind: InsightKind.volume,
          priority: 85,
          text: 'Volumen total $pct % mayor que la última vez que hiciste ${current.name} (${sinceText(same.date, current.date)}).',
        ));
      }
    }
  }

  final dates = [...before.map((w) => w.date), current.date];
  final streak = weeklyStreak(dates, current.date);
  if (streak >= 2) out.add(Insight(kind: InsightKind.streak, priority: 55, text: 'Llevas $streak semanas seguidas entrenando.'));

  final thisWeek = weekStart(current.date);
  final lastWeek = addDays(thisWeek, -7);
  final inThis = dates.where((d) => weekStart(d) == thisWeek).length;
  final inLast = dates.where((d) => weekStart(d) == lastWeek).length;
  if (inLast > 0 && inThis > inLast) {
    out.add(Insight(
      kind: InsightKind.week,
      priority: 50,
      text: 'Ya llevas $inThis entrenamientos esta semana, más que en toda la semana pasada ($inLast).',
    ));
  }

  final total = before.length + 1;
  if (_milestones.contains(total)) {
    out.add(Insight(kind: InsightKind.milestone, priority: 65, text: '¡Completaste tu entrenamiento número $total!'));
  }

  out.sort((a, b) => b.priority.compareTo(a.priority));
  return out.take(limit).toList();
}
