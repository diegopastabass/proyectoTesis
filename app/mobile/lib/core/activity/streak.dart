/// Racha de uso: días seguidos registrando comidas, entrenamientos o rutas de cardio.
///
/// - Un día suma si tiene algún registro hecho a tiempo (ver `loggedOnTime`).
/// - Hoy no corta la racha mientras no termine.
/// - Protector: una falta por semana (lunes a domingo) no corta la racha. El día
///   protegido mantiene la racha pero no suma.
/// - Días de descanso (por ejemplo, el fin de semana): sin registro mantienen la
///   racha sin sumar ni gastar el protector; con registro suman como cualquier día.
library;

import 'dart:math' as math;

import '../common/date.dart';
import '../strength/calendar.dart' show weekStart;
import 'calendar.dart' show lateGraceDays;

class StreakInfo {
  const StreakInfo({
    this.current = 0,
    this.best = 0,
    this.start,
    this.activeToday = false,
    this.protectedDays = const {},
    this.restDays = const {},
    this.restToday = false,
    this.milestone,
    this.milestoneDate,
  });

  /// Días con registro en la racha actual.
  final int current;

  /// Racha más larga de la historia.
  final int best;

  /// Primer día de la racha actual (identifica la racha para no repetir avisos).
  final String? start;

  /// Hoy ya tiene un registro que suma.
  final bool activeToday;

  /// Faltas cubiertas por el protector (en la racha actual y en las anteriores).
  final Set<String> protectedDays;

  /// Días de descanso sin registro que mantuvieron la racha.
  final Set<String> restDays;

  /// Hoy es día de descanso: no hace falta registrar para mantener la racha.
  final bool restToday;

  /// Último hito de la racha actual y el día en que se alcanzó.
  final int? milestone;
  final String? milestoneDate;

  /// El protector de la semana de `today` ya se usó en la racha actual.
  bool protectorUsedInWeek(String today) {
    final week = weekStart(today);
    return start != null && protectedDays.any((d) => d.compareTo(start!) >= 0 && weekStart(d) == week);
  }
}

/// Días de la semana guardados como lista (1 = lunes … 7 = domingo); ignora valores inválidos.
Set<int> weekdaysFrom(Object? data) => {for (final d in data is List ? data : const []) if (d is num && d >= 1 && d <= 7) d.toInt()};

/// Máximo de días de descanso por semana: con más, la racha deja de significar constancia.
const maxStreakRestDays = 3;

/// Calcula la racha con los días que suman (`counted`) hasta `today`.
/// `restWeekdays`: días de descanso, 1 = lunes … 7 = domingo.
StreakInfo computeStreak(Iterable<String> counted, String today, {Set<int> restWeekdays = const {}}) {
  bool isRest(String d) => restWeekdays.contains(fromDateKey(d).weekday);
  final days = counted.where((d) => d.compareTo(today) <= 0).toSet();
  if (days.isEmpty) return StreakInfo(restToday: isRest(today));

  var chain = 0;
  var best = 0;
  String? start;
  int? milestone;
  String? milestoneDate;
  final protectedDays = <String>{};
  final restDays = <String>{};
  // Faltas cubiertas que aún esperan un día con registro para confirmarse.
  final pending = <String>[];
  final usedWeeks = <String>{};

  void reset() {
    chain = 0;
    start = null;
    milestone = null;
    milestoneDate = null;
    pending.clear();
    usedWeeks.clear();
  }

  for (var d = days.reduce((a, b) => a.compareTo(b) < 0 ? a : b); d.compareTo(today) <= 0; d = addDays(d, 1)) {
    if (days.contains(d)) {
      start ??= d;
      chain++;
      protectedDays.addAll(pending);
      pending.clear();
      if (isStreakMilestone(chain)) {
        milestone = chain;
        milestoneDate = d;
      }
      best = math.max(best, chain);
    } else if (d == today) {
      // Hoy todavía puede registrarse.
    } else if (isRest(d)) {
      if (chain > 0) restDays.add(d);
    } else if (chain > 0 && usedWeeks.add(weekStart(d))) {
      pending.add(d);
    } else {
      reset();
    }
  }
  // Las faltas cubiertas al final mantienen viva la racha actual.
  protectedDays.addAll(pending);

  return StreakInfo(
    current: chain,
    best: best,
    start: start,
    activeToday: days.contains(today),
    protectedDays: protectedDays,
    restDays: restDays,
    restToday: isRest(today),
    milestone: milestone,
    milestoneDate: milestoneDate,
  );
}

/// Hitos: 5 días, una semana, 10 días, un mes y luego cada mes (30 días).
bool isStreakMilestone(int days) => days == 5 || days == 7 || days == 10 || (days >= 30 && days % 30 == 0);

/// Próximo hito después de `days`.
int nextStreakMilestone(int days) {
  for (final m in const [5, 7, 10]) {
    if (days < m) return m;
  }
  return (days ~/ 30 + 1) * 30;
}

String streakMilestoneTitle(int days) => switch (days) {
      7 => '¡Una semana seguida!',
      30 => '¡Un mes seguido!',
      _ when days >= 60 && days % 30 == 0 => '¡${days ~/ 30} meses seguidos!',
      _ => '¡$days días seguidos!',
    };

/// Último hito celebrado (se guarda en el perfil para no repetir el aviso en otro dispositivo).
class StreakCelebration {
  const StreakCelebration({required this.start, required this.milestone});

  static StreakCelebration? fromMap(Object? data) {
    if (data is! Map || data['start'] is! String || data['milestone'] is! num) return null;
    return StreakCelebration(start: data['start'] as String, milestone: (data['milestone'] as num).toInt());
  }

  final String start;
  final int milestone;

  Map<String, dynamic> toMap() => {'start': start, 'milestone': milestone};
}

/// Hito por celebrar: alcanzado hoy o ayer (con un registro atrasado) y aún no
/// celebrado en esta racha. Los hitos antiguos no se celebran de nuevo.
int? milestoneToCelebrate(StreakInfo s, StreakCelebration? last, String today) {
  final m = s.milestone;
  final date = s.milestoneDate;
  if (m == null || date == null || s.start == null) return null;
  if (date.compareTo(addDays(today, -lateGraceDays)) < 0) return null;
  if (last != null && last.start == s.start && last.milestone >= m) return null;
  return m;
}
