import 'package:flutter/material.dart';

enum ModuleId { nutricion, fuerza, cardio, comunidad }

class Section {
  const Section(this.path, this.icon, this.label, {this.exact = false});

  final String path;
  final IconData icon;
  final String label;

  /// Solo se marca activa con la ruta exacta (las demás también con sus subrutas).
  final bool exact;

  bool matches(String location) => exact ? location == path : location == path || location.startsWith('$path/');
}

class AppModule {
  const AppModule({required this.id, required this.label, required this.icon, required this.path, required this.ready, required this.summary, this.sections = const [], this.previewOnly = false});

  final ModuleId id;
  final String label;
  final IconData icon;

  /// Ruta de entrada del módulo.
  final String path;

  /// false mientras el módulo se muestra como "En desarrollo".
  final bool ready;

  /// Solo se muestra en modo demostración (pantallas de diseño con datos simulados).
  final bool previewOnly;

  /// Qué hace (o hará) el módulo.
  final String summary;

  /// Secciones de la barra inferior.
  final List<Section> sections;
}

const modules = [
  AppModule(
    id: ModuleId.nutricion,
    label: 'Nutrición',
    icon: Icons.restaurant,
    path: '/',
    ready: true,
    summary: 'Registro de comidas, macros, recetas y progreso corporal.',
    sections: [
      Section('/', Icons.calendar_month, 'Diario', exact: true),
      Section('/registrar', Icons.playlist_add, 'Registrar'),
      Section('/alimentos', Icons.local_grocery_store_outlined, 'Alimentos'),
      Section('/recetas', Icons.menu_book_outlined, 'Recetas'),
      Section('/progreso', Icons.show_chart, 'Progreso'),
      Section('/objetivos', Icons.track_changes, 'Objetivos'),
    ],
  ),
  AppModule(
    id: ModuleId.fuerza,
    label: 'Fuerza',
    icon: Icons.fitness_center,
    path: '/fuerza',
    ready: true,
    summary: 'Registro de rutinas, ejercicios, series, repeticiones y carga.',
    sections: [
      Section('/fuerza', Icons.fitness_center, 'Entrenar', exact: true),
      Section('/fuerza/historial', Icons.history, 'Historial'),
      Section('/fuerza/progreso', Icons.show_chart, 'Progreso'),
      Section('/fuerza/ejercicios', Icons.library_books_outlined, 'Ejercicios'),
    ],
  ),
  AppModule(
    id: ModuleId.cardio,
    label: 'Cardio',
    icon: Icons.monitor_heart_outlined,
    path: '/cardio',
    ready: true,
    summary: 'Rutas de running, ciclismo y trekking con el GPS del teléfono: distancia, ritmo, velocidad y desnivel.',
    sections: [
      Section('/cardio', Icons.radio_button_checked, 'Grabar', exact: true),
      Section('/cardio/historial', Icons.history, 'Historial'),
    ],
  ),
  AppModule(
    id: ModuleId.comunidad,
    label: 'Comunidad',
    icon: Icons.groups_outlined,
    path: '/comunidad',
    ready: true,
    previewOnly: true,
    summary: 'Muro, publicaciones y personas que sigues.',
    sections: [
      Section('/comunidad', Icons.dynamic_feed_outlined, 'Muro', exact: true),
      Section('/comunidad/buscar', Icons.search, 'Buscar'),
      Section('/comunidad/perfil', Icons.person_outline, 'Mi perfil'),
    ],
  ),
];

AppModule moduleById(ModuleId id) => modules.firstWhere((m) => m.id == id);

/// Las rutas de nutrición viven en la raíz; los demás módulos, bajo su propio prefijo.
AppModule moduleForPath(String location) =>
    modules.where((m) => m.path != '/' && (location == m.path || location.startsWith('${m.path}/'))).firstOrNull ?? modules.first;
