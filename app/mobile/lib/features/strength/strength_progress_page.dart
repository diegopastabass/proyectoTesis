import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/date.dart';
import '../../core/common/numbers.dart';
import '../../core/strength/calendar.dart';
import '../../core/strength/insights.dart';
import '../../core/strength/models.dart';
import '../../core/strength/stats.dart';
import '../../ui/format.dart';
import '../../ui/trend_chart.dart';
import '../../ui/widgets.dart';
import 'exercise_widgets.dart';

/// Rutina de cada sesión: su id o, si fue libre, su nombre.
String _groupKey(Workout w) => w.routineId ?? 'nombre:${w.name}';

class StrengthProgressPage extends ConsumerStatefulWidget {
  const StrengthProgressPage({super.key});

  @override
  ConsumerState<StrengthProgressPage> createState() => _StrengthProgressPageState();
}

class _StrengthProgressPageState extends ConsumerState<StrengthProgressPage> {
  String? _group;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AsyncView(ref.watch(strengthDataProvider), builder: (data) {
      final workouts = data.workouts;
      if (workouts.isEmpty) {
        return const PageBody(children: [
          AppCard(
            child: EmptyState(
              icon: Icons.show_chart,
              title: 'Tu progreso aparecerá aquí',
              message: 'Termina tu primer entrenamiento para ver el calendario, el volumen por sesión y la curva de cada ejercicio.',
            ),
          ),
        ]);
      }
      final today = todayKey();
      final dates = workouts.map((w) => w.date).toList();
      final sorted = sortWorkouts(workouts);

      // Grupos para la curva de volumen, del más frecuente al menos frecuente.
      final groups = <String, (String, int)>{};
      for (final w in sorted) {
        final g = groups[_groupKey(w)];
        groups[_groupKey(w)] = (w.name, (g?.$2 ?? 0) + 1);
      }
      final groupList = groups.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
      final selected = _group ?? groupList.firstOrNull?.key ?? 'todas';
      final points = [
        for (final w in sorted)
          if (selected == 'todas' || _groupKey(w) == selected) TrendPoint(date: w.date, value: workoutTotals(w).volume.toDouble(), data: w),
      ];
      final frequent = exerciseFrequency(workouts);

      return PageBody(children: [
        TileGrid(columns: 3, children: [
          StatTile(
            icon: Icons.calendar_month,
            label: 'Este mes',
            value: '${trainedDaysBetween(dates, '${today.substring(0, 7)}-01', today)} días',
            tooltip: 'Días con entrenamiento este mes',
          ),
          StatTile(
            icon: Icons.local_fire_department_outlined,
            label: 'Racha',
            value: '${weeklyStreak(dates, today)} sem.',
            tooltip: 'Semanas seguidas con al menos un entrenamiento',
          ),
          StatTile(icon: Icons.tag, label: 'Total', value: '${workouts.length}', tooltip: 'Entrenamientos registrados'),
        ]),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Constancia', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
            const SizedBox(height: 8),
            Heatmap(
              dates: dates,
              onSelectDay: (date) {
                final w = workouts.where((x) => x.date == date).firstOrNull;
                if (w != null) context.push('/fuerza/historial/${w.id}');
              },
            ),
          ]),
        ),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Peso total por sesión', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
            Text('kg × repeticiones de las series efectivas. Compara sesiones de la misma rutina.', style: TextStyle(fontSize: 11, color: c.faint)),
            const SizedBox(height: 8),
            ChoicePills<String>(
              scrollable: true,
              options: [...groupList.map((g) => g.key), 'todas'],
              selected: selected,
              onSelected: (g) => setState(() => _group = g),
              label: (k) => k == 'todas' ? 'Todas ${workouts.length}' : '${groups[k]!.$1} ${groups[k]!.$2}',
            ),
            const SizedBox(height: 8),
            TrendChart<Workout>(
              key: ValueKey(selected),
              points: points,
              unit: 'kg',
              label: 'peso total por sesión',
              format: (n) => formatNumber(jsRound(n), maxFractionDigits: 0),
              axisFormat: compactNumber,
              minPad: 50,
              compareLabel: 'vs. sesión anterior',
              detail: (w) => w.name,
              onSelect: (w) => context.push('/fuerza/historial/${w.id}'),
            ),
            if (points.length == 1)
              Text('Repite esta rutina para ver la curva.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.faint)),
          ]),
        ),
        CardList(header: const CardHeader('Progreso por ejercicio'), children: [
          for (final f in frequent)
            () {
              final history = exerciseHistory(workouts, f.exerciseId);
              final best = history.reduce((b, h) => h.maxKg > b.maxKg || (h.maxKg == b.maxKg && h.repsAtMax > b.repsAtMax) ? h : b);
              final gain = history.last.best1RM - history.first.best1RM;
              return ListTile(
                onTap: () => context.push('/fuerza/ejercicios/${Uri.encodeComponent(f.exerciseId)}'),
                leading: ExerciseThumb(data.exercise(f.exerciseId), size: 36),
                title: Text(data.nameOf(f.exerciseId, f.name), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${f.sessions} ${f.sessions == 1 ? 'sesión' : 'sesiones'} · mejor ${formatSet(kg: best.maxKg, reps: best.repsAtMax)}',
                  style: TextStyle(fontSize: 12, color: c.faint),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (history.length > 1 && gain != 0)
                    Tooltip(
                      message: 'Cambio del 1RM estimado desde la primera sesión',
                      child: Text('${gain > 0 ? '+' : '−'}${formatKg(round1(gain.abs()))} kg',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: gain > 0 ? c.success : c.faint)),
                    ),
                  Icon(Icons.chevron_right, color: c.faint),
                ]),
              );
            }(),
        ]),
      ]);
    });
  }
}

