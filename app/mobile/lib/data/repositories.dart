/// Contratos de la capa de datos.
///
/// Las pantallas y la lógica dependen solo de estas interfaces. Hay dos
/// implementaciones: Firestore (`firebase/`, mismos documentos que la versión web)
/// y memoria (`memory/`, para el modo demostración y las pruebas). Cambiar de
/// backend (por ejemplo, a una API propia o a una base local con sincronización)
/// solo exige otra implementación de estas interfaces.
library;

import '../core/activity/calendar.dart';
import '../core/activity/streak.dart';
import '../core/body/energy.dart';
import '../core/cardio/activity.dart';
import '../core/body/progress.dart';
import '../core/nutrition/models.dart';
import '../core/nutrition/open_food_facts.dart';
import '../core/strength/models.dart';
import '../core/strength/plan.dart';

class AppUser {
  const AppUser({required this.uid, this.displayName, this.email, this.photoUrl, this.isAnonymous = false});

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final bool isAnonymous;

  String get label => displayName ?? email ?? (isAnonymous ? 'Cuenta de prueba' : 'Usuario');

  String get initial => label.isEmpty ? '?' : String.fromCharCode(label.runes.first).toUpperCase();
}

/// Cómo inicia sesión cada backend, para mostrarlo en la pantalla de ingreso.
enum SignInMethod {
  /// Google (Firebase real).
  google,

  /// Cuenta anónima en el emulador de Firebase.
  anonymous,

  /// Usuario local de demostración (sin red).
  demo,
}

abstract interface class AuthRepository {
  SignInMethod get method;
  AppUser? get currentUser;
  Stream<AppUser?> watchUser();
  Future<void> signIn();
  Future<void> signOut();
}

abstract interface class FoodRepository {
  /// Catálogo público.
  Stream<List<Food>> watchFoods();
  Future<String> createFood(FoodInput input, String uid, FoodSource source);
  Future<void> updateFood(String id, FoodInput input);

  /// Agrega los alimentos que faltan y completa la fibra de los propios.
  Future<void> importSeed({required List<Food> missing, required List<Food> fiberPatches});
}

abstract interface class RecipeRepository {
  /// Recetas privadas del usuario, ordenadas por nombre.
  Stream<List<Recipe>> watchRecipes(String uid);

  /// Crea (sin `id`) o reemplaza una receta. Devuelve su id.
  Future<String> saveRecipe(Recipe recipe, {String? id});
  Future<void> deleteRecipe(String id);
}

abstract interface class DiaryRepository {
  Stream<List<DiaryEntry>> watchDay(String uid, String date);

  /// Agrega los registros y actualiza el resumen del día en la misma escritura.
  Future<void> addEntries(String uid, String date, List<NewDiaryEntry> entries);
  Future<void> deleteEntry(String uid, String date, DiaryEntry entry);

  /// Días con al menos un registro (para el calendario, la racha y el gasto real).
  Stream<List<LoggedDay>> watchLoggedDays(String uid);

  /// Crea el resumen de los días registrados antes de que existiera (una vez por cuenta).
  Future<void> ensureDayIndex(String uid);
}

/// Perfil del usuario: objetivos diarios, meta corporal, datos corporales, registro de peso y racha.
abstract interface class ProfileRepository {
  Stream<Goals> watchGoals(String uid);
  Future<void> saveGoals(String uid, Goals goals);
  Stream<BodyGoal?> watchBodyGoal(String uid);
  Future<void> saveBodyGoal(String uid, BodyGoal goal);

  /// Un registro por día, ordenados por fecha.
  Stream<List<WeightEntry>> watchWeights(String uid);

  /// Guardar dos veces el mismo día reemplaza el registro.
  Future<void> saveWeight(String uid, WeightEntry entry);
  Future<void> deleteWeight(String uid, String date);

  /// Estatura, fecha de nacimiento, sexo y actividad.
  Stream<BodyProfile> watchBodyProfile(String uid);
  Future<void> saveBodyProfile(String uid, BodyProfile profile);

  /// Días de descanso de la racha (1 = lunes … 7 = domingo).
  Stream<Set<int>> watchStreakRestDays(String uid);
  Future<void> saveStreakRestDays(String uid, Set<int> weekdays);

  /// Último hito de racha celebrado.
  Stream<StreakCelebration?> watchStreakCelebration(String uid);
  Future<void> saveStreakCelebration(String uid, StreakCelebration celebration);

  /// Días de entrenamiento y programa que se sigue.
  Stream<TrainingPlan> watchTrainingPlan(String uid);
  Future<void> saveTrainingPlan(String uid, TrainingPlan plan);
}

abstract interface class StrengthRepository {
  /// Rutinas ordenadas por nombre.
  Stream<List<Routine>> watchRoutines(String uid);
  Future<String> saveRoutine(String uid, {required String name, required List<RoutineExercise> exercises, String? id});
  Future<void> deleteRoutine(String uid, String id);

  /// De la más reciente a la más antigua.
  Stream<List<Workout>> watchWorkouts(String uid);
  Future<String> saveWorkout(String uid, NewWorkout workout);
  Future<void> deleteWorkout(String uid, String id);

  /// Cambia el esfuerzo percibido de una sesión ya guardada.
  Future<void> setWorkoutRpe(String uid, String id, int rpe);

  Stream<List<Exercise>> watchCustomExercises(String uid);
  Future<Exercise> createCustomExercise(String uid, {required String name, String? equipment, required List<String> primary});
}

/// Respaldo en la nube de las actividades de cardio. La fuente de verdad está en
/// el teléfono (`CardioLocalStore`): esto solo sube, baja y borra copias.
abstract interface class CardioRepository {
  /// Sube el resumen y, si se entrega, la ruta. Repetirlo con el mismo id no duplica.
  Future<void> saveActivity(String uid, CardioActivity activity, [CardioTrack? track]);

  /// id → última modificación de cada actividad respaldada.
  Future<Map<String, int>> index(String uid);

  /// Resumen y ruta (para restaurar en un teléfono nuevo).
  Future<({CardioActivity activity, CardioTrack track})?> loadActivity(String uid, String id);
  Future<void> deleteActivity(String uid, String id);
}

/// Datos de terceros que no dependen del usuario.
abstract interface class LookupRepository {
  /// Producto de Open Food Facts por código; null si no existe.
  Future<OffDraft?> lookupBarcode(String code);

  /// Instrucciones (en inglés) del catálogo de ejercicios.
  Future<List<String>> exerciseInstructions(String exerciseId);
}

/// Prefijo de los ejercicios propios, para no chocar con los ids del catálogo.
const customExercisePrefix = 'u:';

/// Todo lo que necesita la app para leer y guardar datos.
class Backend {
  const Backend({
    required this.kind,
    required this.auth,
    required this.foods,
    required this.recipes,
    required this.diary,
    required this.profile,
    required this.strength,
    required this.cardio,
    required this.lookup,
  });

  final BackendKind kind;
  final AuthRepository auth;
  final FoodRepository foods;
  final RecipeRepository recipes;
  final DiaryRepository diary;
  final ProfileRepository profile;
  final StrengthRepository strength;
  final CardioRepository cardio;
  final LookupRepository lookup;
}

enum BackendKind {
  /// Datos en memoria con un usuario de prueba: funciona sin red ni configuración.
  memory,

  /// Emulator Suite de Firebase en este computador.
  emulator,

  /// Proyecto real de Firebase.
  firebase,
}
