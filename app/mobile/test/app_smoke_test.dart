// Prueba de humo: arranca la app completa con el backend en memoria y recorre
// todas las pantallas. Falla si alguna lanza una excepción o se desborda
// (overflow) en un ancho de iPhone.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:asistente_deportivo/app/app.dart';
import 'package:asistente_deportivo/app/providers.dart';
import 'package:asistente_deportivo/app/router.dart';
import 'package:asistente_deportivo/core/body/energy.dart';
import 'package:asistente_deportivo/core/common/date.dart';
import 'package:asistente_deportivo/core/nutrition/models.dart';
import 'package:asistente_deportivo/core/nutrition/score.dart';
import 'package:asistente_deportivo/core/nutrition/seed.dart';
import 'package:asistente_deportivo/core/strength/models.dart';
import 'package:asistente_deportivo/app/cardio_providers.dart';
import 'package:asistente_deportivo/core/activity/models.dart';
import 'package:asistente_deportivo/core/activity/reminders.dart';
import 'package:asistente_deportivo/core/cardio/activity.dart';
import 'package:asistente_deportivo/platform/location/location_service.dart';
import 'package:asistente_deportivo/data/local/local_store.dart';
import 'package:asistente_deportivo/platform/capability.dart';
import 'package:asistente_deportivo/platform/notifications/notification_service.dart';
import 'package:asistente_deportivo/platform/platform_providers.dart';
import 'package:asistente_deportivo/ui/format.dart';
import 'package:asistente_deportivo/data/memory/memory_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Registra lo que se programaría y permite simular el toque de un aviso.
class _FakeNotifications implements NotificationService {
  List<PlannedReminder> scheduled = const [];
  final _taps = StreamController<String>.broadcast();

  void tap(String route) => _taps.add(route);

  @override
  Future<CapabilityStatus> status() async => CapabilityStatus.granted;

  @override
  Future<CapabilityStatus> requestPermission() async => CapabilityStatus.granted;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async => scheduled = reminders;

  @override
  Future<void> scheduleRestEnd(DateTime? at) async {}

  @override
  Future<String?> launchRoute() async => null;

  @override
  Stream<String> get taps => _taps.stream;
}

/// GPS simulado: las pruebas empujan los puntos.
class _FakeLocation implements LocationService {
  final _points = StreamController<GeoPoint>.broadcast();

  /// `background` de cada vez que se pidió el GPS.
  final background = <bool>[];

  void emit(GeoPoint p) => _points.add(p);

  bool get listening => _points.hasListener;

  @override
  Future<CapabilityStatus> status() async => CapabilityStatus.granted;

  @override
  Future<CapabilityStatus> requestAccess({bool background = false}) async => CapabilityStatus.granted;

  @override
  Future<GeoPoint?> current() async => null;

  @override
  Stream<GeoPoint> track({double distanceFilterMeters = 5, bool background = false}) {
    this.background.add(background);
    return _points.stream;
  }
}

Future<ProviderContainer> _boot(
  WidgetTester tester, {
  bool signedIn = true,
  bool withSampleData = true,
  NotificationService? notifications,
  LocationService? location,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final seed = seedFoodsFromJson(jsonDecode(File('assets/data/foods.seed.json').readAsStringSync()) as Map<String, dynamic>, demoUser.uid);
  final container = ProviderContainer(overrides: [
    backendProvider.overrideWithValue(memoryBackend(seedFoods: seed, lookup: OfflineLookupRepository(), signedIn: signedIn, withSampleData: withSampleData)),
    localStoreProvider.overrideWithValue(LocalStore(prefs)),
    if (notifications != null) notificationServiceProvider.overrideWithValue(notifications),
    if (location != null) locationServiceProvider.overrideWithValue(location),
    // Sin teselas del mapa: las pruebas no usan la red.
    mapTilesProvider.overrideWithValue(false),
  ]);
  addTearDown(container.dispose);
  // iPhone 15/16 (390 × 844 pt).
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // El catálogo de ejercicios se lee de los assets (E/S real, fuera del reloj simulado).
  await tester.runAsync(() => container.read(exerciseCatalogProvider.future));
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const AsistenteApp()));
  await _settle(tester);
  return container;
}