/// Mapa de calor tipo calendario: una columna por semana (lunes a domingo).
class Heatmap extends StatelessWidget {
  const Heatmap({super.key, required this.dates, this.onSelectDay});

  final List<String> dates;
  final ValueChanged<String>? onSelectDay;

  static const _cell = 13.0;
  static const _gap = 3.0;
  static const _step = _cell + _gap;
  static const _labelW = 16.0;
  static const _top = 14.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(builder: (context, box) {
      final today = todayKey();
      final weeks = math.max(8, math.min(53, ((box.maxWidth - _labelW) / _step).floor()));
      final grid = heatmapWeeks(countByDate(dates), today, weeks);
      final trained = grid.expand((w) => w).where((d) => d.count > 0).length;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          label: 'Calendario de las últimas $weeks semanas: $trained días con entrenamiento.',
          child: GestureDetector(
            onTapUp: (d) {
              final w = ((d.localPosition.dx - _labelW) / _step).floor();
              final day = ((d.localPosition.dy - _top) / _step).floor();
              if (w < 0 || w >= grid.length || day < 0 || day > 6) return;
              final cell = grid[w][day];
              if (cell.count > 0) onSelectDay?.call(cell.date);
            },
            child: CustomPaint(size: Size(_labelW + weeks * _step, _top + 7 * _step), painter: _HeatmapPainter(grid: grid, today: today, colors: c)),
          ),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _legend(c.bgHard, 1, 'Sin entrenar', c),
          const SizedBox(width: 12),
          _legend(c.primary, 0.6, '1', c),
          const SizedBox(width: 12),
          _legend(c.primary, 1, '2 o más', c),
        ]),
      ]);
    });
  }

  Widget _legend(Color fill, double opacity, String label, AppColors c) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: fill.withValues(alpha: opacity), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: c.faint)),
      ]);
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({required this.grid, required this.today, required this.colors});

  final List<List<HeatDay>> grid;
  final String today;
  final AppColors colors;

  static const _dayLabels = ['L', '', 'X', '', 'V', '', 'D'];

  void _text(Canvas canvas, String text, Offset at, double size) {
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(fontSize: size, color: colors.faint)), textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var w = 0; w < grid.length; w++) {
      final x = Heatmap._labelW + w * Heatmap._step;
      final first = grid[w][0].date;
      if (w > 0 && first.substring(5, 7) != grid[w - 1][0].date.substring(5, 7)) {
        _text(canvas, monthShort(first), Offset(x, 0), 10);
      }
      for (var d = 0; d < 7; d++) {
        final day = grid[w][d];
        final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, Heatmap._top + d * Heatmap._step, Heatmap._cell, Heatmap._cell), const Radius.circular(3));
        if (!day.future) {
          final fill = day.count == 0 ? colors.bgHard : colors.primary.withValues(alpha: day.count == 1 ? 0.6 : 1);
          canvas.drawRRect(rect, Paint()..color = fill);
        } else {
          canvas.drawRRect(rect, Paint()
            ..style = PaintingStyle.stroke
            ..color = colors.border);
        }
        if (day.date == today) {
          canvas.drawRRect(rect, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = colors.fg);
        }
      }
    }
    for (var d = 0; d < 7; d++) {
      if (_dayLabels[d].isNotEmpty) _text(canvas, _dayLabels[d], Offset(0, Heatmap._top + d * Heatmap._step), 9);
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => old.grid != grid || old.colors != colors;
}
