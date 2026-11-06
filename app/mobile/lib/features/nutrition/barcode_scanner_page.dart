import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/theme.dart';
import '../../core/nutrition/barcode.dart';

/// Abre la cámara y devuelve el primer código válido (EAN-13, EAN-8, UPC-A, UPC-E).
Future<String?> scanBarcode(BuildContext context) => Navigator.of(context, rootNavigator: true)
    .push<String>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const BarcodeScannerPage()));

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _manual = TextEditingController();
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _accept(String raw) {
    final code = normalizeBarcode(raw);
    if (_done || !isValidGtin(code)) return;
    _done = true;
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final manualValid = isValidGtin(normalizeBarcode(_manual.text));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear código'),
        actions: [
          IconButton(tooltip: 'Linterna', onPressed: () => _controller.toggleTorch(), icon: const Icon(Icons.flashlight_on_outlined)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                for (final b in capture.barcodes) {
                  final value = b.rawValue;
                  if (value != null) _accept(value);
                }
              },
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? 'Sin permiso para usar la cámara. Actívalo en Ajustes › NutriApp, o escribe el código abajo.'
                        : 'No se pudo abrir la cámara (el simulador no tiene). Escribe el código abajo.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 260,
                  height: 140,
                  decoration: BoxDecoration(border: Border.all(color: c.primary, width: 2), borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]),
        ),
        Container(
          color: c.bg,
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _manual,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                onSubmitted: _accept,
                decoration: const InputDecoration(hintText: 'O escribe el código', prefixIcon: Icon(Icons.keyboard)),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: manualValid ? () => _accept(_manual.text) : null, child: const Text('Usar')),
          ]),
        ),
      ]),
    );
  }
}
