import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/nutrition/matcher.dart';
import '../../core/nutrition/models.dart';
import '../../core/nutrition/resolve.dart';
import '../../ui/macros.dart';
import '../../ui/widgets.dart';

/// Resultado del buscador: un candidato elegido o la orden de crear un alimento.
sealed class PickResult {
  const PickResult();
}

class Picked extends PickResult {
  const Picked(this.candidate);

  final Candidate candidate;
}

class CreateRequested extends PickResult {
  const CreateRequested(this.name);

  final String name;
}

/// Hoja con buscador del catálogo. Si `allowCreate`, ofrece crear el alimento buscado.
Future<PickResult?> showFoodPicker(
  BuildContext context, {
  required Matcher matcher,
  required ResolveContext ctx,
  String title = 'Elegir alimento',
  String initialQuery = '',
  bool allowCreate = true,
}) {
  return showSheet<PickResult>(
    context,
    title: title,
    builder: (context) => _FoodPicker(matcher: matcher, ctx: ctx, initialQuery: initialQuery, allowCreate: allowCreate),
  );
}

class _FoodPicker extends StatefulWidget {
  const _FoodPicker({required this.matcher, required this.ctx, required this.initialQuery, required this.allowCreate});

  final Matcher matcher;
  final ResolveContext ctx;
  final String initialQuery;
  final bool allowCreate;

  @override
  State<_FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends State<_FoodPicker> {
  late final _query = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _query.text.trim();
    final results = q.isEmpty ? const <Candidate>[] : widget.matcher.search(q, limit: 12);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          controller: _query,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar en el catálogo…'),
        ),
      ),
      Expanded(
        child: ListView(children: [
          for (final cand in results)
            () {
              final food = cand.kind == EntryKind.food ? widget.ctx.foods[cand.id] : null;
              final recipe = cand.kind == EntryKind.recipe ? widget.ctx.recipes[cand.id] : null;
              return ListTile(
                onTap: () => Navigator.pop(context, Picked(cand)),
                leading: cand.kind == EntryKind.recipe ? Icon(Icons.menu_book_outlined, color: c.primary) : null,
                title: Text(cand.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: food != null
                    ? MacroInline(food.per100g, fontSize: 11)
                    : (recipe != null ? MacroInline(recipe.perServing, fontSize: 11) : null),
                trailing: Text('${food != null ? '/100 g' : 'porción'} · ${(cand.confidence * 100).round()}%',
                    style: TextStyle(fontSize: 10, color: c.faint)),
              );
            }(),
          if (q.isNotEmpty && results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Sin coincidencias en el catálogo.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.muted)),
            ),
        ]),
      ),
      if (widget.allowCreate && q.isNotEmpty)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, CreateRequested(q)),
              icon: const Icon(Icons.add),
              label: Text('Crear "$q"', overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
    ]);
  }
}
