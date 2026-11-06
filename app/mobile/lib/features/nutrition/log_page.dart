import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/date.dart';
import '../../core/common/numbers.dart';
import '../../core/nutrition/macros.dart';
import '../../core/nutrition/matcher.dart';
import '../../core/nutrition/models.dart';
import '../../core/nutrition/resolve.dart';
import '../../core/nutrition/rule_parser.dart';
import '../../ui/format.dart';
import '../../ui/macros.dart';
import '../../ui/widgets.dart';
import 'barcode_scanner_page.dart';
import 'food_form_page.dart';
import 'food_picker.dart';

const _placeholder = 'Arroz 100g\n1 Tomate mediano\nHuevos x3\nAtún 150g';

/// Registrar: lista en lenguaje natural → alimentos con gramos y macros.
class LogPage extends ConsumerStatefulWidget {
  const LogPage({super.key, this.initialDate, this.initialMeal});

  final String? initialDate;

  /// Comida elegida al llegar desde un recordatorio; si no, se propone según la hora.
  final MealSlot? initialMeal;

  @override
  ConsumerState<LogPage> createState() => _LogPageState();
}

class _LogPageState extends ConsumerState<LogPage> {
  late String _date = isDateKey(widget.initialDate) ? widget.initialDate! : todayKey();
  late MealSlot _meal = widget.initialMeal ?? mealForNow();
  final _text = TextEditingController();
  List<ResolvedItem>? _items;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _analyze(ResolveContext ctx) {
    FocusScope.of(context).unfocus();
    // Los ítems escaneados se conservan al volver a analizar el texto.
    final scanned = (_items ?? const <ResolvedItem>[]).where((it) => it.key.startsWith('scan-')).toList();
    // Con el campo vacío (y nada escaneado) se analiza el ejemplo, para probar rápido el flujo.
    final input = _text.text.trim().isNotEmpty ? _text.text : (scanned.isNotEmpty ? '' : _placeholder);
    if (input != _text.text) _text.text = input;
    setState(() => _items = [...resolveText(input, ctx), ...scanned]);
  }

  void _update(String key, ResolvedItem Function(ResolvedItem) fn) =>
      setState(() => _items = [for (final it in _items ?? const <ResolvedItem>[]) it.key == key ? fn(it) : it]);

  Candidate _forced(Food food) => Candidate(kind: EntryKind.food, id: food.id, name: food.name, confidence: 1);

  /// Agrega un alimento escaneado con su porción por defecto, para que el usuario la ajuste.
  void _addScanned(Food food, String code, ResolveContext ctx) {
    final parsed = ParsedItem(raw: 'Código $code', query: food.name);
    final item = resolveItem(parsed, ctx.withFood(food), 'scan-$code-${DateTime.now().millisecondsSinceEpoch}', forced: _forced(food));
    setState(() => _items = [...?_items, item.withStatus(item.assumed ? ItemStatus.review : ItemStatus.ok)]);
    showToast(context, '${food.name}: ajusta la porción');
  }

