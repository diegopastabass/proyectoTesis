/// Elegir una foto (cámara o galería) para el asistente: se reduce a 1080 px por
/// lado y se comprime en JPEG en el teléfono, como pide la tesis, antes de enviarla.
/// La foto no se guarda: se usa solo para la estimación.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';

/// Cómo se obtiene la foto (en las pruebas se reemplaza para no abrir la cámara).
typedef PhotoSource = Future<Uint8List?> Function(BuildContext context, {required String title});

final photoSourceProvider = Provider<PhotoSource>((ref) => pickPhoto);

Future<Uint8List?> pickPhoto(BuildContext context, {required String title}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (sheet) {
      final c = sheet.colors;
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.fgStrong)),
        ),
        ListTile(leading: Icon(Icons.photo_camera_outlined, color: c.primary), title: const Text('Sacar una foto'), onTap: () => Navigator.pop(sheet, ImageSource.camera)),
        ListTile(leading: Icon(Icons.photo_library_outlined, color: c.primary), title: const Text('Elegir de la galería'), onTap: () => Navigator.pop(sheet, ImageSource.gallery)),
        const SizedBox(height: 8),
      ]);
    },
  );
  if (source == null) return null;
  final file = await ImagePicker().pickImage(source: source, maxWidth: 1080, maxHeight: 1080, imageQuality: 80);
  return file?.readAsBytes();
}
