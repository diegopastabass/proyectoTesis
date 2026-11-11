/// Plan semanal sugerido (CU-12, R13, RNF-14): sesiones de fuerza y de cardio
/// ubicadas en la semana según las reglas del entrenamiento concurrente.
///
/// 1. El perfil se clasifica (nivel, orientación y cuántas sesiones de cada tipo).
/// 2. La fuerza sale de los programas de `strength/programs.dart`.
/// 3. El cardio se arma por intensidad: casi todo suave, a lo más una sesión
///    intensa (intervalos) y una larga.
/// 4. Las sesiones se ubican buscando, entre todas las semanas posibles, la que
///    menos reglas rompe (penalizaciones abajo). Son pocas combinaciones (hasta
///    unas cien mil), así que se revisan todas y el resultado siempre es el mismo.
library;

import '../cardio/activity.dart';
import '../strength/programs.dart';
import 'profile.dart';
import 'reason.dart';

enum SessionKind { strength, cardio }

enum CardioIntensity {
  easy('suave', 3, 'zona cómoda, puedes conversar'),
  long('larga', 4, 'ritmo constante y cómodo'),
  intervals('intervalos', 7, 'bloques intensos con pausas');

  const CardioIntensity(this.label, this.rpe, this.hint);

  final String label;

  /// Esfuerzo planificado (escala CR-10), para estimar la carga de la semana.
  final int rpe;
  final String hint;
}

/// Nombre corto de cada día (1 = lunes).
const weekdayShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

class PlannedSession {
  const PlannedSession({
    required this.kind,
    required this.weekday,
    required this.title,
    required this.minutes,
    required this.rpe,
    this.discipline,
    this.intensity,
    this.routineIndex,
    this.legHeavy = false,
    this.sharedDay = false,
  });

  factory PlannedSession.fromMap(Object? data) {
    final m = data is Map ? data : const {};
    return PlannedSession(
      kind: SessionKind.values.where((k) => k.name == m['kind']).firstOrNull ?? SessionKind.strength,
      weekday: ((m['weekday'] as num?)?.toInt() ?? 1).clamp(1, 7),
      title: m['title'] as String? ?? '',
      minutes: (m['minutes'] as num?)?.toInt() ?? 0,
      rpe: (m['rpe'] as num?)?.toInt() ?? 0,
      discipline: m['discipline'] == null ? null : Discipline.from(m['discipline']),
      intensity: CardioIntensity.values.where((i) => i.name == m['intensity']).firstOrNull,
      routineIndex: (m['routineIndex'] as num?)?.toInt(),
      legHeavy: m['legHeavy'] == true,
      sharedDay: m['sharedDay'] == true,
    );
  }

  final SessionKind kind;

  /// 1 = lunes … 7 = domingo.
  final int weekday;
  final String title;
  final int minutes;

  /// Esfuerzo planificado (CR-10).
  final int rpe;
  final Discipline? discipline;
  final CardioIntensity? intensity;

  /// Rutina del programa (índice en `Program.routines`).
  final int? routineIndex;

  /// Rutina con mucho trabajo de pierna.
  final bool legHeavy;

  /// Ese día también hay una sesión del otro tipo (van separadas al menos 6 h).
  final bool sharedDay;

  /// Carga planificada en UA (RPE × minutos), la misma escala que la carga registrada.
  int get load => rpe * minutes;

  /// Exigente para las piernas al día siguiente: pierna pesada, sesión larga o intervalos.
  bool get demanding => kind == SessionKind.cardio && intensity != CardioIntensity.easy;

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'weekday': weekday,
        'title': title,
        'minutes': minutes,
        'rpe': rpe,
        'discipline': ?discipline?.name,
        'intensity': ?intensity?.name,
        'routineIndex': ?routineIndex,
        if (legHeavy) 'legHeavy': true,
        if (sharedDay) 'sharedDay': true,
      };

  @override
  String toString() => '${weekdayShort[weekday - 1]} $title';
}

