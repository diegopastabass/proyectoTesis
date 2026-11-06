import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/sim_providers.dart';
import '../../app/theme.dart';
import '../../data/simulated/sim_data.dart';
import '../../ui/sim_widgets.dart';
import '../../ui/widgets.dart';

IconData postKindIcon(SimPostKind k) => switch (k) {
      SimPostKind.workout => Icons.fitness_center,
      SimPostKind.route => Icons.route_outlined,
      SimPostKind.meal => Icons.restaurant,
      SimPostKind.recipe => Icons.menu_book_outlined,
    };

/// Busca una publicación entre las de ejemplo y las que publicó el usuario.
SimPost? findPost(WidgetRef ref, String id) =>
    [...ref.watch(simProvider).published, ...simPosts].where((p) => p.id == id).firstOrNull;

class KindChip extends StatelessWidget {
  const KindChip(this.kind, {super.key});

  final SimPostKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(color: c.primarySoft, shape: const StadiumBorder()),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(postKindIcon(kind), size: 12, color: c.primary),
        const SizedBox(width: 4),
        Text(kind.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.primary)),
      ]),
    );
  }
}

/// Fotos o ruta de una publicación.
class PostMedia extends StatelessWidget {
  const PostMedia(this.post, {super.key, this.height = 170});

  final SimPost post;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (post.routeSeed != null) return SimRoutePreview(seed: post.routeSeed!, height: height);
    if (post.photos == 0) return const SizedBox.shrink();
    final icon = postKindIcon(post.kind);
    if (post.photos == 1) return SimPhoto(icon: icon, tone: post.id.hashCode, height: height);
    return Row(children: [
      for (var i = 0; i < post.photos; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(child: SimPhoto(icon: i == 0 ? icon : Icons.photo_outlined, tone: i, height: height)),
      ],
    ]);
  }
}

/// Encabezado de una publicación: autor, tiempo y tipo.
class PostAuthorRow extends StatelessWidget {
  const PostAuthorRow(this.post, {super.key, this.me = false});

  final SimPost post;
  final bool me;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final author = me ? null : simUser(post.authorId);
    return Row(children: [
      if (author != null)
        GestureDetector(onTap: () => context.push('/comunidad/usuario/${author.id}'), child: SimAvatar(author))
      else
        CircleAvatar(radius: 20, backgroundColor: c.primarySoft, child: Icon(Icons.person, color: c.primary)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(author?.name ?? 'Tú', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
          Text(post.when, style: TextStyle(fontSize: 12, color: c.muted)),
        ]),
      ),
      KindChip(post.kind),
    ]);
  }
}

/// Publicación en el muro.
class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, this.me = false});

  final SimPost post;
  final bool me;

  void _add(BuildContext context) => context.push(post.kind == SimPostKind.recipe || post.kind == SimPostKind.meal ? '/comunidad/post/${post.id}/receta' : '/comunidad/post/${post.id}/agregar');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final added = ref.watch(simProvider).added.contains(post.id);
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: me ? null : () => context.push('/comunidad/post/${post.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PostAuthorRow(post, me: me),
        const SizedBox(height: 10),
        Text(post.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.fgStrong)),
        const SizedBox(height: 4),
        Text(post.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, height: 1.35, color: c.fg)),
        if (post.photos > 0 || post.routeSeed != null) ...[const SizedBox(height: 10), PostMedia(post, height: 150)],
        if (post.stats.isNotEmpty) ...[const SizedBox(height: 10), StatRow(post.stats)],
        if (!me) ...[
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  onPressed: added ? null : () => _add(context),
                  icon: Icon(added ? Icons.check : Icons.add_circle_outline, size: 18),
                  label: Text(added ? 'Agregada' : post.kind.addLabel),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Reportar',
              visualDensity: VisualDensity.compact,
              onPressed: () => context.push('/comunidad/post/${post.id}/reportar'),
              icon: Icon(Icons.flag_outlined, size: 20, color: c.muted),
            ),
          ]),
        ],
      ]),
    );
  }
}

/// Botón Seguir / Siguiendo.
class FollowButton extends ConsumerWidget {
  const FollowButton(this.userId, {super.key, this.expanded = false});

  final String userId;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(simProvider).followed.contains(userId);
    void toggle() => ref.read(simProvider.notifier).toggleFollow(userId);
    final size = expanded ? null : const Size(92, 36);
    return following
        ? OutlinedButton(onPressed: toggle, style: OutlinedButton.styleFrom(minimumSize: size, textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), child: const Text('Siguiendo'))
        : FilledButton(onPressed: toggle, style: FilledButton.styleFrom(minimumSize: size, textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), child: const Text('Seguir'));
  }
}
