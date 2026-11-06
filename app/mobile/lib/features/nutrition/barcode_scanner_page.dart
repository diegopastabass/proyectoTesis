import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/theme.dart';
import '../../core/nutrition/barcode.dart';

/// Abre la cámara y devuelve el primer código válido (EAN-13, EAN-8, UPC-A, UPC-E).
Future<String?> scanBarcode(BuildContext context) => Navigator.of(context, rootNavigator: true)
    .push<String>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const BarcodeScannerPage()));

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key, this.simulated = false});

  /// Muestra un visor de ejemplo en vez de la cámara: el simulador no tiene (modo de capturas).
  final bool simulated;

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
        // Sobre negro: el tema dejaría el título y la barra de estado oscuros.
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: Colors.white),
        title: const Text('Escanear código'),
        actions: [
          IconButton(tooltip: 'Linterna', onPressed: () => _controller.toggleTorch(), icon: const Icon(Icons.flashlight_on_outlined)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            if (widget.simulated)
              const _SimulatedViewfinder()
            else
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

/// Envase de ejemplo con su código de barras, para mostrar el visor sin cámara.
class _SimulatedViewfinder extends StatelessWidget {
  const _SimulatedViewfinder();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF3A3531),
        child: Center(
          child: Container(
            width: 216,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 74,
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var i = 0; i < 46; i++) Expanded(flex: 1 + (i * 7) % 3, child: ColoredBox(color: i.isEven ? Colors.black : Colors.white)),
                ]),
              ),
              const SizedBox(height: 4),
              const Text('7 802900 123456', style: TextStyle(fontSize: 13, letterSpacing: 1.6, color: Colors.black)),
            ]),
          ),
        ),
      );
}