class WeeklyPlan {
  const WeeklyPlan({
    required this.level,
    required this.orientation,
    required this.sessions,
    required this.why,
    this.programId,
    this.routineOffset = 0,
    this.createdAt,
  });

  static WeeklyPlan? fromMap(Object? data) {
    if (data is! Map) return null;
    return WeeklyPlan(
      level: Level.values.where((l) => l.name == data['level']).firstOrNull ?? Level.beginner,
      orientation: Orientation.values.where((o) => o.name == data['orientation']).firstOrNull ?? Orientation.balanced,
      programId: data['programId'] as String?,
      routineOffset: (data['routineOffset'] as num?)?.toInt() ?? 0,
      sessions: [for (final s in data['sessions'] as List? ?? const []) PlannedSession.fromMap(s)]..sort(_byDay),
      why: [for (final r in data['why'] as List? ?? const []) Reason.fromMap(r)],
      createdAt: data['createdAt'] as String?,
    );
  }

  final Level level;
  final Orientation orientation;

  /// Programa de fuerza del plan.
  final String? programId;

  /// Rutina del programa con que parte la semana (la rotación sigue desde ahí).
  final int routineOffset;

  /// Ordenadas por día (la fuerza antes que el cardio en un mismo día).
  final List<PlannedSession> sessions;
  final List<Reason> why;

  /// Cuándo se aceptó (YYYY-MM-DD).
  final String? createdAt;

  List<PlannedSession> on(int weekday) => [for (final s in sessions) if (s.weekday == weekday) s];

  Iterable<PlannedSession> get strength => sessions.where((s) => s.kind == SessionKind.strength);

  Iterable<PlannedSession> get cardio => sessions.where((s) => s.kind == SessionKind.cardio);

  /// Días con fuerza (para los recordatorios y la rotación del programa).
  Set<int> get strengthWeekdays => {for (final s in strength) s.weekday};

  Set<int> get trainingWeekdays => {for (final s in sessions) s.weekday};

  /// Carga planificada de la semana (UA).
  int get plannedLoad => sessions.fold(0, (a, s) => a + s.load);

  WeeklyPlan accepted(String date) =>
      WeeklyPlan(level: level, orientation: orientation, sessions: sessions, why: why, programId: programId, routineOffset: routineOffset, createdAt: date);

  Map<String, dynamic> toMap() => {
        'level': level.name,
        'orientation': orientation.name,
        'programId': programId,
        'routineOffset': routineOffset,
        'sessions': [for (final s in sessions) s.toMap()],
        'why': [for (final r in why) r.toMap()],
        'createdAt': ?createdAt,
      };
}

int _byDay(PlannedSession a, PlannedSession b) {
  final d = a.weekday.compareTo(b.weekday);
  return d != 0 ? d : a.kind.index.compareTo(b.kind.index);
}

// ---------------------------------------------------------------------------
// Fuerza: programa y rutinas con mucha pierna
// ---------------------------------------------------------------------------

const _legWords = ['squat', 'deadlift', 'leg_press', 'lunge', 'leg_curl', 'leg_extension', 'calf', 'hip_thrust', 'glute', 'box_jump'];

bool _isLegExercise(String id) {
  final s = id.toLowerCase();
  return _legWords.any(s.contains);
}

/// Parte de las series efectivas de la rutina que son de pierna (0 a 1).
double legShare(ProgramDay day) {
  var leg = 0;
  var total = 0;
  for (final e in day.exercises) {
    total += e.sets;
    if (_isLegExercise(e.exerciseId)) leg += e.sets;
  }
  return total == 0 ? 0 : leg / total;
}

/// Desde un tercio de las series de pierna, la rutina deja las piernas cansadas al día siguiente.
bool isLegHeavy(ProgramDay day) => legShare(day) >= 0.3;

CardioType _cardioType(Set<Discipline> d) =>
    d.contains(Discipline.cycling) && !d.contains(Discipline.running) ? CardioType.cycling : CardioType.running;

