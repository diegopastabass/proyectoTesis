import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/activity/reminders.dart';
import '../../core/strength/session.dart';

/// Datos que viven solo en el dispositivo: la sesión de fuerza en curso, los
/// recordatorios y las preferencias de la interfaz.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static String _activeKey(String uid) => 'fuerza-activa:$uid';

  /// La sesión en curso sobrevive a cerrar la app (como en la web con localStorage).
  ActiveWorkout? readActiveWorkout(String uid) {
    final raw = _prefs.getString(_activeKey(uid));
    if (raw == null) return null;
    try {
      return ActiveWorkout.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<void> writeActiveWorkout(String uid, ActiveWorkout? w) async {
    if (w == null) {
      await _prefs.remove(_activeKey(uid));
    } else {
      await _prefs.setString(_activeKey(uid), jsonEncode(w.toJson()));
    }
  }

  /// Si ya se mostró la hoja de permisos de Apple Salud (iOS no dice si se aceptó).
  bool get healthRequested => _prefs.getBool('health-requested') ?? false;

  Future<void> markHealthRequested() => _prefs.setBool('health-requested', true);

  /// Si ya se mostró el diálogo de permiso de notificaciones.
  bool get notificationsRequested => _prefs.getBool('notifications-requested') ?? false;

  Future<void> markNotificationsRequested() => _prefs.setBool('notifications-requested', true);

  /// Recordatorios elegidos en este dispositivo.
  ReminderSettings get reminders {
    final raw = _prefs.getString('reminders');
    if (raw == null) return const ReminderSettings();
    try {
      return ReminderSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return const ReminderSettings();
    }
  }

  Future<void> setReminders(ReminderSettings r) => _prefs.setString('reminders', jsonEncode(r.toJson()));

  /// Última disciplina de cardio usada (se propone al abrir el módulo).
  String? get cardioDiscipline => _prefs.getString('cardio-discipline');

  Future<void> setCardioDiscipline(String name) => _prefs.setString('cardio-discipline', name);

  /// Unidad de peso preferida para los ejercicios nuevos y los totales ('kg' o 'lb').
  String? get weightUnit => _prefs.getString('weight-unit');

  Future<void> setWeightUnit(String unit) => _prefs.setString('weight-unit', unit);

  /// Razón ATL/CTL desde la que se avisa la fatiga (1,3 por defecto).
  double? get fatigueThreshold => _prefs.getDouble('fatigue-threshold');

  Future<void> setFatigueThreshold(double value) => _prefs.setDouble('fatigue-threshold', value);

  /// 'system', 'light' o 'dark'.
  String get themeMode => _prefs.getString('theme') ?? 'system';

  Future<void> setThemeMode(String mode) => _prefs.setString('theme', mode);
}
