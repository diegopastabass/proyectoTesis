// Temporizador del descanso con AlarmKit (iOS 26+): cuenta regresiva en la isla
// dinámica y en la pantalla bloqueada (con pausar, seguir y cancelar) y una alarma
// al terminar, como el temporizador del reloj de iPhone.
//
// Canal `nutriapp/rest_timer` (órdenes desde Flutter) y `nutriapp/rest_timer/events`
// (cambios hechos fuera de la app). Ver lib/platform/rest_timer/rest_timer_service.dart.

import ActivityKit
import AlarmKit
import Flutter
import SwiftUI
import UIKit

final class RestTimerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var updates: Task<Void, Never>?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = RestTimerPlugin()
    let channel = FlutterMethodChannel(name: "nutriapp/rest_timer", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    FlutterEventChannel(name: "nutriapp/rest_timer/events", binaryMessenger: registrar.messenger()).setStreamHandler(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 26.0, *) else {
      result(call.method == "supported" ? false : FlutterError(code: "unsupported", message: "El temporizador del sistema requiere iOS 26", details: nil))
      return
    }
    let args = call.arguments as? [String: Any]
    let seconds = args?["seconds"] as? Int ?? 60
    let subtitle = args?["exercise"] as? String
    Task { @MainActor in
      do {
        switch call.method {
        case "supported":
          result(true)
        case "status":
          result(RestTimerController.name(AlarmManager.shared.authorizationState))
        case "request":
          result(RestTimerController.name(try await AlarmManager.shared.requestAuthorization()))
        case "start":
          try await RestTimerController.shared.start(seconds: seconds, subtitle: subtitle)
          result(nil)
        case "pause":
          try RestTimerController.shared.pause()
          result(nil)
        case "resume":
          try await RestTimerController.shared.resume(seconds: seconds, subtitle: subtitle)
          result(nil)
        case "cancel":
          RestTimerController.shared.cancel()
          result(nil)
        case "current":
          result(RestTimerController.shared.snapshot() ?? NSNull())
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "alarm", message: "\(error)", details: nil))
      }
    }
  }

  // MARK: FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    guard #available(iOS 26.0, *) else { return nil }
    updates = Task { @MainActor [weak self] in
      for await _ in AlarmManager.shared.alarmUpdates {
        guard let self, !RestTimerController.shared.replacing else { continue }
        self.sink?(RestTimerController.shared.snapshot() ?? NSNull())
      }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    updates?.cancel()
    updates = nil
    sink = nil
    return nil
  }
}

@available(iOS 26.0, *)
@MainActor
final class RestTimerController {
  static let shared = RestTimerController()

  /// Mientras se reemplaza una cuenta por otra no se informan cambios (la cuenta
  /// vieja desaparece un instante antes de que exista la nueva).
  private(set) var replacing = false

  static func name(_ state: AlarmManager.AuthorizationState) -> String {
    switch state {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .notDetermined: return "notDetermined"
    @unknown default: return "notDetermined"
    }
  }

  private var manager: AlarmManager { AlarmManager.shared }

  private func presentation() -> AlarmPresentation {
    let alert: AlarmPresentation.Alert
    if #available(iOS 26.1, *) {
      alert = AlarmPresentation.Alert(title: "Descanso terminado")
    } else {
      alert = AlarmPresentation.Alert(title: "Descanso terminado", stopButton: AlarmButton(text: "Listo", textColor: .white, systemImageName: "checkmark"))
    }
    return AlarmPresentation(
      alert: alert,
      countdown: AlarmPresentation.Countdown(title: "Descanso", pauseButton: AlarmButton(text: "Pausar", textColor: RestTimerStyle.tint, systemImageName: "pause.fill")),
      paused: AlarmPresentation.Paused(title: "Descanso en pausa", resumeButton: AlarmButton(text: "Seguir", textColor: RestTimerStyle.tint, systemImageName: "play.fill"))
    )
  }

  /// Empieza una cuenta nueva y quita la anterior (solo hay un descanso a la vez).
  func start(seconds: Int, subtitle: String?) async throws {
    replacing = true
    defer { replacing = false }
    for alarm in (try? manager.alarms) ?? [] {
      try? manager.cancel(id: alarm.id)
    }
    let id = UUID()
    let attributes = AlarmAttributes(presentation: presentation(), metadata: RestTimerMetadata(subtitle: subtitle), tintColor: RestTimerStyle.tint)
    RestTimerStore.started(id: id, seconds: seconds)
    do {
      _ = try await manager.schedule(id: id, configuration: .timer(duration: TimeInterval(max(1, seconds)), attributes: attributes))
    } catch {
      RestTimerStore.clear()
      throw error
    }
  }

  private var current: Alarm? {
    guard let id = RestTimerStore.id else { return nil }
    return ((try? manager.alarms) ?? []).first { $0.id == id }
  }

  func pause() throws {
    guard let alarm = current, alarm.state == .countdown else { return }
    try manager.pause(id: alarm.id)
    RestTimerStore.paused()
  }

  /// Sigue la cuenta en pausa; si ya no existe, empieza una con lo que quedaba.
  func resume(seconds: Int, subtitle: String?) async throws {
    if let alarm = current, alarm.state == .paused {
      try manager.resume(id: alarm.id)
      RestTimerStore.resumed()
    } else {
      try await start(seconds: seconds, subtitle: subtitle)
    }
  }

  func cancel() {
    if let id = RestTimerStore.id { try? manager.cancel(id: id) }
    RestTimerStore.clear()
  }

  /// Estado del descanso para Flutter; nil si ya no hay (se canceló o sonó y se apagó).
  func snapshot() -> [String: Any]? {
    guard let alarm = current else {
      RestTimerStore.clear()
      return nil
    }
    // La actividad en vivo trae la hora exacta de término (también tras pausar
    // desde la pantalla bloqueada); si no está, se usa lo guardado.
    if let activity = Activity<AlarmAttributes<RestTimerMetadata>>.activities.first(where: { $0.content.state.alarmID == alarm.id }) {
      switch activity.content.state.mode {
      case .countdown(let c):
        return ["state": "countdown", "endsAt": Int(c.fireDate.timeIntervalSince1970 * 1000)]
      case .paused(let p):
        return ["state": "paused", "leftMs": Int(max(0, p.totalCountdownDuration - p.previouslyElapsedDuration) * 1000)]
      case .alert:
        return ["state": "alerting"]
      @unknown default:
        break
      }
    }
    switch alarm.state {
    case .countdown, .scheduled:
      return ["state": "countdown", "endsAt": RestTimerStore.endsAt ?? RestTimerStore.nowMs()]
    case .paused:
      return ["state": "paused", "leftMs": RestTimerStore.leftMs ?? 0]
    case .alerting:
      return ["state": "alerting"]
    @unknown default:
      return nil
    }
  }
}
