import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/sim_providers.dart';
import '../../app/theme.dart';
import '../../data/simulated/sim_data.dart';
import '../../ui/sim_widgets.dart';
import '../../ui/widgets.dart';
import 'community_widgets.dart';

/// CU-23: publicaciones recientes de las personas que el usuario sigue.
class WallPage extends ConsumerWidget {
  const WallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sim = ref.watch(simProvider);
    final posts = simPosts.where((p) => sim.followed.contains(p.authorId) && !sim.reported.contains(p.id)).toList();
    return PageBody(children: [
      Row(children: [
        const Expanded(child: SectionTitle('Tu muro')),
        FilledButton.icon(
          onPressed: () => context.push('/comunidad/publicar'),
          style: FilledButton.styleFrom(minimumSize: const Size(64, 38), textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Publicar'),
        ),
      ]),
      for (final p in sim.published) PostCard(post: p, me: true),
      if (posts.isEmpty && sim.published.isEmpty)
        AppCard(
          child: Column(children: [
            const EmptyState(icon: Icons.groups_outlined, title: 'Tu muro está vacío', message: 'Sigue a otras personas para ver sus sesiones, rutas y comidas.'),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: FilledButton(onPressed: () => context.go('/comunidad/buscar'), child: const Text('Buscar personas')),
            ),
          ]),
        ),
      for (final p in posts) PostCard(post: p),
    ]);
  }
}

/// CU-14: buscador de personas.
class SearchPeoplePage extends ConsumerStatefulWidget {
  const SearchPeoplePage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<SearchPeoplePage> createState() => _SearchPeoplePageState();
}

class _SearchPeoplePageState extends ConsumerState<SearchPeoplePage> {
  late final _q = TextEditingController(text: widget.initialQuery ?? '');

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final query = _q.text.trim().toLowerCase();
    final found = simUsers.where((u) => query.isEmpty || u.name.toLowerCase().contains(query) || u.handle.contains(query) || u.sport.toLowerCase().contains(query)).toList();
    return PageBody(children: [
      TextField(
        controller: _q,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: 'Buscar por nombre o deporte', prefixIcon: Icon(Icons.search)),
      ),
      if (found.isEmpty)
        AppCard(child: EmptyState(icon: Icons.person_search_outlined, title: 'No encontramos a nadie', message: 'Prueba con otro nombre o con un deporte, por ejemplo "$_exampleSport".'))
      else
        CardList(
          header: CardHeader(query.isEmpty ? 'Personas sugeridas' : 'Resultados'),
          children: [
            for (final u in found)
              ListTile(
                onTap: () => context.push('/comunidad/usuario/${u.id}'),
                leading: SimAvatar(u),
                title: Text(u.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
                subtitle: Text('${u.sport} · ${u.followers} seguidores', style: TextStyle(fontSize: 12, color: c.muted)),
                trailing: FollowButton(u.id),
              ),
          ],
        ),
    ]);
  }
}

const _exampleSport = 'ciclismo';

/// CU-14: perfil de otra persona.
class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final u = simUser(id);
    final following = ref.watch(simProvider).followed.contains(id);
    final posts = simPosts.where((p) => p.authorId == id).toList();
    return Scaffold(
      appBar: AppBar(title: Text(u.handle)),
      body: PageBody(children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            SimAvatar(u, radius: 38),
            const SizedBox(height: 10),
            Text(u.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: c.fgStrong)),
            Text(u.sport, style: TextStyle(fontSize: 13, color: c.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(u.bio, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.35, color: c.fg)),
            const SizedBox(height: 14),
            Row(children: [
              _Count('${posts.length}', 'Publicaciones'),
              _Count('${u.followers + (following ? 1 : 0)}', 'Seguidores'),
              _Count('${u.following}', 'Siguiendo'),
            ]),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FollowButton(id, expanded: true)),
          ]),
        ),
        if (following)
          for (final p in posts) PostCard(post: p)
        else
          const InfoNote(icon: Icons.lock_outline, text: 'Sigue a esta persona para ver sus publicaciones en tu muro.'),
      ]),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.fgStrong, fontFeatures: tabular)),
        Text(label, style: TextStyle(fontSize: 11, color: c.muted)),
      ]),
    );
  }
}

/// Perfil propio dentro de la comunidad.
class MyCommunityProfilePage extends ConsumerWidget {
  const MyCommunityProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final sim = ref.watch(simProvider);
    return PageBody(children: [
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          CircleAvatar(radius: 34, backgroundColor: c.primarySoft, child: Icon(Icons.person, size: 34, color: c.primary)),
          const SizedBox(height: 10),
          Text('Usuario de prueba', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.fgStrong)),
          const SizedBox(height: 14),
          Row(children: [
            _Count('${sim.published.length}', 'Publicaciones'),
            const _Count('12', 'Seguidores'),
            _Count('${sim.followed.length}', 'Siguiendo'),
          ]),
        ]),
      ),
      if (sim.published.isEmpty)
        const AppCard(child: EmptyState(icon: Icons.post_add, title: 'Aún no has publicado', message: 'Comparte una sesión, una ruta o una comida desde el muro.'))
      else
        for (final p in sim.published) PostCard(post: p, me: true),
    ]);
  }
}
