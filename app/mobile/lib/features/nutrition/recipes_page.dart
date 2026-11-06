import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/numbers.dart';
import '../../ui/macros.dart';
import '../../ui/widgets.dart';

class RecipesPage extends ConsumerWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return AsyncView(
      ref.watch(nutritionDataProvider),
      builder: (data) => PageBody(gap: 12, children: [
        SectionTitle(
          'Mis recetas',
          trailing: IconButton.filled(tooltip: 'Nueva receta', onPressed: () => context.push('/recetas/nueva'), icon: const Icon(Icons.add)),
        ),
        if (data.recipes.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Aún no tienes recetas',
              message: 'Crea una y luego escribe su nombre en la lista, por ejemplo "Pollo al limón 2 porciones".',
            ),
          )
        else
          CardList(children: [
            for (final r in data.recipes)
              ListTile(
                onTap: () => context.push('/recetas/${r.id}'),
                leading: Icon(Icons.menu_book_outlined, color: c.primary),
                title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Wrap(spacing: 8, children: [
                  Text('${plain(r.servings)} porc. · ${r.ingredients.length} ingr. · por porción', style: TextStyle(fontSize: 11, color: c.faint)),
                  MacroInline(r.perServing, fontSize: 11),
                ]),
                trailing: Icon(Icons.chevron_right, color: c.faint),
              ),
          ]),
      ]),
    );
  }
}
