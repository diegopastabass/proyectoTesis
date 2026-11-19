/// Registro con ayuda del asistente de IA (Gemini): CU-07 (comida con foto),
/// CU-16 (comida con palabras) y CU-02 (sesión de fuerza con palabras).
///
/// El asistente propone y el usuario siempre revisa antes de guardar. Los macros
/// de los alimentos salen del catálogo cuando están en él (`core/ai/estimate.dart`),
/// y lo que el asistente no tiene claro (confianza bajo 70 %) se debe revisar.
/// Si el asistente falla o no está configurado, se ofrece el registro manual.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/ai/ai_models.dart';
import '../../core/ai/estimate.dart';
import '../../core/ai/strength_import.dart';
import '../../core/common/date.dart';
import '../../core/common/numbers.dart';
import '../../core/nutrition/models.dart';
import '../../core/nutrition/resolve.dart';
import '../../data/ai/ai_service.dart';
import '../../data/simulated/sim_data.dart' show SimStat;
import '../../ui/format.dart';
import '../../ui/sim_widgets.dart';
import '../../ui/widgets.dart';
import '../strength/exercise_widgets.dart';
import 'photo_picker.dart';

/// Etapas de los flujos: escribir o sacar la foto, esperar al asistente y revisar.
enum _Step { input, working, review }

/// Ejemplo para conocer la función de fuerza.
const strengthExample =
    'Sentadilla, 4 series de 8 con 80 kilos. Después peso muerto rumano 3 de 10 con 60. Terminé con wall balls, 3 series de 20 con un balón de 6 kilos.';

String _errorText(Object e) => e is AiException ? e.message : 'Algo falló con el asistente. Prueba otra vez o registra a mano.';

class _Working extends StatelessWidget {
  const _Working(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 3.5, color: c.primary)),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong),
        ),
        const SizedBox(height: 4),
        Text(
          'Puedes revisar y corregir el resultado antes de guardar.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: c.muted),
        ),
      ],
    );
  }
}

/// Qué se envía y a quién (y si es un ejemplo).
class _PrivacyNote extends ConsumerWidget {
  const _PrivacyNote({required this.what});

  /// "La foto", "El texto"…
  final String what;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ai = ref.watch(aiServiceProvider);
    final text = switch (ai.mode) {
      AiMode.gemini =>
        '$what se envía a Gemini (Google) solo para esta estimación, sin tu nombre ni tus datos. '
            'En el nivel gratuito, Google puede usar lo enviado para mejorar sus productos.',
      AiMode.demo => 'Modo demostración: el asistente responde un ejemplo fijo, sin enviar nada.',
      AiMode.off => '',
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(text, style: TextStyle(fontSize: 11, height: 1.35, color: c.faint));
  }
}

/// Sin asistente configurado: se explica y se ofrece lo manual.
class _AiOff extends StatelessWidget {
  const _AiOff({required this.manual, required this.manualRoute});

  final String manual;
  final String manualRoute;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PageBody(
      children: [
        InfoNote(
          icon: Icons.auto_awesome,
          color: c.warning,
          title: 'El asistente no está configurado',
          text: 'Falta la clave de la API de Gemini en env/gemini.json (ver el README de la app). Mientras tanto puedes $manual.',
        ),
        FilledButton(onPressed: () => context.go(manualRoute), child: Text(capitalize(manual))),
      ],
    );
  }
}

