import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Recordatorios locales: mostrarlos también con la app abierta y recibir los toques.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Temporizador del descanso (AlarmKit): isla dinámica, pantalla bloqueada y alarma.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RestTimerPlugin") {
      RestTimerPlugin.register(with: registrar)
    }
  }
}