bool _fits(Equipment program, Equipment available) => switch (program) {
      Equipment.gym => available == Equipment.gym,
      Equipment.dumbbells => available != Equipment.bodyweight,
      Equipment.bodyweight => true,
    };

/// Programa de fuerza para el perfil: el mejor de `recommendPrograms` (si hay uno
/// casi igual de bueno hecho para el equipo que tienes, ese) o, si ninguno calza
/// con los días, el más cercano que se pueda hacer con el equipo.
Program programFor(AthleteProfile p, Classification c) {
  final answers = ProgramAnswers(
    days: c.strengthSessions < 2 ? 2 : c.strengthSessions,
    experience: p.experience,
    goal: trainingGoalFor(p.goal),
    minutes: p.minutes,
    equipment: p.equipment,
    cardioDays: c.cardioSessions,
    cardio: _cardioType(p.disciplines),
  );
  final matches = recommendPrograms(answers, limit: 5);
  if (matches.isNotEmpty) {
    final top = matches.first;
    // Con gimnasio completo, un programa de gimnasio antes que uno "en casa" si casi empatan.
    final own = matches.where((m) => m.program.equipment == p.equipment && m.score >= top.score - 2 && m.program.minutes <= p.minutes + 15).firstOrNull;
    return (own ?? top).program;
  }
  final usable = programs.where((x) => _fits(x.equipment, p.equipment)).toList()
    ..sort((a, b) => (a.days - c.strengthSessions).abs().compareTo((b.days - c.strengthSessions).abs()));
  return usable.first;
}

// ---------------------------------------------------------------------------
// Cardio: intensidades, disciplinas y duraciones
// ---------------------------------------------------------------------------

/// Intensidades de la semana: casi todo suave, a lo más una sesión intensa y una larga.
/// Quien recién empieza no hace intervalos.
List<CardioIntensity> cardioIntensities(int count, Level level) {
  if (count <= 0) return const [];
  if (level == Level.beginner) {
    return count == 1 ? const [CardioIntensity.easy] : [for (var i = 0; i < count - 1; i++) CardioIntensity.easy, CardioIntensity.long];
  }
  return switch (count) {
    1 => const [CardioIntensity.long],
    2 => const [CardioIntensity.intervals, CardioIntensity.long],
    _ => [for (var i = 0; i < count - 2; i++) CardioIntensity.easy, CardioIntensity.intervals, CardioIntensity.long],
  };
}

Discipline _disciplineFor(CardioIntensity i, List<Discipline> ds, int n) {
  switch (i) {
    case CardioIntensity.long:
      // El trekking es una salida larga por naturaleza; si no, la bici y después la carrera.
      for (final d in const [Discipline.trekking, Discipline.cycling, Discipline.running]) {
        if (ds.contains(d)) return d;
      }
    case CardioIntensity.intervals:
      for (final d in const [Discipline.running, Discipline.cycling]) {
        if (ds.contains(d)) return d;
      }
    case CardioIntensity.easy:
      break;
  }
  return ds[n % ds.length];
}

/// Duración de la sesión larga según la disciplina y el nivel, sin pasar del doble
/// del tiempo que indicaste por sesión.
int _longMinutes(Discipline d, Level l, int minutes) {
  final base = switch (d) {
    Discipline.running => const [50, 75, 90],
    Discipline.cycling => const [90, 120, 150],
    Discipline.trekking => const [120, 180, 240],
  }[l.index];
  final cap = minutes * 2 < minutes + 30 ? minutes + 30 : minutes * 2;
  return base < cap ? base : cap;
}

String _cardioTitle(Discipline d, CardioIntensity i) => switch (i) {
      CardioIntensity.intervals => '${d.label}: intervalos',
      CardioIntensity.long => d == Discipline.trekking ? 'Trekking largo' : '${d.label} largo',
      CardioIntensity.easy => d == Discipline.trekking ? 'Caminata o trekking suave' : '${d.label} suave',
    };

