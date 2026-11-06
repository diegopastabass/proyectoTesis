import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/numbers.dart';
import '../../core/nutrition/models.dart';
import '../../ui/macros.dart';
import '../../ui/widgets.dart';
import 'food_form_page.dart';

const _maxRows = 150;

/// Catálogo público de alimentos, con búsqueda por nombre o código.
class FoodsPage extends ConsumerStatefulWidget {
  const FoodsPage({super.key});

  @override
  ConsumerState<FoodsPage> createState() => _FoodsPageState();
}

class _FoodsPageState extends ConsumerState<FoodsPage> {
  final _query = TextEditingController();
  bool _importing = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Food> _filter(NutritionData data) {
    final q = _query.text.trim();
    if (q.isEmpty) return [...data.foods]..sort((a, b) => a.name.compareTo(b.name));
    // Solo dígitos: se busca por código de barras.
    final digits = q.replaceAll(RegExp(r'\s'), '');
    if (RegExp(r'^\d{4,}$').hasMatch(digits)) return data.foods.where((f) => f.barcode?.contains(digits) ?? false).toList();
    final byId = data.ctx.foods;
    return [for (final cand in data.foodMatcher.search(q, limit: _maxRows)) ?byId[cand.id]];
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final plan = await ref.read(nutritionActionsProvider).importSeed();
      if (!mounted) return;
      final parts = [
        if (plan.missing.isNotEmpty) '${plan.missing.length} importados',
        if (plan.fiberPatches.isNotEmpty) '${plan.fiberPatches.length} con fibra completada',
      ];
      showToast(context, parts.isEmpty ? 'Catálogo base al día' : parts.join(' · '));
    } on Object catch (e) {
      if (mounted) showToast(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final data = ref.watch(nutritionDataProvider);
    final plan = ref.watch(seedPlanProvider);
    final uid = ref.watch(sessionUserProvider)?.uid;
    final pending = plan?.pending ?? 0;
    final importLabel = pending == 0
        ? 'Catálogo base al día'
        : (plan!.missing.isNotEmpty
            ? 'Importar catálogo base (${plan.missing.length} alimentos)'
            : 'Completar fibra del catálogo base (${plan.fiberPatches.length} alimentos)');

    return AsyncView(
      data,
      builder: (d) {
        final list = _filter(d);
        return PageBody(gap: 12, children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Buscar en ${d.foods.length} alimentos o por código…'),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: importLabel,
              onPressed: _importing || pending == 0 ? null : _import,
              icon: const Icon(Icons.cloud_download_outlined),
            ),
            IconButton.filled(
              tooltip: 'Nuevo alimento',
              onPressed: () => openFoodForm(context, initialName: _query.text.trim()),
              icon: const Icon(Icons.add),
            ),
          ]),
          if (d.foods.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'El catálogo está vacío',
                message: 'Importa el catálogo base con el botón de descarga o crea tu primer alimento.',
              ),
            ),
          if (list.isNotEmpty)
            CardList(children: [
              for (final f in list.take(_maxRows))
                InkWell(
                  onTap: f.createdBy == uid ? () => openFoodForm(context, food: f) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(f.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.fg))),
                            if (f.brand != null)
                              Flexible(child: Text(' · ${f.brand}', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.faint))),
                            if (f.barcode != null) ...[const SizedBox(width: 4), Icon(Icons.qr_code_2, size: 14, color: c.faint)],
                            if (f.verified) ...[const SizedBox(width: 4), Icon(Icons.verified, size: 14, color: c.primary)],
                            if (f.source.type == FoodSourceType.user) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.person_outline, size: 14, color: f.createdBy == uid ? c.primary : c.faint),
                            ],
                          ]),
                          const SizedBox(height: 2),
                          Wrap(spacing: 8, children: [
                            Text('100 g', style: TextStyle(fontSize: 11, color: c.faint)),
                            MacroInline(f.per100g, fontSize: 11),
                          ]),
                          if (f.portions.isNotEmpty)
                            Text(f.portions.map((p) => '${p.name} ${plain(p.grams)} g').join(', '),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.faint)),
                        ]),
                      ),
                      if (f.createdBy == uid) Icon(Icons.edit_outlined, size: 18, color: c.muted),
                    ]),
                  ),
                ),
            ]),
          if (_query.text.trim().isNotEmpty && list.isEmpty)
            Text('Sin resultados para "${_query.text.trim()}".', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.muted)),
        ]);
      },
    );
  }
}
