import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../app/config.dart';
import 'assets/catalog_assets.dart';
import 'firebase/firebase_backend.dart';
import 'memory/memory_backend.dart';
import 'remote/lookup_client.dart';
import 'repositories.dart';

/// Proyecto "demo-" del emulador: no necesita credenciales reales (igual que .env.emulator).
const _emulatorOptions = FirebaseOptions(
  apiKey: 'demo-api-key',
  // iOS valida el formato del App ID aunque el emulador no lo use.
  appId: '1:000000000000:ios:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-nutricion',
);

/// Crea el backend según la configuración de compilación.
Future<Backend> createBackend(AppConfig config, {CatalogAssets? assets}) async {
  final lookup = HttpLookupRepository();
  switch (config.backend) {
    case BackendKind.memory:
      final seed = await (assets ?? CatalogAssets()).seedFoods(demoUser.uid);
      return memoryBackend(seedFoods: seed, lookup: lookup);
    case BackendKind.emulator:
      await Firebase.initializeApp(options: _emulatorOptions);
      final auth = FirebaseAuth.instance;
      final db = FirebaseFirestore.instance;
      await auth.useAuthEmulator(config.emulatorHost, 9099);
      db.useFirestoreEmulator(config.emulatorHost, 8080);
      return _firebase(BackendKind.emulator, auth, db, lookup, SignInMethod.anonymous);
    case BackendKind.firebase:
      final f = config.firebase!;
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: f.apiKey,
          appId: f.appId,
          messagingSenderId: f.messagingSenderId,
          projectId: f.projectId,
          storageBucket: f.storageBucket.isEmpty ? null : f.storageBucket,
          iosBundleId: f.iosBundleId.isEmpty ? null : f.iosBundleId,
          iosClientId: f.iosClientId.isEmpty ? null : f.iosClientId,
          authDomain: f.authDomain.isEmpty ? null : f.authDomain,
        ),
      );
      return _firebase(BackendKind.firebase, FirebaseAuth.instance, FirebaseFirestore.instance, lookup, SignInMethod.google);
  }
}

Backend _firebase(BackendKind kind, FirebaseAuth auth, FirebaseFirestore db, LookupRepository lookup, SignInMethod method) => Backend(
      kind: kind,
      auth: FirebaseAuthRepository(auth, method: method),
      foods: FirestoreFoodRepository(db),
      recipes: FirestoreRecipeRepository(db),
      diary: FirestoreDiaryRepository(db),
      profile: FirestoreProfileRepository(db),
      strength: FirestoreStrengthRepository(db),
      cardio: FirestoreCardioRepository(db),
      lookup: lookup,
    );
