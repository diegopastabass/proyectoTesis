import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/cardio_providers.dart';
import 'app/config.dart';
import 'app/providers.dart';
import 'data/backend_factory.dart';
import 'data/local/cardio_store.dart';
import 'data/local/local_store.dart';
import 'data/repositories.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (config.missingFirebase) {
    runApp(const SetupNoticeApp());
    return;
  }
  final capture = config.backend == BackendKind.memory ? _readCaptureRequest() : null;
  final backend = await createBackend(config, capture: capture != null);
  final prefs = await SharedPreferences.getInstance();
  // Las rutas de cardio se guardan en archivos del teléfono (funciona sin internet).
  // En modo demostración (y en la web) quedan en memoria, como el resto de los datos.
  final support = backend.kind == BackendKind.memory || kIsWeb ? null : await getApplicationSupportDirectory();
  runApp(ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      captureProvider.overrideWithValue(capture),
      backendProvider.overrideWithValue(backend),
      localStoreProvider.overrideWithValue(LocalStore(prefs)),
      if (support != null)
        cardioStoreFactoryProvider.overrideWithValue((uid) => FileCardioLocalStore(Directory('${support.path}/cardio/$uid'))),
    ],
    child: const AsistenteApp(),
  ));
}

/// Modo de capturas (`tool/capture_screens.py`): el pedido llega en un archivo dentro de
/// la carpeta temporal de la app, porque Dart no puede leer variables de entorno en iOS.
CaptureRequest? _readCaptureRequest() {
  if (kIsWeb) return null;
  final temp = Directory.systemTemp.path;
  final file = File('$temp/nutri_capture.json');
  if (!file.existsSync()) return null;
  final request = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  captureScrollOffset = (request['scroll'] as num?)?.toDouble();
  return CaptureRequest(
    route: request['route']! as String,
    replace: request['go'] == true,
    onReady: () => File('$temp/nutri_ready').writeAsStringSync('listo'),
  );
}
