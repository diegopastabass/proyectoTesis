import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/sim_providers.dart';
import '../../app/theme.dart';
import '../../core/common/date.dart';
import '../../core/nutrition/macros.dart';
import '../../core/nutrition/models.dart';
import '../../core/nutrition/score.dart';
import '../../data/simulated/sim_data.dart';
import '../../ui/sim_widgets.dart';
import '../../ui/widgets.dart';
import 'community_widgets.dart';

/// Lista de ejercicios o ingredientes de una publicación.
class _PostContent extends StatelessWidget {
  const _PostContent(this.post);

  final SimPost post;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (post.lines.isNotEmpty) {
      return CardList(header: const CardHeader('Ejercicios', icon: Icons.fitness_center), children: [
        for (final l in post.lines)
          ListTile(
            dense: true,
            title: Text(l.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.fgStrong)),
            subtitle: Text(l.detail, style: TextStyle(fontSize: 12, color: c.muted)),
          ),
      ]);
    }
    if (post.ingredients.isNotEmpty) {
      return CardList(header: const CardHeader('Ingredientes', icon: Icons.kitchen_outlined), children: [
        for (final i in post.ingredients)
          ListTile(
            dense: true,
            title: Text(i.name, style: TextStyle(fontSize: 14, color: c.fgStrong)),
            trailing: Text('${i.grams.round()} g', style: TextStyle(fontSize: 13, color: c.muted, fontFeatures: tabular)),
          ),
      ]);
    }
    return const SizedBox.shrink();
  }
}

/// CU-23: detalle de una publicación, con las acciones de agregar (CU-13, CU-08) y reportar (CU-22).
class PostDetailPage extends ConsumerWidget {
  const PostDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final post = findPost(ref, id);
    if (post == null) return const Scaffold(body: EmptyState(icon: Icons.search_off, title: 'Publicación no encontrada'));
    final added = ref.watch(simProvider).added.contains(id);
    final nutrition = post.kind == SimPostKind.recipe || post.kind == SimPostKind.meal;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicación'),
        actions: [
          IconButton(tooltip: 'Reportar', onPressed: () => context.push('/comunidad/post/$id/reportar'), icon: Icon(Icons.flag_outlined, color: c.muted)),
        ],
      ),
      bottomNavigationBar: BottomActions(children: [
        FilledButton.icon(
          onPressed: added ? null : () => context.push(nutrition ? '/comunidad/post/$id/receta' : '/comunidad/post/$id/agregar'),
          icon: Icon(added ? Icons.check : Icons.add_circle_outline),
          label: Text(added ? 'Ya está en ${post.kind.destination}' : post.kind.addLabel),
        ),
      ]),
      body: PageBody(children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PostAuthorRow(post),
            const SizedBox(height: 12),
            Text(post.title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: c.fgStrong)),
            const SizedBox(height: 6),
            Text(post.text, style: TextStyle(fontSize: 14, height: 1.4, color: c.fg)),
            if (post.photos > 0 || post.routeSeed != null) ...[const SizedBox(height: 12), PostMedia(post, height: 190)],
            if (post.stats.isNotEmpty) ...[const SizedBox(height: 12), StatRow(post.stats)],
          ]),
        ),
        _PostContent(post),
      ]),
    );
  }
}

/// CU-13: agrega una sesión o ruta a los módulos, indicando quién la creó.
class AddPostPage extends ConsumerStatefulWidget {
  const AddPostPage({super.key, required this.id, this.done = false, this.repeated = false});

  final String id;

  /// Muestran directamente el resultado (los usa el modo de capturas).
  final bool done;
  final bool repeated;

  @override
  ConsumerState<AddPostPage> createState() => _AddPostPageState();
}