/// Avanza el reloj sin esperar a que terminen los cronómetros (que nunca terminan).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  // Al centro de la pantalla: arriba y abajo hay barras translúcidas con el contenido por debajo.
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _go(WidgetTester tester, ProviderContainer container, String location) async {
  container.read(routerProvider).go(location);
  await _settle(tester);
}

void main() {
  testWidgets('sin sesión muestra el ingreso y entra en modo demostración', (tester) async {
    await _boot(tester, signedIn: false);
    expect(find.text('Entrar en modo demostración'), findsOneWidget);
    await _tap(tester, find.text('Entrar en modo demostración'));
    expect(find.text('PUNTAJE'), findsOneWidget);
  });

  testWidgets('registra la lista de ejemplo y la ve en el diario', (tester) async {
    final container = await _boot(tester);
    expect(find.text('Sin registros este día'), findsOneWidget);

    await _go(tester, container, '/registrar');
    await _tap(tester, find.text('Analizar'));
    expect(find.text('Arroz blanco cocido'), findsOneWidget);
    expect(find.textContaining('4 ok · 0 revisar · 0 faltan'), findsOneWidget);

    await _tap(tester, find.text('Guardar'));
    expect(find.text('PUNTAJE'), findsOneWidget);
    expect(find.text('Arroz blanco cocido'), findsOneWidget);
    expect(find.text('Sin registros este día'), findsNothing);
  });

  testWidgets('recorre nutrición, fuerza, cardio y ajustes', (tester) async {
    final container = await _boot(tester);
    final screens = {
      '/alimentos': 'Arroz blanco cocido',
      '/recetas': 'Aún no tienes recetas',
      '/recetas/nueva': 'Nueva receta',
      '/progreso': 'Registrar peso',
      '/objetivos': 'Objetivos diarios',
      '/fuerza': 'Rutina de pecho',
      '/fuerza/rutinas/demo-pecho': 'Editar rutina',
      '/fuerza/historial': 'Historial',
      '/fuerza/historial/demo-w2': 'Tus avances',
      '/fuerza/progreso': 'Constancia',
      '/fuerza/ejercicios': 'Ejercicios',
      '/fuerza/ejercicios/Barbell_Bench_Press_-_Medium_Grip': 'Press de banca con barra',
      '/cardio': 'INICIAR',
      '/cardio/historial': 'Carrera de la mañana',
      '/cardio/historial/demo-running-1': 'Parciales por kilómetro',
      '/cardio/historial/demo-trekking-6/exportar': 'Imagen para historias',
      '/ajustes': 'Integraciones del sistema',
      '/actividad': '12 días seguidos',
      '/perfil': 'Gasto calórico estimado',
      '/notificaciones': 'Racha en riesgo',
      '/fuerza/programas': 'Sugeridos para ti',
    };
    for (final MapEntry(key: location, value: text) in screens.entries) {
      await _go(tester, container, location);
      expect(find.textContaining(text), findsWidgets, reason: location);
    }
  });

  testWidgets('recorre las pantallas de diseño con datos simulados', (tester) async {
    final container = await _boot(tester);
    final screens = {
      '/comunidad': 'Tu muro',
      '/comunidad/buscar': 'Personas sugeridas',
      '/comunidad/buscar?q=xyz': 'No encontramos a nadie',
      '/comunidad/perfil': 'Aún no has publicado',
      '/comunidad/usuario/camila': 'Triatleta',
      '/comunidad/post/p1': 'Ejercicios',
      '/comunidad/post/p2': 'Ingredientes',
      '/comunidad/post/p3': 'Inicio y final ocultos',
      '/comunidad/post/p1/agregar': 'Creada por',
      '/comunidad/post/p1/agregar?estado=listo': 'Quedó agregada',
      '/comunidad/post/p3/agregar': 'Agregar a mi cardio',
      '/comunidad/post/p2/receta': 'Ingredientes ajustados',
      '/comunidad/post/p2/receta?estado=metas': 'Ya cumpliste tus metas',
      '/comunidad/post/p1/reportar': '¿Cuál es el motivo?',
      '/comunidad/post/p1/reportar?estado=listo': 'Gracias por avisar',
      '/comunidad/publicar?ejemplo=1': 'Son mías o tengo permiso',
      '/comunidad/publicar?ejemplo=1&tipo=ruta': 'Ocultamos el inicio',
      '/ia/fuerza': 'Ordenar con el asistente',
      '/ia/fuerza?estado=analizando': 'El asistente está ordenando',
      '/ia/fuerza?estado=revision': 'Falta confirmar un ejercicio',
      '/ia/comida': 'Estimar con el asistente',
      '/ia/comida?estado=revision': 'Alimentos detectados',
      '/ia/foto': 'Encuadra tu plato',
      '/ia/foto?estado=analizando': 'mirando tu plato',
      '/ia/foto?estado=revision': 'Revisa lo marcado',
      '/carga': 'Carga de esta semana',
      '/carga?estado=faltan': 'Faltan datos',
      '/carga/alerta': 'Bajar 10 %',
      '/metas': 'Cuándo te conviene comer',
      '/metas?dia=descanso': 'día de descanso',
      '/cardio/manual?ejemplo=1': 'Datos de la sesión',
      '/cardio/reloj': 'Conectar con Salud',
      '/cardio/reloj?estado=conectado': 'Sesiones nuevas',
      '/cardio/archivo': 'Elige tu archivo',
      '/cardio/archivo?estado=error': 'No pudimos usar este archivo',
      '/cardio/archivo?estado=resumen': 'Potencia',
      '/bienvenida/terminos': 'Antes de empezar',
      '/bienvenida/terminos?estado=cambios': 'Actualizamos los términos',
      '/bienvenida/terminos?estado=rechazo': 'Son necesarios',
      '/bienvenida/cuestionario?ejemplo=1': 'objetivo principal',
      '/bienvenida/cuestionario?paso=1&ejemplo=1': 'equipamiento',
      '/bienvenida/cuestionario?paso=2&ejemplo=1': 'Estatura',
      '/bienvenida/cuestionario?estado=falta': 'Responde todas',
      '/bienvenida/plan': 'Aceptar el plan',
      '/bienvenida/plan?estado=listo': 'Es tu plan de esta semana',
      '/ajustes/datos': 'Datos de salud',
      '/ajustes/datos/eliminar?ejemplo=1': 'Esta acción no se puede deshacer',
      '/premium': 'IVA incluido',
      '/premium?estado=activo': 'Ya tienes el plan premium',
      '/premium?estado=rechazado': 'No se pudo completar el pago',
      '/premium/suscripcion': 'Próximo cobro',
      '/premium/suscripcion?estado=cancelada': 'Premium hasta',
    };
    for (final MapEntry(key: location, value: text) in screens.entries) {
      // Otra pantalla entre medio: cambiar solo la consulta reutilizaría el estado de la anterior.
      await _go(tester, container, '/ajustes');
      await _go(tester, container, location);
      expect(find.textContaining(text), findsWidgets, reason: location);
    }
  });

  testWidgets('repite el desayuno de ayer con un toque', (tester) async {
    final container = await _boot(tester);
    expect(find.text('Repetir de ayer'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Copiar desayuno'));
    expect(find.text('Avena en hojuelas'), findsOneWidget);
    expect(find.bySemanticsLabel('Copiar desayuno'), findsNothing);
    final today = await tester.runAsync(() => container.read(dayEntriesProvider(todayKey()).future));
    expect(today!.map((e) => e.name), ['Avena en hojuelas', 'Leche semidescremada']);
  });

  testWidgets('el calendario abre el detalle de un día', (tester) async {
    final container = await _boot(tester);
    await _go(tester, container, '/actividad');
    final yesterday = addDays(todayKey(), -1);
    await _tap(tester, find.bySemanticsLabel(RegExp('^${longDate(yesterday)}, con registro')));
    expect(find.text('4 registros'), findsOneWidget);
  });

  testWidgets('el perfil calcula el gasto y aplica los objetivos sugeridos', (tester) async {
    final container = await _boot(tester);
    await container
        .read(backendProvider)
        .profile
        .saveBodyProfile(demoUser.uid, const BodyProfile(heightCm: 178, birthDate: '1990-01-01', sex: Sex.male, activity: ActivityLevel.high));
    await _go(tester, container, '/perfil');
    expect(find.textContaining('Reposo'), findsOneWidget);
    await _tap(tester, find.text('Aplicar a mis objetivos'));
    await _tap(tester, find.text('Aplicar'));
    expect(find.text('Objetivos diarios'), findsOneWidget);
    final goals = container.read(goalsProvider).value!;
    expect(goals.range(MacroKey.kcal), isNot(defaultGoals.range(MacroKey.kcal)));
  });

  testWidgets('la racha suma el día al registrar y celebra el hito', (tester) async {
    final container = await _boot(tester, withSampleData: false);
    // Cuatro días seguidos de entrenamiento antes de hoy.
    final strength = container.read(backendProvider).strength;
    for (var i = 4; i >= 1; i--) {
      final start = fromDateKey(addDays(todayKey(), -i)).add(const Duration(hours: 8)).millisecondsSinceEpoch;
      await strength.saveWorkout(demoUser.uid, NewWorkout(routineId: null, name: 'Libre', date: addDays(todayKey(), -i), startedAt: start, finishedAt: start + 3600000, exercises: const []));
    }
    await _settle(tester);
    expect(find.bySemanticsLabel(RegExp(r'^Racha: 4 días')), findsOneWidget);

    await _go(tester, container, '/registrar');
    await _tap(tester, find.text('Analizar'));
    await _tap(tester, find.text('Guardar'));
    expect(find.text('¡5 días seguidos!'), findsOneWidget);
    await _tap(tester, find.text('¡Vamos!'));
    expect(find.text('¡5 días seguidos!'), findsNothing);
    expect(find.bySemanticsLabel('Racha: 5 días'), findsOneWidget);
  });

  testWidgets('elige un programa sugerido y la pantalla de fuerza dice qué rutina toca', (tester) async {
    final container = await _boot(tester);
    await _go(tester, container, '/fuerza/programas');
    expect(find.text('MEJOR OPCIÓN'), findsOneWidget);
    await _tap(tester, find.text('Usar este programa').first);
    await _tap(tester, find.text('Usar programa'));
    expect(find.text('Tu programa'), findsOneWidget);
    expect(find.text('Cuerpo completo · 3 días'), findsOneWidget);
    expect(find.text('Toca: Cuerpo completo A'), findsOneWidget);
    final plan = container.read(trainingPlanProvider).value!;
    expect((plan.programId, plan.routineIds.length, (plan.weekdays.toList()..sort()).join(',')), ('cuerpo-completo-3', 2, '1,3,5'));

    // La rutina creada lleva el rango de repeticiones.
    await _tap(tester, find.text('Toca: Cuerpo completo A'));
    expect(find.textContaining('Objetivo: 6–8 reps'), findsOneWidget);
  });

  testWidgets('programa los recordatorios y abre la pantalla del aviso tocado', (tester) async {
    final fake = _FakeNotifications();
    final container = await _boot(tester, notifications: fake);
    expect(fake.scheduled, isEmpty);
    container.read(reminderSettingsProvider.notifier).set(ReminderSettings.suggested);
    await _settle(tester);
    expect(fake.scheduled.where((r) => r.kind == ReminderKind.meal), isNotEmpty);
    expect(fake.scheduled.where((r) => r.kind == ReminderKind.streak), isNotEmpty);

    fake.tap('/fuerza');
    await _settle(tester);
    expect(container.read(routerProvider).state.uri.path, '/fuerza');

    // Desactivar todo cancela los avisos.
    container.read(reminderSettingsProvider.notifier).set(const ReminderSettings());
    await _settle(tester);
    expect(fake.scheduled, isEmpty);
  });

  testWidgets('graba una ruta con el GPS, cambia de disciplina, la guarda y se respalda', (tester) async {
    final gps = _FakeLocation();
    final container = await _boot(tester, location: gps, withSampleData: false);
    await _go(tester, container, '/cardio');
    await _tap(tester, find.bySemanticsLabel(RegExp('^Iniciar')));
    expect(find.text('TIEMPO'), findsOneWidget);

    // 600 m hacia el norte a 3 m/s, un punto por segundo.
    final start = DateTime.now();
    for (var s = 0; s <= 200; s++) {
      gps.emit(GeoPoint(latitude: -33.45 + s * 3 / 111195, longitude: -70.66, at: start.add(Duration(seconds: s)), altitude: 550, accuracy: 5, speed: 3));
    }
    await _settle(tester);
    expect(find.text('0,6 km'), findsOneWidget);

    // Cambiar a ciclismo en plena grabación muestra la velocidad.
    await _tap(tester, find.bySemanticsLabel('Ciclismo'));
    expect(find.text('Vel. media'), findsOneWidget);

    await _tap(tester, find.bySemanticsLabel('Pausar'));
    expect(find.text('EN PAUSA'), findsOneWidget);
    await _tap(tester, find.text('Terminar'));
    expect(find.text('Guardar actividad'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'Vuelta al parque');
    // Con el campo enfocado, la lista vuelve a mostrarlo; se cierra el teclado antes de tocar Guardar.
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle(tester);
    await _tap(tester, find.bySemanticsLabel(RegExp('^Esfuerzo 6')));
    expect(find.text('6 · Duro'), findsOneWidget);
    await _tap(tester, find.text('Guardar'));

    expect(find.text('Vuelta al parque'), findsWidgets);
    expect(find.text('Velocidad media'), findsOneWidget);
    final saved = container.read(cardioActivitiesProvider).value!.single;
    expect((saved.discipline, saved.stats.distanceM.round(), saved.syncState, saved.rpe), (Discipline.cycling, 600, SyncState.synced, 6));
    expect(find.text('6/10'), findsOneWidget);
    expect(await container.read(backendProvider).cardio.index(demoUser.uid), contains(saved.id));
    expect(container.read(recordingProvider), isNull);
    expect(container.read(streakProvider).value!.activeToday, isTrue);
  });

  testWidgets('el GPS de la pantalla de inicio se apaga al salir de la app y vuelve al regresar', (tester) async {
    final gps = _FakeLocation();
    final container = await _boot(tester, location: gps, withSampleData: false);
    await _go(tester, container, '/cardio');
    expect(gps.listening, isTrue);
    expect(gps.background, [false]);

    Future<void> lifecycle(List<AppLifecycleState> states) async {
      for (final s in states) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await _settle(tester);
    }

    await lifecycle([AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]);
    expect(gps.listening, isFalse);
    await lifecycle([AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]);
    expect(gps.listening, isTrue);

    // Solo la grabación sigue con la app en segundo plano.
    await _tap(tester, find.bySemanticsLabel(RegExp('^Iniciar')));
    expect(gps.background.last, isTrue);
    await tester.runAsync(() => container.read(recordingProvider.notifier).discard());
  });

  testWidgets('baja las actividades respaldadas y la grabación sobrevive a reiniciar', (tester) async {
    final container = await _boot(tester);
    // El teléfono empieza vacío: las rutas de ejemplo llegan desde la "nube".
    await tester.runAsync(() => container.read(cardioActivitiesProvider.notifier).sync());
    await _settle(tester);
    final list = container.read(cardioActivitiesProvider).value!;
    expect(list.map((a) => a.discipline), [Discipline.running, Discipline.cycling, Discipline.trekking]);
    expect(list.every((a) => a.syncState == SyncState.synced), isTrue);

    // Una grabación escrita en el teléfono se recupera al abrir la app.
    final store = container.read(cardioStoreProvider)!;
    final r = Recording(id: 'en-curso', discipline: Discipline.trekking, startedAt: DateTime.now().millisecondsSinceEpoch - 60000)..pause(DateTime.now().millisecondsSinceEpoch);
    await store.writeRecording(r);
    container.invalidate(recordingProvider);
    container.read(recordingProvider);
    await _settle(tester);
    expect(container.read(recordingProvider)?.recording.id, 'en-curso');
    await _go(tester, container, '/cardio');
    expect(find.text('Actividad sin guardar'), findsOneWidget);
  });

  testWidgets('hace un entrenamiento desde la rutina y lo guarda', (tester) async {
    final container = await _boot(tester);
    await _go(tester, container, '/fuerza');
    await _tap(tester, find.byTooltip('Empezar Rutina de pecho'));
    expect(find.text('Terminar'), findsOneWidget);

    // Marca la primera serie: toma los valores de la sesión anterior.
    await _tap(tester, find.bySemanticsLabel('Marcar serie C como hecha').first);
    expect(find.text('1 serie'), findsOneWidget);

    await _tap(tester, find.text('Terminar'));
    await _tap(tester, find.text('Terminar').last); // confirma las series sin marcar
    expect(find.text('¿Qué tan duro fue el entrenamiento?'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel(RegExp('^Esfuerzo 7')));
    expect(find.text('¡Entrenamiento terminado!'), findsOneWidget);
    expect(container.read(activeWorkoutProvider), isNull);
    final saved = container.read(workoutsProvider).value!.first;
    expect(saved.rpe, 7);
    expect(find.text('7/10'), findsOneWidget);

    // El esfuerzo se puede cambiar después desde el detalle.
    await _tap(tester, find.text('7/10'));
    await _tap(tester, find.bySemanticsLabel(RegExp('^Esfuerzo 5')));
    expect(container.read(workoutsProvider).value!.first.rpe, 5);
    expect(find.text('5/10'), findsOneWidget);
  });

  testWidgets('al marcar una serie empieza el descanso y se agregan drop sets desde las opciones', (tester) async {
    final container = await _boot(tester);
    await _go(tester, container, '/fuerza');
    await _tap(tester, find.byTooltip('Empezar Rutina de pecho'));

    await _tap(tester, find.bySemanticsLabel('Marcar serie C como hecha').first);
    final rest = container.read(activeWorkoutProvider)!.rest!;
    expect(rest.seconds, defaultRestSec);
    expect(find.text('Saltar'), findsOneWidget);
    await _tap(tester, find.text('+15'));
    expect(container.read(activeWorkoutProvider)!.rest!.endsAt, rest.endsAt + 15000);
    await _tap(tester, find.text('Saltar'));
    expect(container.read(activeWorkoutProvider)!.rest, isNull);
    expect(find.text('Saltar'), findsNothing);

    // Drop set a la serie 1 del primer ejercicio: queda justo después, como "D".
    await _tap(tester, find.byTooltip('Opciones de la serie 1').first);
    await _tap(tester, find.text('Agregar drop set'));
    final sets = container.read(activeWorkoutProvider)!.exercises.first.sets;
    final drop = sets.indexWhere((s) => s.type == SetType.drop);
    expect(sets[drop - 1].type, SetType.normal);
    expect(find.text('D'), findsOneWidget);

    // Sin descanso en el ejercicio, marcar no lo inicia.
    await _tap(tester, find.bySemanticsLabel(RegExp('^Descanso entre series')).first);
    await _tap(tester, find.text('Sin descanso'));
    expect(container.read(activeWorkoutProvider)!.exercises.first.restSec, 0);
    await _tap(tester, find.bySemanticsLabel('Marcar serie 1 como hecha').first);
    expect(container.read(activeWorkoutProvider)!.rest, isNull);

    // Terminar también está al final de la lista.
    expect(find.text('Terminar entrenamiento'), findsOneWidget);
  });

  testWidgets('cerrar la pregunta del esfuerzo no termina el entrenamiento', (tester) async {
    final container = await _boot(tester);
    await _go(tester, container, '/fuerza');
    await _tap(tester, find.byTooltip('Empezar Rutina de pecho'));
    await _tap(tester, find.bySemanticsLabel('Marcar serie C como hecha').first);
    await _tap(tester, find.text('Terminar'));
    await _tap(tester, find.text('Terminar').last);
    await tester.tapAt(const Offset(200, 40)); // fuera de la hoja
    await _settle(tester);
    expect(container.read(activeWorkoutProvider), isNotNull);

    await _tap(tester, find.text('Terminar'));
    await _tap(tester, find.text('Terminar').last);
    await _tap(tester, find.text('Guardar sin indicar'));
    expect(find.text('¡Entrenamiento terminado!'), findsOneWidget);
    expect(container.read(workoutsProvider).value!.first.rpe, isNull);
    expect(find.text('Estimada (sin esfuerzo)'), findsOneWidget);
  });
}