class _Cardio {
  const _Cardio(this.intensity, this.discipline, this.minutes);

  final CardioIntensity intensity;
  final Discipline discipline;
  final int minutes;
}

// ---------------------------------------------------------------------------
// Ubicación en la semana
// ---------------------------------------------------------------------------

/// Penalizaciones (más bajo es mejor). Los valores ordenan las reglas por importancia.
abstract final class PlanPenalty {
  /// Pierna pesada el día antes de la sesión larga o de intervalos.
  static const legsBeforeDemanding = 6;

  /// Pierna pesada el mismo día que la sesión larga o los intervalos.
  static const legsSameDayDemanding = 5;

  /// Pierna pesada dos días seguidos.
  static const legsBackToBack = 3;

  /// Intervalos pegados a la sesión larga.
  static const intervalsNextToLong = 3;

  /// Fuerza y cardio el mismo día (se pueden, separados 6 h, pero mejor en días distintos).
  static const sharedDay = 4;

  /// Pierna pesada el día después de los intervalos.
  static const legsAfterIntervals = 2;

  /// La sesión larga fuera del fin de semana.
  static const longOnWeekday = 2;

  /// Cada día de entrenamiento después del tercero seguido (del segundo, si recién empiezas).
  static const longStreak = 1;
}

int _next(int day) => day % 7 + 1;

int _prev(int day) => day == 1 ? 7 : day - 1;

class _Week {
  _Week(this.strengthDay, this.legs, this.cardioDay, this.cardio);

  /// Día → rutina de fuerza (pierna pesada o no) y día → sesión de cardio.
  final Map<int, int> strengthDay; // día → índice de rutina
  final Map<int, bool> legs; // día → pierna pesada
  final Map<int, int> cardioDay; // día → índice en la lista de cardio
  final List<_Cardio> cardio;

  CardioIntensity? intensityOn(int day) => cardioDay[day] == null ? null : cardio[cardioDay[day]!].intensity;

  bool demandingOn(int day) {
    final i = intensityOn(day);
    return i == CardioIntensity.long || i == CardioIntensity.intervals;
  }
}

int _score(_Week w, Level level) {
  var score = 0;
  for (var day = 1; day <= 7; day++) {
    final legs = w.legs[day] ?? false;
    if (w.strengthDay.containsKey(day) && w.cardioDay.containsKey(day)) score += PlanPenalty.sharedDay;
    if (legs) {
      if (w.demandingOn(_next(day))) score += PlanPenalty.legsBeforeDemanding;
      if (w.demandingOn(day)) score += PlanPenalty.legsSameDayDemanding;
      if (w.legs[_next(day)] ?? false) score += PlanPenalty.legsBackToBack;
      if (w.intensityOn(_prev(day)) == CardioIntensity.intervals) score += PlanPenalty.legsAfterIntervals;
    }
    final i = w.intensityOn(day);
    if (i == CardioIntensity.long && day < 6) score += PlanPenalty.longOnWeekday;
    if (i == CardioIntensity.intervals && (w.intensityOn(_next(day)) == CardioIntensity.long || w.intensityOn(_prev(day)) == CardioIntensity.long)) {
      score += PlanPenalty.intervalsNextToLong;
    }
  }
  // Rachas de días seguidos entrenando (la semana se repite: el domingo sigue al lunes).
  final trains = [for (var day = 1; day <= 7; day++) w.strengthDay.containsKey(day) || w.cardioDay.containsKey(day)];
  if (trains.any((t) => !t)) {
    final limit = level == Level.beginner ? 2 : 3;
    final start = trains.indexOf(false);
    var run = 0;
    for (var k = 1; k <= 7; k++) {
      if (trains[(start + k) % 7]) {
        run++;
        if (run > limit) score += PlanPenalty.longStreak;
      } else {
        run = 0;
      }
    }
  }
  return score;
}