/// Campo para escribir (o dictar con el teclado de iOS), compartido por CU-02 y CU-16.
class _TypeHere extends StatelessWidget {
  const _TypeHere({required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            minLines: 5,
            maxLines: 9,
            decoration: InputDecoration(hintText: hint),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.mic_none, size: 16, color: c.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('También puedes dictar con el micrófono del teclado.', style: TextStyle(fontSize: 12, color: c.muted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Revisión de una comida estimada (CU-07 y CU-16)
// ---------------------------------------------------------------------------

class _MealReview extends ConsumerStatefulWidget {
  const _MealReview({required this.items, required this.via, this.leading, this.note});

  final List<EstimatedItem> items;

  /// Cómo se registró (queda en el diario: "IA: foto", "IA: texto").
  final String via;
  final Widget? leading;

  /// Aviso del asistente.
  final String? note;

  @override
  ConsumerState<_MealReview> createState() => _MealReviewState();
}

class _MealReviewState extends ConsumerState<_MealReview> {
  late List<EstimatedItem> _items = [...widget.items];
  MealSlot _meal = mealForNow();
  bool _saving = false;

  ResolveContext? get _ctx => ref.read(nutritionDataProvider).value?.ctx;

  void _setGrams(int i, String text) {
    final g = parseNum(text);
    final ctx = _ctx;
    if (g == null || g <= 0 || ctx == null) return;
    setState(() => _items[i] = _items[i].withGrams(g, ctx));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final date = todayKey();
    final entries = [for (final e in _items) e.toEntry(_meal, via: widget.via)];
    final ok = await runGuarded(context, () => ref.read(nutritionActionsProvider).addEntries(date, entries), success: 'Comida guardada en tu diario');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.go('/?d=$date');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = totalOf(_items);
    final pending = _items.where((e) => e.needsReview).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Revisa tu comida')),
      bottomNavigationBar: BottomActions(
        children: [
          FilledButton(
            onPressed: _items.isEmpty || pending > 0 || _saving ? null : _save,
            child: Text(pending > 0 ? 'Revisa ${pending == 1 ? '1 alimento' : '$pending alimentos'} para guardar' : 'Guardar en mi diario'),
          ),
        ],
      ),
      body: PageBody(
        children: [
          ?widget.leading,
          if (widget.note != null) InfoNote(icon: Icons.info_outline, text: widget.note!),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Estimación de la comida',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted),
                ),
                const SizedBox(height: 8),
                StatRow([
                  SimStat('Calorías', '${total.kcal.round()} kcal'),
                  SimStat('Proteína', '${total.protein.round()} g'),
                  SimStat('Carbohidr.', '${total.carbs.round()} g'),
                  SimStat('Grasa', '${total.fat.round()} g'),
                ]),
              ],
            ),
          ),
          if (pending > 0)
            InfoNote(
              icon: Icons.warning_amber_rounded,
              color: c.warning,
              title: 'Revisa lo marcado',
              text: 'El asistente no está seguro de ${pending == 1 ? 'un alimento' : 'algunos alimentos'}. Corrige los gramos o confírmalo para guardar.',
            ),
          if (_items.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.no_food_outlined,
                title: 'No hay alimentos',
                message: 'Vuelve atrás para intentarlo de nuevo o regístralos a mano.',
              ),
            ),
          if (_items.isNotEmpty)
            CardList(
              header: const CardHeader('Alimentos detectados', icon: Icons.restaurant),
              children: [for (var i = 0; i < _items.length; i++) _itemTile(i, c)],
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in MealSlot.values)
                ChoiceChip(
                  avatar: Icon(mealMeta[m]!.icon, size: 16, color: m == _meal ? c.onPrimary : c.muted),
                  label: Text(mealMeta[m]!.label),
                  selected: m == _meal,
                  onSelected: (_) => setState(() => _meal = m),
                ),
            ],
          ),
          Text(
            'Los macros de los alimentos del catálogo salen del catálogo; los demás son estimaciones del asistente.',
            style: TextStyle(fontSize: 11, color: c.faint),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(int i, AppColors c) {
    final e = _items[i];
    final review = e.needsReview;
    final origin = switch (e.source) {
      EstimateSource.catalog => 'del catálogo',
      EstimateSource.rules => 'de tu lista',
      EstimateSource.model => 'estimado por el asistente',
    };
    return ListTile(
      key: ValueKey('$i-${e.name}'),
      dense: true,
      leading: review
          ? IconButton(
              tooltip: 'Confirmar ${e.name}',
              onPressed: () => setState(() => _items[i] = e.copyWith(confirmed: true)),
              icon: Icon(Icons.help_outline, color: c.warning),
            )
          : Icon(Icons.check_circle_outline, size: 20, color: c.success),
      title: Text(e.name, style: TextStyle(fontSize: 14, color: c.fgStrong)),
      subtitle: Text(
        '${e.macros.kcal.round()} kcal · P ${e.macros.protein.round()} · C ${e.macros.carbs.round()} · G ${e.macros.fat.round()} · $origin'
        '${review ? ' · confianza ${e.confidence.round()} %' : ''}',
        style: TextStyle(fontSize: 12, color: review ? c.warning : c.muted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NumberField(
            initialValue: plainEs(e.grams.round()),
            width: 58,
            dense: true,
            textAlign: TextAlign.center,
            decimal: false,
            onChanged: (v) => _setGrams(i, v),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('g', style: TextStyle(fontSize: 13, color: c.muted)),
          ),
          IconButton(
            tooltip: 'Quitar ${e.name}',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _items = [..._items]..removeAt(i)),
            icon: Icon(Icons.close, size: 18, color: c.faint),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CU-07: comida con una foto
// ---------------------------------------------------------------------------

class AiPhotoPage extends ConsumerStatefulWidget {
  const AiPhotoPage({super.key, this.estado});

  /// 'analizando' o 'revision': empieza con la foto de ejemplo (capturas del documento).
  final String? estado;

  @override
  ConsumerState<AiPhotoPage> createState() => _AiPhotoPageState();
}

class _AiPhotoPageState extends ConsumerState<AiPhotoPage> {
  _Step _step = _Step.input;
  Uint8List? _photo;
  AiMeal? _meal;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.estado != null && ref.read(aiServiceProvider).mode == AiMode.demo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _analyze(Uint8List(0), stayWorking: widget.estado == 'analizando'));
    }
  }

  Future<void> _take() async {
    final photo = await ref.read(photoSourceProvider)(context, title: 'Foto de tu plato');
    if (photo != null && mounted) await _analyze(photo);
  }

  Future<void> _analyze(Uint8List photo, {bool stayWorking = false}) async {
    setState(() {
      _photo = photo;
      _step = _Step.working;
      _error = null;
    });
    if (stayWorking) return;
    try {
      final meal = await ref.read(aiServiceProvider).mealFromPhoto(photo);
      if (mounted) {
        setState(() {
          _meal = meal;
          _step = _Step.review;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _step = _Step.input;
        });
      }
    }
  }

  Widget _photoView({double height = 120}) {
    final p = _photo;
    if (p == null || p.isEmpty) return SimPhoto(icon: Icons.restaurant, tone: 0, height: height);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.memory(
        p,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => SimPhoto(icon: Icons.restaurant, tone: 0, height: height),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ai = ref.watch(aiServiceProvider);
    if (ai.mode == AiMode.off) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comida con foto')),
        body: const _AiOff(manual: 'registrar la comida con tu lista', manualRoute: '/registrar'),
      );
    }
    final data = ref.watch(nutritionDataProvider).value;
    if (_step == _Step.review && _meal != null && data != null) {
      return _MealReview(
        items: [for (final f in _meal!.items) estimateFromAi(f, data.ctx)],
        via: 'IA: foto',
        note: _meal!.note ?? (_meal!.items.isEmpty ? 'El asistente no encontró alimentos en la foto.' : null),
        leading: _photoView(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_step == _Step.working ? 'Analizando la foto' : 'Comida con foto')),
      bottomNavigationBar: _step == _Step.input
          ? BottomActions(
              children: [FilledButton.icon(onPressed: _take, icon: const Icon(Icons.photo_camera_outlined), label: const Text('Sacar o elegir una foto'))],
            )
          : null,
      body: switch (_step) {
        _Step.working => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [_photoView(height: 210), const SizedBox(height: 22), const _Working('El asistente está mirando tu plato…')],
            ),
          ),
        ),
        _ => PageBody(
          children: [
            if (_error != null) InfoNote(icon: Icons.error_outline, color: c.danger, title: 'No se pudo usar el asistente', text: _errorText(_error!)),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.restaurant, size: 40, color: c.primary),
                  const SizedBox(height: 10),
                  Text(
                    'Encuadra tu plato completo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.fgStrong),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Desde arriba, con buena luz y todo a la vista. El asistente estima los alimentos y los gramos; tú los revisas antes de guardar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.35, color: c.muted),
                  ),
                ],
              ),
            ),
            const _PrivacyNote(what: 'La foto'),
            if (_error != null) OutlinedButton(onPressed: () => context.go('/registrar'), child: const Text('Registrar con mi lista')),
          ],
        ),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// CU-16: comida con mis palabras