class _AddPostPageState extends ConsumerState<AddPostPage> {
  late bool _justAdded = widget.done;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final post = findPost(ref, widget.id);
    if (post == null) return const Scaffold(body: EmptyState(icon: Icons.search_off, title: 'Publicación no encontrada'));
    final author = simUser(post.authorId);
    final repeated = widget.repeated || (!_justAdded && ref.watch(simProvider).added.contains(widget.id));
    return Scaffold(
      appBar: AppBar(title: Text(post.kind.addLabel)),
      bottomNavigationBar: BottomActions(children: [
        if (_justAdded || repeated)
          FilledButton(onPressed: () => context.go(post.kind == SimPostKind.route ? '/cardio' : '/fuerza'), child: Text('Ir a ${post.kind.destination}'))
        else ...[
          FilledButton(
            onPressed: () {
              ref.read(simProvider.notifier).add(widget.id);
              setState(() => _justAdded = true);
            },
            child: Text(post.kind.addLabel),
          ),
          OutlinedButton(onPressed: () => context.pop(), child: const Text('Cancelar')),
        ],
      ]),
      body: PageBody(children: [
        if (_justAdded) InfoNote(icon: Icons.check_circle, color: c.success, title: 'Quedó agregada', text: 'La encuentras en ${post.kind.destination}. Es una copia tuya: puedes cambiarla sin afectar la original.'),
        if (repeated) InfoNote(icon: Icons.info_outline, color: c.warning, title: 'Ya la habías agregado', text: 'Está en ${post.kind.destination}, así que no creamos una copia nueva.'),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(post.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.fgStrong)),
            const SizedBox(height: 8),
            Row(children: [
              SimAvatar(author, radius: 13),
              const SizedBox(width: 8),
              Expanded(child: Text('Creada por ${author.name}', style: TextStyle(fontSize: 13, color: c.muted))),
            ]),
            if (post.routeSeed != null) ...[const SizedBox(height: 12), SimRoutePreview(seed: post.routeSeed!, height: 180)],
            if (post.stats.isNotEmpty) ...[const SizedBox(height: 12), StatRow(post.stats)],
          ]),
        ),
        _PostContent(post),
      ]),
    );
  }
}

/// Comidas que quedan en el día (regla de ejemplo).
const _mealsLeft = 2;

/// CU-08: agrega una receta ajustando los ingredientes a lo que falta comer hoy.
class AddRecipePage extends ConsumerStatefulWidget {
  const AddRecipePage({super.key, required this.id, this.done = false, this.goalsMet = false});

  final String id;
  final bool done;

  /// Fuerza el curso alterno "ya cumplió sus metas" (lo usa el modo de capturas).
  final bool goalsMet;

  @override
  ConsumerState<AddRecipePage> createState() => _AddRecipePageState();
}

class _AddRecipePageState extends ConsumerState<AddRecipePage> {
  double? _factor;
  late bool _saved = widget.done;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final post = findPost(ref, widget.id);
    if (post == null || post.macros == null) return const Scaffold(body: EmptyState(icon: Icons.search_off, title: 'Receta no encontrada'));
    final author = simUser(post.authorId);
    final goals = ref.watch(goalsProvider).value ?? defaultGoals;
    final today = todayKey();
    final totals = sumMacros((ref.watch(dayEntriesProvider(today)).value ?? const <DiaryEntry>[]).map((e) => e.macros));
    double remaining(MacroKey k) {
      final r = goals.range(k);
      return ((r.min + r.max) / 2 - totals[k]).clamp(0, double.infinity).toDouble();
    }

    final left = remaining(MacroKey.kcal);
    final metGoals = widget.goalsMet || left < 150;
    // Se mantienen las proporciones: todos los ingredientes usan el mismo factor.
    final suggested = metGoals ? 1.0 : ((left / _mealsLeft / post.macros!.kcal * 20).round() / 20).clamp(0.5, 1.5).toDouble();
    final factor = _factor ?? suggested;
    final adjusted = post.macros!.times(factor);

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar receta')),
      bottomNavigationBar: BottomActions(children: [
        if (_saved)
          FilledButton(onPressed: () => context.go('/recetas'), child: const Text('Ver mis recetas'))
        else ...[
          FilledButton(
            onPressed: () {
              ref.read(simProvider.notifier).add(widget.id);
              setState(() => _saved = true);
            },
            child: const Text('Agregar a mi nutrición'),
          ),
        ],
      ]),
      body: PageBody(children: [
        if (_saved)
          InfoNote(icon: Icons.check_circle, color: c.success, title: 'Receta agregada', text: 'Quedó en tu módulo de nutrición, indicando que la creó ${author.name}. Agregarla no la registra como comida.'),
        Row(children: [
          SimPhoto(icon: Icons.menu_book_outlined, tone: 1, height: 64, width: 64, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.fgStrong)),
              Text('Receta de ${author.name}', style: TextStyle(fontSize: 13, color: c.muted)),
            ]),
          ),
        ]),
        if (metGoals)
          InfoNote(icon: Icons.emoji_events_outlined, color: c.warning, title: 'Ya cumpliste tus metas de hoy', text: 'Puedes guardarla con sus porciones originales y usarla otro día.')
        else
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Lo que te falta comer hoy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted)),
              const SizedBox(height: 8),
              StatRow([
                SimStat('Calorías', '${left.round()} kcal'),
                SimStat('Proteína', '${remaining(MacroKey.protein).round()} g'),
                SimStat('Carbohidratos', '${remaining(MacroKey.carbs).round()} g'),
              ]),
              const SizedBox(height: 8),
              Text('Lo repartimos entre las $_mealsLeft comidas que te quedan hoy.', style: TextStyle(fontSize: 12, color: c.faint)),
            ]),
          ),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Porción ajustada', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong))),
              Text('× ${factor.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.primary, fontFeatures: tabular)),
            ]),
            Slider(value: factor, min: 0.5, max: 1.5, divisions: 20, onChanged: _saved ? null : (v) => setState(() => _factor = v)),
            StatRow([
              SimStat('Calorías', '${adjusted.kcal.round()} kcal'),
              SimStat('Proteína', '${adjusted.protein.round()} g'),
              SimStat('Carbohidratos', '${adjusted.carbs.round()} g'),
              SimStat('Grasa', '${adjusted.fat.round()} g'),
            ]),
          ]),
        ),
        CardList(header: const CardHeader('Ingredientes ajustados', icon: Icons.kitchen_outlined), children: [
          for (final i in post.ingredients)
            ListTile(
              dense: true,
              title: Text(i.name, style: TextStyle(fontSize: 14, color: c.fgStrong)),
              subtitle: Text('Original: ${i.grams.round()} g', style: TextStyle(fontSize: 12, color: c.faint)),
              trailing: Text('${(i.grams * factor).round()} g', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.fgStrong, fontFeatures: tabular)),
            ),
        ]),
      ]),
    );
  }
}