Iterable<List<int>> _combinations(List<int> items, int k, [int start = 0]) sync* {
  if (k == 0) {
    yield const [];
    return;
  }
  for (var i = start; i <= items.length - k; i++) {
    for (final rest in _combinations(items, k - 1, i + 1)) {
      yield [items[i], ...rest];
    }
  }
}

/// Asignaciones de `k` sesiones distintas a días distintos (variaciones sin repetición).
Iterable<List<int>> _arrangements(List<int> days, int k) sync* {
  if (k == 0) {
    yield const [];
    return;
  }
  for (final d in days) {
    for (final rest in _arrangements([for (final x in days) if (x != d) x], k - 1)) {
      yield [d, ...rest];
    }
  }
}

const _allDays = [1, 2, 3, 4, 5, 6, 7];

/// Resultado del ordenamiento: la mejor semana y su puntaje.
class _Placement {
  _Placement(this.week, this.score, this.offset);

  final _Week week;
  final int score;
  final int offset;
}

_Placement _place({required int strength, required List<bool> routineLegs, required List<_Cardio> cardio, required int maxDays, required Level level}) {
  _Placement? best;
  final offsets = routineLegs.isEmpty ? 1 : routineLegs.length;
  // Cardio idéntico (misma intensidad y disciplina) es intercambiable: se recorre una sola vez.
  for (final sDays in _combinations(_allDays, strength)) {
    for (var offset = 0; offset < offsets; offset++) {
      final strengthDay = <int, int>{};
      final legs = <int, bool>{};
      for (var i = 0; i < sDays.length; i++) {
        final r = routineLegs.isEmpty ? 0 : (offset + i) % routineLegs.length;
        strengthDay[sDays[i]] = r;
        legs[sDays[i]] = routineLegs.isNotEmpty && routineLegs[r];
      }
      for (final cDays in _arrangements(_allDays, cardio.length)) {
        if (!_canonical(cDays, cardio)) continue;
        final used = {...sDays, ...cDays};
        if (used.length > maxDays) continue;
        final week = _Week(strengthDay, legs, {for (var i = 0; i < cDays.length; i++) cDays[i]: i}, cardio);
        final score = _score(week, level);
        if (best == null || score < best.score) best = _Placement(week, score, offset);
      }
    }
  }
  return best!;
}

/// Entre sesiones de cardio iguales, solo el orden creciente de días (evita repetir semanas idénticas).
bool _canonical(List<int> days, List<_Cardio> cardio) {
  for (var i = 1; i < days.length; i++) {
    final a = cardio[i - 1];
    final b = cardio[i];
    if (a.intensity == b.intensity && a.discipline == b.discipline && days[i - 1] > days[i]) return false;
  }
  return true;
}

String _duration(int minutes) =>
    minutes < 60 ? '$minutes min' : (minutes % 60 == 0 ? '${minutes ~/ 60} h' : '${minutes ~/ 60} h ${minutes % 60} min');

/// Texto corto de la sesión: "45 min · zona cómoda, puedes conversar".
String sessionDetail(PlannedSession s) {
  final what = s.kind == SessionKind.strength ? (s.legHeavy ? 'con pierna' : 'sin pierna pesada') : s.intensity!.hint;
  final shared = s.sharedDay ? ' · separada 6 h de la otra sesión' : '';
  return '${_duration(s.minutes)} · $what$shared';
}

