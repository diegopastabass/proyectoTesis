/// Configuración de compilación, leída de `--dart-define` o `--dart-define-from-file`.
///
/// Ejemplos (ver mobile/README.md):
///   flutter run                                              → modo demostración (memoria)
///   flutter run --dart-define-from-file=env/emulator.json    → Emulator Suite local
///   flutter run --dart-define-from-file=env/firebase.json    → proyecto real
library;

import '../data/repositories.dart';

class AppConfig {
  const AppConfig({
    required this.backend,
    this.emulatorHost = '127.0.0.1',
    this.firebase,
  });

  factory AppConfig.fromEnvironment() {
    const backend = String.fromEnvironment('BACKEND', defaultValue: 'memory');
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    final kind = BackendKind.values.where((k) => k.name == backend).firstOrNull ?? BackendKind.memory;
    return AppConfig(
      backend: kind,
      emulatorHost: const String.fromEnvironment('EMULATOR_HOST', defaultValue: '127.0.0.1'),
      firebase: apiKey.isEmpty || appId.isEmpty || projectId.isEmpty
          ? null
          : const FirebaseConfig(
              apiKey: apiKey,
              appId: appId,
              projectId: projectId,
              messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
              storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
              iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
              iosClientId: String.fromEnvironment('FIREBASE_IOS_CLIENT_ID'),
              authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
            ),
    );
  }

  final BackendKind backend;
  final String emulatorHost;
  final FirebaseConfig? firebase;

  /// Falta la configuración para conectarse al proyecto real.
  bool get missingFirebase => backend == BackendKind.firebase && firebase == null;
}

/// Valores de la app de iOS registrada en Firebase (GoogleService-Info.plist).
class FirebaseConfig {
  const FirebaseConfig({
    required this.apiKey,
    required this.appId,
    required this.projectId,
    this.messagingSenderId = '',
    this.storageBucket = '',
    this.iosBundleId = '',
    this.iosClientId = '',
    this.authDomain = '',
  });

  final String apiKey;
  final String appId;
  final String projectId;
  final String messagingSenderId;
  final String storageBucket;
  final String iosBundleId;

  /// CLIENT_ID del plist: el ingreso con Google vuelve a la app por su REVERSED_CLIENT_ID.
  final String iosClientId;
  final String authDomain;
}