// ---------------------------------------------------------------------------

class AiMealTextPage extends ConsumerStatefulWidget {
  const AiMealTextPage({super.key, this.estado, this.initialText});

  /// 'revision': empieza con un ejemplo ya estimado (capturas del documento).
  final String? estado;

  /// Texto que viene de la lista ("lo que las reglas no entendieron").
  final String? initialText;

  @override
  ConsumerState<AiMealTextPage> createState() => _AiMealTextPageState();
}

class _AiMealTextPageState extends ConsumerState<AiMealTextPage> {
  _Step _step = _Step.input;
  late final _text = TextEditingController(
    text: widget.initialText ?? (widget.estado == null ? '' : '1 taza de arroz\nUn plato de porotos con riendas y una ensalada'),
  );
  List<EstimatedItem>? _items;
  String? _note;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.estado == 'revision' && ref.read(aiServiceProvider).mode == AiMode.demo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _estimate());
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _estimate() async {
    FocusScope.of(context).unfocus();
    final data = ref.read(nutritionDataProvider).value;
    if (data == null) {
      showToast(context, 'Cargando el catálogo de alimentos… prueba en un momento');
      return;
    }
    setState(() {
      _step = _Step.working;
      _error = null;
    });
    // Primero las reglas (sin red, sin costo); al asistente solo va lo que no entendieron.
    final split = splitByRules(_text.text, data.ctx);
    try {
      AiMeal? meal;
      if (split.pending.isNotEmpty) meal = await ref.read(aiServiceProvider).mealFromText(split.pending.join('\n'));
      if (!mounted) return;
      setState(() {
        _items = [...split.resolved, for (final f in meal?.items ?? const <AiFood>[]) estimateFromAi(f, data.ctx)];
        _note = meal?.note;
        _step = _Step.review;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _step = _Step.input;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ai = ref.watch(aiServiceProvider);
    // Mantiene cargado el catálogo para cruzar lo que diga el asistente.
    ref.watch(nutritionDataProvider);
    if (ai.mode == AiMode.off) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contar mi comida')),
        body: const _AiOff(manual: 'registrar la comida con tu lista', manualRoute: '/registrar'),
      );
    }
    if (_step == _Step.review && _items != null) {
      return _MealReview(
        items: _items!,
        via: 'IA: texto',
        note: _note,
        leading: AppCard(
          padding: const EdgeInsets.all(12),
          child: Text(
            '«${_text.text.trim()}»',
            style: TextStyle(fontSize: 13, height: 1.4, fontStyle: FontStyle.italic, color: c.muted),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Contar mi comida')),
      bottomNavigationBar: _step == _Step.input
          ? BottomActions(
              children: [
                FilledButton.icon(
                  onPressed: _text.text.trim().isEmpty ? null : _estimate,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Estimar con el asistente'),
                ),
              ],
            )
          : null,
      body: _step == _Step.working
          ? const Center(
              child: Padding(padding: EdgeInsets.all(24), child: _Working('El asistente está estimando tu comida…')),
            )
          : PageBody(
              children: [
                if (_error != null) InfoNote(icon: Icons.error_outline, color: c.danger, title: 'No se pudo usar el asistente', text: _errorText(_error!)),
                const InfoNote(
                  icon: Icons.auto_awesome,
                  text: 'Describe lo que comiste con tus palabras. Lo que la app entiende sola se toma del catálogo; el asistente solo estima el resto.',
                ),
                _TypeHere(controller: _text, hint: 'Un plato de porotos con riendas y una ensalada…', onChanged: () => setState(() {})),
                const _PrivacyNote(what: 'El texto que la app no entienda sola'),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// CU-02: sesión de fuerza con mis palabras
// ---------------------------------------------------------------------------

class AiStrengthPage extends ConsumerStatefulWidget {
  const AiStrengthPage({super.key, this.estado});

  /// 'analizando' o 'revision': empieza con el ejemplo (capturas del documento).
  final String? estado;

  @override
  ConsumerState<AiStrengthPage> createState() => _AiStrengthPageState();
}

class _AiStrengthPageState extends ConsumerState<AiStrengthPage> {
  _Step _step = _Step.input;
  late final _text = TextEditingController(text: widget.estado == null ? '' : strengthExample);
  List<ImportedExercise>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.estado != null && ref.read(aiServiceProvider).mode == AiMode.demo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.estado == 'analizando' ? setState(() => _step = _Step.working) : _organize());
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _organize() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = _Step.working;
      _error = null;
    });
    try {
      final parsed = await ref.read(aiServiceProvider).strengthFromText(_text.text);
      if (!mounted) return;
      // El catálogo ya está cargado (la pantalla lo escucha); si no, se espera.
      final index = ref.read(exercisesProvider).value?.index ?? ExerciseCatalog(await ref.read(exerciseCatalogProvider.future)).index;
      if (!mounted) return;
      setState(() {
        _items = matchExercises(parsed, index);
        _step = _Step.review;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _step = _Step.input;
        });
      }
    }
  }

  Future<void> _pick(int i) async {
    final e = await pickExercise(context);
    if (e != null && mounted) setState(() => _items![i] = _items![i].pick(e));
  }

  Future<void> _continue() async {
    final items = _items!;
    if (ref.read(activeWorkoutProvider) != null &&
        !await confirm(context, 'Ya tienes un entrenamiento en curso. ¿Reemplazarlo por la sesión contada?', accept: 'Reemplazar', destructive: true)) {
      return;
    }
    if (!mounted) return;
    ref.read(activeWorkoutProvider.notifier).set(workoutFromImport(items, now: DateTime.now().millisecondsSinceEpoch));
    showToast(context, 'Revisa las series y toca Terminar para guardar');
    context.go('/fuerza/entrenar');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ai = ref.watch(aiServiceProvider);
    if (ai.mode == AiMode.off) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contar mi sesión')),
        body: const _AiOff(manual: 'anotar la sesión con el formulario', manualRoute: '/fuerza'),
      );
    }
    // Mantiene cargado el catálogo de ejercicios para cruzar lo que diga el asistente.
    ref.watch(exercisesProvider);
    final items = _items;
    final unknown = items?.where((i) => !i.recognized).length ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(_step == _Step.review ? 'Revisa tu sesión' : 'Contar mi sesión')),
      bottomNavigationBar: switch (_step) {
        _Step.input => BottomActions(
          children: [
            FilledButton.icon(
              onPressed: _text.text.trim().isEmpty ? null : _organize,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Ordenar con el asistente'),
            ),
            OutlinedButton(onPressed: () => context.go('/fuerza'), child: const Text('Usar el formulario')),
          ],
        ),
        _Step.working => null,
        _Step.review => BottomActions(
          children: [
            FilledButton(
              onPressed: items == null || items.isEmpty || unknown > 0 ? null : _continue,
              child: Text(unknown > 0 ? 'Elige ${unknown == 1 ? 'el ejercicio que falta' : 'los $unknown ejercicios que faltan'}' : 'Revisar y guardar'),
            ),
          ],
        ),
      },
      body: switch (_step) {
        _Step.input => PageBody(
          children: [
            if (_error != null) InfoNote(icon: Icons.error_outline, color: c.danger, title: 'No se pudo usar el asistente', text: _errorText(_error!)),
            const InfoNote(
              icon: Icons.auto_awesome,
              text: 'Cuéntalo como se lo dirías a alguien: qué ejercicios hiciste, cuántas series y con cuánto peso (en kilos o libras).',
            ),
            _TypeHere(controller: _text, hint: 'Sentadilla, 4 series de 8 con 80 kilos…', onChanged: () => setState(() {})),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _text.text = strengthExample),
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: const Text('Ver un ejemplo'),
              ),
            ),
            const _PrivacyNote(what: 'El texto'),
          ],
        ),
        _Step.working => const Center(
          child: Padding(padding: EdgeInsets.all(24), child: _Working('El asistente está ordenando tu sesión…')),
        ),
        _Step.review => PageBody(
          children: [
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Text(
                '«${_text.text.trim()}»',
                style: TextStyle(fontSize: 13, height: 1.4, fontStyle: FontStyle.italic, color: c.muted),
              ),
            ),
            if (items != null && items.isEmpty)
              const AppCard(
                child: EmptyState(
                  icon: Icons.fitness_center,
                  title: 'No encontramos ejercicios',
                  message: 'Vuelve atrás y cuéntalo con más detalle, o usa el formulario.',
                ),
              ),
            if (unknown > 0)
              InfoNote(
                icon: Icons.help_outline,
                color: c.warning,
                title: unknown == 1 ? 'Falta confirmar un ejercicio' : 'Faltan confirmar $unknown ejercicios',
                text: unknown == 1 ? 'No reconocimos un ejercicio en la lista. Elígelo para poder guardar.' : 'No reconocimos algunos ejercicios en la lista. Elígelos para poder guardar.',
              ),
            for (var i = 0; i < (items?.length ?? 0); i++) _ExerciseCard(item: items![i], onPick: () => _pick(i)),
            Text(
              'Al continuar se abre como un entrenamiento con todo marcado: revisa las series y toca Terminar para guardarlo.',
              style: TextStyle(fontSize: 11, color: c.faint),
            ),
          ],
        ),
      },
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.item, required this.onPick});

  final ImportedExercise item;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pending = !item.recognized;
    final s = item.source;
    return AppCard(
      padding: const EdgeInsets.all(12),
      borderColor: pending ? c.warning : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(pending ? Icons.help_outline : Icons.check_circle, size: 18, color: pending ? c.warning : c.success),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.exercise?.name ?? (s.name.isEmpty ? s.written : s.name),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong),
                    ),
                    if (s.written.isNotEmpty) Text('Escribiste: «${s.written}»', style: TextStyle(fontSize: 11, color: c.faint)),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: onPick,
                child: Text(pending ? 'Elegir' : 'Cambiar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < s.sets.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: ShapeDecoration(color: c.surface2.withValues(alpha: 0.7), shape: smoothShape(9)),
                  child: Text(
                    '${s.sets[i].warmup ? 'C' : '${i + 1}.'}  ${setLabel(s.sets[i], item.unit)}',
                    style: TextStyle(fontSize: 12, color: c.fg, fontFeatures: tabular),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