  Future<void> _scan(ResolveContext ctx) async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    final match = ctx.foods.values.where((f) => f.barcode == code).firstOrNull;
    if (match != null) {
      _addScanned(match, code, ctx);
      return;
    }
    // Código que no está en el catálogo: se abre el formulario para crearlo.
    final created = await openFoodForm(context, initialBarcode: code, autoLookup: true);
    if (created != null && mounted) _addScanned(created, code, ctx);
  }

  Future<void> _create(ResolvedItem item, String name, ResolveContext ctx) async {
    final food = await openFoodForm(context, initialName: name);
    // Se asigna sin esperar a que el alimento llegue al catálogo.
    if (food != null && mounted) _update(item.key, (it) => resolveItem(it.parsed, ctx.withFood(food), it.key, forced: _forced(food)));
  }

  Future<void> _pick(ResolvedItem item, ResolveContext ctx) async {
    final result = await showFoodPicker(context, matcher: ctx.matcher, ctx: ctx, title: 'Elegir alimento o receta', initialQuery: item.parsed.query);
    if (!mounted) return;
    switch (result) {
      case Picked(:final candidate):
        _update(item.key, (it) => resolveItem(it.parsed, ctx, it.key, forced: candidate));
      case CreateRequested(:final name):
        await _create(item, name, ctx);
      case null:
        break;
    }
  }

  Future<void> _save() async {
    final items = _items;
    if (items == null) return;
    final entries = [
      for (final it in items)
        NewDiaryEntry(
          kind: it.match!.kind,
          refId: it.match!.id,
          name: it.match!.name,
          grams: it.grams,
          servings: it.servings,
          macros: it.macros,
          meal: _meal,
          rawInput: it.parsed.raw,
        ),
    ];
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () => ref.read(nutritionActionsProvider).addEntries(_date, entries),
      success: '${entries.length} ${entries.length == 1 ? 'alimento registrado' : 'alimentos registrados'}',
    );
    if (!mounted) return;
    if (ok) {
      context.go('/?d=$_date');
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final data = ref.watch(nutritionDataProvider);
    final ctx = data.value?.ctx;
    final items = _items;
    final counts = {for (final s in ItemStatus.values) s: items?.where((i) => i.status == s).length ?? 0};
    final totals = sumMacros((items ?? const <ResolvedItem>[]).where((i) => i.match != null).map((i) => i.macros));
    final canSave = items != null && items.isNotEmpty && counts[ItemStatus.missing] == 0 && !_saving;

    return PageBody(children: [
      DateNav(date: _date, onChanged: (d) => setState(() => _date = d)),
      Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
        for (final m in MealSlot.values)
          ChoiceChip(
            avatar: Icon(mealMeta[m]!.icon, size: 16, color: m == _meal ? c.primary : c.muted),
            label: Text(mealMeta[m]!.label),
            selected: m == _meal,
            onSelected: (_) => setState(() => _meal = m),
          ),
      ]),
      if (data is AsyncError) ErrorView(data.error!),
      AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter, meta: true): () => ctx != null ? _analyze(ctx) : null,
              const SingleActivator(LogicalKeyboardKey.enter, control: true): () => ctx != null ? _analyze(ctx) : null,
            },
            child: TextField(
              controller: _text,
              minLines: 5,
              maxLines: 12,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 14, height: 1.5),
              decoration: const InputDecoration(hintText: _placeholder),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('Una línea por alimento', style: TextStyle(fontSize: 11, color: c.faint))),
            IconButton.filledTonal(
              tooltip: 'Escanear código de barras',
              onPressed: ctx == null ? null : () => _scan(ctx),
              icon: const Icon(Icons.qr_code_scanner),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: ctx == null ? null : () => _analyze(ctx),
              icon: const Icon(Icons.document_scanner_outlined, size: 18),
              label: const Text('Analizar'),
            ),
          ]),
        ]),
      ),
      if (items != null && ctx != null)
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No se reconocieron ítems en el texto.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.muted)),
              ),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(),
              _ItemRow(
                key: ValueKey(items[i].key),
                item: items[i],
                onPick: () => _pick(items[i], ctx),
                onCreate: () => _create(items[i], items[i].parsed.query, ctx),
                onGrams: (g) => _update(items[i].key, (x) => withGrams(x, g, ctx)),
                onRemove: () => setState(() => _items = items.where((x) => x.key != items[i].key).toList()),
              ),
            ],
            if (items.isNotEmpty) ...[
              const Divider(),
              Container(
                color: c.surface2.withValues(alpha: 0.5),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      MacroInline(totals, fontSize: 13),
                      const SizedBox(height: 2),
                      Text(
                        '${counts[ItemStatus.ok]} ok · ${counts[ItemStatus.review]} revisar · ${counts[ItemStatus.missing]} faltan'
                        '${counts[ItemStatus.missing]! > 0 ? ' — crea o busca los faltantes para guardar' : ''}',
                        style: TextStyle(fontSize: 11, color: c.faint),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(onPressed: canSave ? _save : null, icon: const Icon(Icons.check), label: const Text('Guardar')),
                ]),
              ),
            ],
          ]),
        ),
    ]);
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({super.key, required this.item, required this.onPick, required this.onCreate, required this.onGrams, required this.onRemove});

  final ResolvedItem item;
  final VoidCallback onPick;
  final VoidCallback onCreate;
  final ValueChanged<double> onGrams;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, color, label) = switch (item.status) {
      ItemStatus.ok => (Icons.check_circle_outline, c.success, 'Reconocido'),
      ItemStatus.review => (Icons.error_outline, c.warning, 'Revisar coincidencia o cantidad'),
      ItemStatus.missing => (Icons.help_outline, c.danger, 'No está en el catálogo'),
    };
    final match = item.match;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Tooltip(message: label, child: Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 18, color: color))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.parsed.raw, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Menlo', fontSize: 11, color: c.faint)),
            if (match != null) ...[
              InkWell(
                onTap: onPick,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    if (match.kind == EntryKind.recipe) ...[Icon(Icons.menu_book_outlined, size: 14, color: c.primary), const SizedBox(width: 4)],
                    Flexible(child: Text(match.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.fg))),
                    const SizedBox(width: 6),
                    Text('${(match.confidence * 100).round()}%', style: TextStyle(fontSize: 10, color: c.faint)),
                    Icon(Icons.unfold_more, size: 14, color: c.faint),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                _GramsInput(grams: item.grams, onCommit: onGrams),
                Text(item.label, style: TextStyle(fontSize: 11, color: item.assumed ? c.warning : c.faint)),
                MacroInline(item.macros, fontSize: 11),
              ]),
            ] else
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('"${item.parsed.query}" no está en el catálogo', style: TextStyle(fontSize: 13, color: c.fg)),
                TextButton.icon(onPressed: onPick, icon: const Icon(Icons.search, size: 16), label: const Text('Buscar')),
                TextButton.icon(onPressed: onCreate, icon: const Icon(Icons.add, size: 16), label: const Text('Crear')),
              ]),
          ]),
        ),
        IconButton(tooltip: 'Quitar de la lista', onPressed: onRemove, icon: Icon(Icons.close, size: 18, color: c.muted)),
      ]),
    );
  }
}

/// Gramos editables; se aplican al salir del campo o con "listo".
class _GramsInput extends StatefulWidget {
  const _GramsInput({required this.grams, required this.onCommit});

  final double grams;
  final ValueChanged<double> onCommit;

  @override
  State<_GramsInput> createState() => _GramsInputState();
}

class _GramsInputState extends State<_GramsInput> {
  late final _controller = TextEditingController(text: plain(widget.grams));
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_GramsInput old) {
    super.didUpdateWidget(old);
    if (old.grams != widget.grams && !_focus.hasFocus) _controller.text = plain(widget.grams);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final g = parseNum(_controller.text);
    if (g != null && g >= 0 && g != widget.grams) {
      widget.onCommit(g);
    } else {
      _controller.text = plain(widget.grams);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      NumberField(controller: _controller, focusNode: _focus, width: 64, dense: true, textAlign: TextAlign.right, onSubmitted: (_) => _commit()),
      const SizedBox(width: 4),
      Text('g', style: TextStyle(fontSize: 12, color: context.colors.faint)),
    ]);
  }
}