/// Plan sugerido para el perfil. `program` permite fijar otro programa de fuerza.
WeeklyPlan buildWeeklyPlan(AthleteProfile p, {Program? program}) {
  final c = classify(p);
  final prog = program ?? programFor(p, c);
  final routineLegs = [for (final r in prog.routines) isLegHeavy(r)];
  final disciplines = [for (final d in Discipline.values) if (p.disciplines.contains(d)) d];

  final intensities = disciplines.isEmpty ? const <CardioIntensity>[] : cardioIntensities(c.cardioSessions, c.level);
  final easyMinutes = p.minutes.clamp(30, c.level == Level.beginner ? 40 : 60);
  var easyCount = 0;
  final cardio = <_Cardio>[
    for (final i in intensities)
      () {
        final d = _disciplineFor(i, disciplines, i == CardioIntensity.easy ? easyCount++ : 0);
        final minutes = switch (i) {
          CardioIntensity.easy => easyMinutes,
          CardioIntensity.intervals => 45,
          CardioIntensity.long => _longMinutes(d, c.level, p.minutes),
        };
        return _Cardio(i, d, minutes);
      }(),
  ];

  final placement = _place(strength: c.strengthSessions, routineLegs: routineLegs, cardio: cardio, maxDays: p.days, level: c.level);
  final w = placement.week;
  final strengthMinutes = prog.minutes < p.minutes ? prog.minutes : p.minutes;
  final strengthRpe = c.level == Level.beginner ? 6 : 7;

  final sessions = <PlannedSession>[
    for (final MapEntry(key: day, value: r) in w.strengthDay.entries)
      PlannedSession(
        kind: SessionKind.strength,
        weekday: day,
        title: prog.routines[r].name,
        minutes: strengthMinutes,
        rpe: strengthRpe,
        routineIndex: r,
        legHeavy: routineLegs[r],
        sharedDay: w.cardioDay.containsKey(day),
      ),
    for (final MapEntry(key: day, value: i) in w.cardioDay.entries)
      PlannedSession(
        kind: SessionKind.cardio,
        weekday: day,
        title: _cardioTitle(w.cardio[i].discipline, w.cardio[i].intensity),
        minutes: w.cardio[i].minutes,
        rpe: w.cardio[i].intensity.rpe,
        discipline: w.cardio[i].discipline,
        intensity: w.cardio[i].intensity,
        sharedDay: w.strengthDay.containsKey(day),
      ),
  ]..sort(_byDay);

  final why = <Reason>[
    ...c.why,
    Reason('Fuerza: ${prog.name}. ${prog.forWhom}'),
    if (cardio.isNotEmpty)
      const Reason('La mayor parte del cardio es suave y hay a lo más una sesión intensa: así sumas volumen sin acumular tanta fatiga.', source: Sources.design),
    if (cardio.isNotEmpty)
      const Reason('Fuerza y cardio van en días distintos o separados al menos 6 horas, para reducir la interferencia entre ambos.', source: Sources.concurrent),
    if (cardio.any((x) => x.intensity != CardioIntensity.easy) && routineLegs.any((l) => l))
      _legsReason(w),
    if (cardio.any((x) => x.intensity == CardioIntensity.long))
      _longReason(w),
  ];
  return WeeklyPlan(level: c.level, orientation: c.orientation, sessions: sessions, why: why, programId: prog.id, routineOffset: placement.offset);
}

Reason _legsReason(_Week w) {
  final broken = [
    for (var day = 1; day <= 7; day++)
      if ((w.legs[day] ?? false) && (w.demandingOn(_next(day)) || w.demandingOn(day))) day,
  ];
  return broken.isEmpty
      ? const Reason('No hay pierna pesada el día antes (ni el mismo día) de tu sesión larga o de intervalos.', source: Sources.concurrent)
      : Reason(
          'Con tus días no se pudo evitar pierna pesada cerca de una sesión exigente (${broken.map((d) => weekdayShort[d - 1]).join(', ')}): '
          'si llegas cansado, baja la carga de las piernas ese día.',
          source: Sources.concurrent,
        );
}

Reason _longReason(_Week w) {
  final day = w.cardioDay.entries.firstWhere((e) => w.cardio[e.value].intensity == CardioIntensity.long).key;
  return day >= 6
      ? const Reason('La sesión larga va el fin de semana, cuando suele haber más tiempo.', source: Sources.design)
      : Reason('La sesión larga quedó el ${weekdayShort[day - 1].toLowerCase()} para respetar las otras reglas; muévela si el fin de semana te acomoda más.',
          source: Sources.design);
}
