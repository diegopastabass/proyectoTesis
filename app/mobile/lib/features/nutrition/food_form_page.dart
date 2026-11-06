import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/normalize.dart';
import '../../core/common/numbers.dart';
import '../../core/nutrition/barcode.dart';
import '../../core/nutrition/macros.dart';
import '../../core/nutrition/models.dart';
import '../../core/nutrition/open_food_facts.dart';
import '../../ui/format.dart';
import '../../ui/widgets.dart';
import 'barcode_scanner_page.dart';

/// Abre el formulario de alimento a pantalla completa. Devuelve el alimento guardado.
Future<Food?> openFoodForm(BuildContext context, {Food? food, String initialName = '', String initialBarcode = '', bool autoLookup = false}) {
  return Navigator.of(context, rootNavigator: true).push<Food>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => FoodFormPage(food: food, initialName: initialName, initialBarcode: initialBarcode, autoLookup: autoLookup),
  ));
}

/// Medidas que la lista en lenguaje natural sabe interpretar. "ml" guarda la densidad.
const _measures = [
  ('unidad', '1 pieza: un huevo, una manzana…'),
  ('pequeño', '"1 tomate pequeño"'),
  ('mediano', '"1 tomate mediano"'),
  ('grande', '"1 tomate grande"'),
  ('taza', '"2 tazas de arroz"'),
  ('vaso', '"1 vaso de leche"'),
  ('cda', 'cucharada'),
  ('cdta', 'cucharadita'),
  ('rebanada', 'rebanada o lámina'),
  ('lata', '"1 lata de atún"'),
  ('scoop', 'medida de proteína en polvo'),
  ('porción', '"2 porciones"'),
  ('ml', 'solo líquidos: cuánto pesa 1 ml (agua = 1)'),
];

/// Tolerancia para avisar que las kcal no calzan con los macros.
const _kcalTolerance = 0.2;

sealed class _Lookup {
  const _Lookup();
}

class _Idle extends _Lookup {
  const _Idle();
}

class _Loading extends _Lookup {
  const _Loading();
}

class _NotFound extends _Lookup {
  const _NotFound();
}

class _Found extends _Lookup {
  const _Found(this.url);

  final String url;
}

class _Failed extends _Lookup {
  const _Failed(this.message);

  final String message;
}

class _Row {
  _Row(this.name, String grams) : grams = TextEditingController(text: grams);

  final String name;
  final TextEditingController grams;
}

bool _sameName(String a, String b) => normalize(a) == normalize(b);

class FoodFormPage extends ConsumerStatefulWidget {
  const FoodFormPage({super.key, this.food, this.initialName = '', this.initialBarcode = '', this.autoLookup = false});

  final Food? food;
  final String initialName;
  final String initialBarcode;

  /// Busca el código inicial en Open Food Facts al abrir.
  final bool autoLookup;

  @override
  ConsumerState<FoodFormPage> createState() => _FoodFormPageState();
}

