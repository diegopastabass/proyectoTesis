import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../data/repositories.dart';
import '../../ui/widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(backendProvider).auth.signIn();
    } on Object catch (e) {
      // Cerrar la ventana de Google no es un error que haya que mostrar.
      final text = e.toString();
      final cancelled = text.contains('canceled') || text.contains('cancelled') || text.contains('web-context-canceled');
      if (mounted) setState(() => _error = cancelled ? null : errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final method = ref.watch(backendProvider).auth.method;
    final (label, note) = switch (method) {
      SignInMethod.google => ('Ingresar con Google', null),
      SignInMethod.anonymous => ('Ingresar (emulador)', 'Modo emulador: se crea una cuenta anónima local.'),
      SignInMethod.demo => ('Entrar en modo demostración', 'Datos de prueba en memoria: se borran al cerrar la app.'),
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // El logo llega con un pequeño rebote: es la bienvenida.
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.6, end: 1),
                      duration: Motion.bouncyDuration,
                      curve: Motion.bouncy,
                      builder: (_, v, child) => Transform.scale(scale: Motion.reduced(context) ? 1 : v, child: child),
                      child: const AppLogo(size: 96),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'NutriApp',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: c.fgStrong),
                    ),
                    const SizedBox(height: 4),
                    Text('Nutrición, fuerza y cardio', style: TextStyle(fontSize: 12, color: c.muted)),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _login,
                        icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                        label: Text(label),
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        note,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: c.warning),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: c.danger),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