const _motives = [
  ('Contenido inapropiado', 'Ofensivo, violento o de contenido sexual.'),
  ('Peligroso para la salud', 'Dietas extremas, sustancias o ejercicios riesgosos.'),
  ('Foto sin permiso', 'Aparece alguien que no autorizó su publicación.'),
  ('Publicidad o spam', 'Promociona productos o se repite sin aportar.'),
  ('Otro motivo', 'No calza con los anteriores.'),
];

/// CU-22: reportar una publicación.
class ReportPostPage extends ConsumerStatefulWidget {
  const ReportPostPage({super.key, required this.id, this.done = false, this.selected});

  final String id;
  final bool done;
  final int? selected;

  @override
  ConsumerState<ReportPostPage> createState() => _ReportPostPageState();
}

class _ReportPostPageState extends ConsumerState<ReportPostPage> {
  late int? _motive = widget.selected;
  late bool _sent = widget.done;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final post = findPost(ref, widget.id);
    if (post == null) return const Scaffold(body: EmptyState(icon: Icons.search_off, title: 'Publicación no encontrada'));
    final repeated = !_sent && ref.watch(simProvider).reported.contains(widget.id);
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar publicación')),
      bottomNavigationBar: BottomActions(children: [
        if (_sent || repeated)
          FilledButton(onPressed: () => context.go('/comunidad'), child: const Text('Volver al muro'))
        else ...[
          FilledButton(
            onPressed: _motive == null
                ? null
                : () {
                    ref.read(simProvider.notifier).report(widget.id);
                    setState(() => _sent = true);
                  },
            child: const Text('Enviar reporte'),
          ),
          OutlinedButton(onPressed: () => context.pop(), child: const Text('Cancelar')),
        ],
      ]),
      body: PageBody(children: [
        if (_sent)
          InfoNote(icon: Icons.check_circle, color: c.success, title: 'Gracias por avisar', text: 'El equipo revisará la publicación. Mientras tanto dejará de aparecer en tu muro.')
        else if (repeated)
          InfoNote(icon: Icons.info_outline, color: c.warning, title: 'Ya la reportaste', text: 'Tu reporte está en revisión. No es necesario enviarlo de nuevo.')
        else ...[
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              SimAvatar(simUser(post.authorId)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
                  Text('De ${simUser(post.authorId).name}', style: TextStyle(fontSize: 12, color: c.muted)),
                ]),
              ),
            ]),
          ),
          const SectionTitle('¿Cuál es el motivo?'),
          CardList(children: [
            for (var i = 0; i < _motives.length; i++)
              OptionTile(title: _motives[i].$1, subtitle: _motives[i].$2, selected: _motive == i, onTap: () => setState(() => _motive = i)),
          ]),
          Text('Quien publicó no sabrá que fuiste tú.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.muted)),
        ],
      ]),
    );
  }
}