class _FoodFormPageState extends ConsumerState<FoodFormPage> {
  late final _barcode = TextEditingController(text: widget.food?.barcode ?? widget.initialBarcode);
  late final _name = TextEditingController(text: widget.food?.name ?? capitalize(widget.initialName));
  late final _brand = TextEditingController(text: widget.food?.brand ?? '');
  late final _aliases = TextEditingController(text: widget.food?.aliases.join(', ') ?? '');
  late final Map<MacroKey, TextEditingController> _macros = {
    for (final k in MacroKey.values) k: TextEditingController(text: widget.food == null ? '' : plain(widget.food!.per100g[k])),
  };
  late final List<_Row> _rows = () {
    final f = widget.food;
    if (f == null) return [_Row('unidad', '')];
    return [
      for (final p in f.portions) _Row(p.name, plain(p.grams)),
      if (f.density != null) _Row('ml', plain(f.density!)),
    ];
  }();
  _Lookup _lookup = const _Idle();
  FoodSource? _offSource;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autoLookup && widget.initialBarcode.isNotEmpty) _searchOff(normalizeBarcode(widget.initialBarcode));
  }

  @override
  void dispose() {
    for (final c in [_barcode, _name, _brand, _aliases, ..._macros.values, ..._rows.map((r) => r.grams)]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(MacroKey k) => parseNum(_macros[k]!.text);

  /// Completa solo los campos vacíos, para no pisar lo que el usuario ya escribió.
  void _applyDraft(OffDraft draft) {
    if (draft.name.isNotEmpty && _name.text.trim().isEmpty) _name.text = draft.name;
    if (draft.brand != null && _brand.text.trim().isEmpty) _brand.text = draft.brand!;
    final per100g = draft.per100g;
    if (per100g != null) {
      for (final k in MacroKey.values) {
        if (_macros[k]!.text.trim().isEmpty) _macros[k]!.text = plain(per100g[k]);
      }
    }
    if (draft.servingGrams != null && !_rows.any((r) => _sameName(r.name, 'porción'))) {
      _rows.removeWhere((r) => r.name == 'unidad' && r.grams.text.trim().isEmpty);
      _rows.add(_Row('porción', plain(draft.servingGrams!)));
    }
    _offSource = FoodSource(type: FoodSourceType.off, ref: draft.barcode, license: 'ODbL');
  }

  Future<void> _searchOff(String code) async {
    setState(() => _lookup = const _Loading());
    try {
      final draft = await ref.read(lookupProvider).lookupBarcode(code);
      if (!mounted) return;
      setState(() {
        if (draft == null) {
          _lookup = const _NotFound();
        } else {
          _applyDraft(draft);
          _lookup = _Found(draft.url);
        }
      });
    } on Object catch (e) {
      if (mounted) setState(() => _lookup = _Failed(errorMessage(e)));
    }
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    setState(() => _barcode.text = code);
    // Si el formulario aún está vacío, se intenta completar con Open Food Facts.
    if (_name.text.trim().isEmpty || MacroKey.values.every((k) => _macros[k]!.text.trim().isEmpty)) {
      await _searchOff(code);
    } else {
      setState(() => _lookup = const _Idle());
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final code = normalizeBarcode(_barcode.text);
    if (_barcode.text.trim().isNotEmpty && !isValidGtin(code)) {
      setState(() => _error = 'El código de barras no es válido: revisa los dígitos.');
      return;
    }
    final p = _num(MacroKey.protein);
    final cb = _num(MacroKey.carbs);
    final f = _num(MacroKey.fat);
    final values = <MacroKey, double>{};
    for (final k in MacroKey.values) {
      var v = _num(k);
      if (k == MacroKey.kcal && v == null && p != null && cb != null && f != null) v = estimateKcal(p, cb, f).toDouble();
      if (k == MacroKey.fiber && _macros[k]!.text.trim().isEmpty) v = 0;
      if (v == null || v < 0) {
        setState(() => _error = 'Revisa el valor de ${macroMeta[k]!.label.toLowerCase()}.');
        return;
      }
      values[k] = v;
    }
    if (values[MacroKey.protein]! + values[MacroKey.carbs]! + values[MacroKey.fat]! > 100) {
      setState(() => _error = 'La suma de proteína, carbohidratos y grasa supera 100 g por 100 g.');
      return;
    }
    final ml = _rows.where((r) => r.name == 'ml').firstOrNull;
    final density = ml == null ? null : parseNum(ml.grams.text);
    final input = FoodInput(
      name: _name.text.trim(),
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      barcode: _barcode.text.trim().isEmpty ? null : code,
      aliases: _aliases.text.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty).toList(),
      per100g: Macros.generate((k) => values[k]!),
      portions: [
        for (final r in _rows)
          if (r.name != 'ml' && (parseNum(r.grams.text) ?? 0) > 0) Portion(name: r.name.trim(), grams: parseNum(r.grams.text)!),
      ],
      density: density != null && density > 0 ? density : null,
    );
    setState(() => _saving = true);
    try {
      final actions = ref.read(nutritionActionsProvider);
      final saved = widget.food != null
          ? await actions.updateFood(widget.food!, input)
          : await actions.createFood(input, source: _offSource ?? FoodSource.userSource);
      if (!mounted) return;
      showToast(context, widget.food != null ? 'Alimento actualizado' : 'Alimento creado');
      Navigator.pop(context, saved);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = errorMessage(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final foods = ref.watch(foodsProvider).value ?? const <Food>[];
    final code = normalizeBarcode(_barcode.text);
    final codeValid = isValidGtin(code);
    final duplicate = codeValid ? foods.where((x) => x.barcode == code && x.id != widget.food?.id).firstOrNull : null;
    final p = _num(MacroKey.protein);
    final cb = _num(MacroKey.carbs);
    final f = _num(MacroKey.fat);
    final canEstimate = p != null && cb != null && f != null;
    final estimated = canEstimate ? estimateKcal(p, cb, f) : null;
    final k = _num(MacroKey.kcal);
    final kcalMismatch = k != null && estimated != null && estimated > 0 && (k - estimated).abs() > (estimated * _kcalTolerance).clamp(25, double.infinity);
    final available = _measures.where((m) => !_rows.any((r) => _sameName(r.name, m.$1))).toList();
    final small = TextStyle(fontSize: 11, color: c.faint, height: 1.4);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.food != null ? 'Editar alimento' : 'Nuevo alimento'),
        actions: [
          TextButton(onPressed: _saving || _name.text.trim().isEmpty ? null : _submit, child: const Text('Guardar')),
          const SizedBox(width: 8),
        ],
      ),
      body: PageBody(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Código de barras (opcional)', style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _barcode,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _lookup = const _Idle()),
                decoration: const InputDecoration(hintText: 'Escanéalo o escríbelo'),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(tooltip: 'Escanear con la cámara', onPressed: _scan, icon: const Icon(Icons.qr_code_scanner)),
            IconButton.filledTonal(
              tooltip: 'Buscar datos en Open Food Facts',
              onPressed: codeValid && _lookup is! _Loading ? () => _searchOff(code) : null,
              icon: const Icon(Icons.travel_explore),
            ),
          ]),
          const SizedBox(height: 4),
          switch (_lookup) {
            _Loading() => Text('Buscando en Open Food Facts…', style: TextStyle(fontSize: 11, color: c.muted)),
            _Found(:final url) => Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                Icon(Icons.check_circle, size: 14, color: c.success),
                const SizedBox(width: 4),
                Text('Datos de Open Food Facts cargados. Compáralos con la etiqueta antes de guardar. ', style: TextStyle(fontSize: 11, color: c.muted)),
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  child: Text('Ver ficha', style: TextStyle(fontSize: 11, color: c.primary, decoration: TextDecoration.underline)),
                ),
              ]),
            _NotFound() => Text('No está en Open Food Facts: complétalo con la etiqueta.', style: TextStyle(fontSize: 11, color: c.muted)),
            _Failed(:final message) => Text(message, style: TextStyle(fontSize: 11, color: c.danger)),
            _Idle() => const SizedBox.shrink(),
          },
          if (duplicate != null)
            Text('Ya existe «${duplicate.name}» con este código.', style: TextStyle(fontSize: 11, color: c.warning)),
        ]),
        TextField(
          controller: _name,
          autofocus: !widget.autoLookup && widget.food == null,
          maxLength: 120,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Nombre', counterText: ''),
        ),
        Row(children: [
          Expanded(child: TextField(controller: _brand, decoration: const InputDecoration(labelText: 'Marca (opcional)'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _aliases, decoration: const InputDecoration(labelText: 'Alias, separados por coma', hintText: 'palta, aguacate'))),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Valores por 100 g', style: TextStyle(fontSize: 12, color: c.muted))),
            TextButton.icon(
              onPressed: canEstimate ? () => setState(() => _macros[MacroKey.kcal]!.text = '$estimated') : null,
              icon: const Icon(Icons.calculate_outlined, size: 18),
              label: const Text('kcal desde macros', style: TextStyle(fontSize: 12)),
            ),
          ]),
          Row(children: [
            for (final key in MacroKey.values) ...[
              if (key != MacroKey.kcal) const SizedBox(width: 6),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(key == MacroKey.kcal ? 'kcal' : '${macroMeta[key]!.short} g', style: TextStyle(fontSize: 11, color: c.macro(key))),
                  const SizedBox(height: 2),
                  NumberField(
                    controller: _macros[key],
                    textAlign: TextAlign.center,
                    dense: true,
                    hint: key == MacroKey.kcal && estimated != null ? '$estimated' : '0',
                    onChanged: (_) => setState(() {}),
                  ),
                ]),
              ),
            ],
          ]),
          if (kcalMismatch) ...[
            const SizedBox(height: 6),
            Text('Las kcal no calzan con los macros (≈ $estimated kcal según 4/4/9). Revisa la etiqueta; puede ser un error de digitación.',
                style: TextStyle(fontSize: 11, color: c.warning, height: 1.4)),
          ],
          const SizedBox(height: 6),
          Text('La fibra es opcional. Copia los carbohidratos tal como vienen en la etiqueta (según el país o la fuente, pueden incluir o no la fibra).',
              style: small),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Equivalencias en gramos (opcional)', style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 4),
          Text(
            'Sirven para que la lista entienda medidas como "Huevos x3" o "2 tazas de arroz". Toca una medida y escribe cuánto pesa. '
            'Ej.: 1 unidad = 50 g. Si no pones nada, solo se entenderán gramos ("150g").',
            style: small,
          ),
          const SizedBox(height: 8),
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(width: 110, child: Text('1 ${row.name}', style: TextStyle(fontSize: 14, color: c.fg))),
                Text('=', style: TextStyle(color: c.faint)),
                const SizedBox(width: 8),
                NumberField(controller: row.grams, width: 90, hint: row.name == 'ml' ? '1' : '0', dense: true),
                const SizedBox(width: 6),
                Text('g', style: TextStyle(fontSize: 12, color: c.faint)),
                const Spacer(),
                IconButton(
                  tooltip: 'Quitar ${row.name}',
                  onPressed: () => setState(() {
                    _rows.remove(row);
                    row.grams.dispose();
                  }),
                  icon: Icon(Icons.delete_outline, color: c.danger, size: 20),
                ),
              ]),
            ),
          if (available.isNotEmpty)
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('Agregar:', style: small),
              for (final m in available)
                Tooltip(
                  message: m.$2,
                  child: ActionChip(
                    avatar: const Icon(Icons.add, size: 14),
                    label: Text(m.$1),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _rows.add(_Row(m.$1, ''))),
                  ),
                ),
            ]),
        ]),
        if (_error != null) Text(_error!, style: TextStyle(fontSize: 12, color: c.danger)),
        FilledButton.icon(
          onPressed: _saving || _name.text.trim().isEmpty ? null : _submit,
          icon: const Icon(Icons.check),
          label: const Text('Guardar alimento'),
        ),
      ]),
    );
  }
}
