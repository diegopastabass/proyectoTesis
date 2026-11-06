import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_host.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';

const _locales = [Locale('es', 'CL'), Locale('es')];

const _delegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class AsistenteApp extends ConsumerWidget {
  const AsistenteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'NutriApp',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      locale: _locales.first,
      supportedLocales: _locales,
      localizationsDelegates: _delegates,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => NotificationHost(child: child ?? const SizedBox()),
    );
  }
}

/// Se muestra cuando se compila para Firebase sin su configuración.
class SetupNoticeApp extends StatelessWidget {
  const SetupNoticeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.dark),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: const [
              Text('Falta configurar Firebase', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              SizedBox(height: 12),
              Text('Se compiló con BACKEND=firebase pero faltan FIREBASE_API_KEY, FIREBASE_APP_ID o FIREBASE_PROJECT_ID.'),
              SizedBox(height: 8),
              Text('Copia mobile/env/firebase.example.json como env/firebase.json, complétalo y ejecuta:\n'
                  'flutter run --dart-define-from-file=env/firebase.json\n\n'
                  'Sin configuración, "flutter run" abre el modo demostración.'),
            ]),
          ),
        ),
      ),
    );
  }
}
