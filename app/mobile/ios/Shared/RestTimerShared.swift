// Código compartido entre la app (Runner) y la extensión del temporizador
// (RestTimerWidget): los datos de la alarma y las acciones de los botones de la
// isla dinámica y de la pantalla bloqueada.
//
// Las acciones (LiveActivityIntent) se ejecutan en el proceso de la app aunque se
// toquen en la pantalla bloqueada: por eso pueden actualizar `RestTimerStore`, que
// la app lee para saber cuánto falta.

import AlarmKit
import AppIntents
import Foundation
import SwiftUI

/// Datos propios de la alarma del descanso (se muestran en la pantalla bloqueada).
@available(iOS 26.0, *)
struct RestTimerMetadata: AlarmMetadata {
  /// Nombre del entrenamiento en curso.
  var subtitle: String?
}

/// Color de la app (aqua de la paleta Gruvbox).
enum RestTimerStyle {
  static let tint = Color(red: 0.557, green: 0.753, blue: 0.486)
}

/// Estado del descanso en curso, guardado en el teléfono: la alarma de AlarmKit
/// no informa la hora de término, así que la app la lleva aquí.
enum RestTimerStore {
  private static let defaults = UserDefaults.standard
  private static let idKey = "rest-timer.id"
  private static let endsAtKey = "rest-timer.endsAt"
  private static let leftKey = "rest-timer.leftMs"

  static var id: UUID? { defaults.string(forKey: idKey).flatMap(UUID.init(uuidString:)) }

  /// Fin de la cuenta (ms desde epoch) mientras corre.
  static var endsAt: Int? { defaults.object(forKey: endsAtKey) as? Int }

  /// ms que faltan, en pausa.
  static var leftMs: Int? { defaults.object(forKey: leftKey) as? Int }

  static func nowMs() -> Int { Int(Date().timeIntervalSince1970 * 1000) }

  static func started(id: UUID, seconds: Int) {
    defaults.set(id.uuidString, forKey: idKey)
    defaults.set(nowMs() + seconds * 1000, forKey: endsAtKey)
    defaults.removeObject(forKey: leftKey)
  }

  static func paused() {
    guard let endsAt else { return }
    defaults.set(max(0, endsAt - nowMs()), forKey: leftKey)
    defaults.removeObject(forKey: endsAtKey)
  }

  static func resumed() {
    guard let leftMs else { return }
    defaults.set(nowMs() + leftMs, forKey: endsAtKey)
    defaults.removeObject(forKey: leftKey)
  }

  static func clear() {
    defaults.removeObject(forKey: idKey)
    defaults.removeObject(forKey: endsAtKey)
    defaults.removeObject(forKey: leftKey)
  }
}

@available(iOS 26.0, *)
struct PauseRestIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Pausar el descanso"
  static let isDiscoverable = false

  @Parameter(title: "Alarma")
  var alarmID: String

  init() {}

  init(alarmID: String) {
    self.alarmID = alarmID
  }

  func perform() async throws -> some IntentResult {
    if let id = UUID(uuidString: alarmID) {
      try AlarmManager.shared.pause(id: id)
      RestTimerStore.paused()
    }
    return .result()
  }
}

@available(iOS 26.0, *)
struct ResumeRestIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Seguir el descanso"
  static let isDiscoverable = false

  @Parameter(title: "Alarma")
  var alarmID: String

  init() {}

  init(alarmID: String) {
    self.alarmID = alarmID
  }

  func perform() async throws -> some IntentResult {
    if let id = UUID(uuidString: alarmID) {
      try AlarmManager.shared.resume(id: id)
      RestTimerStore.resumed()
    }
    return .result()
  }
}

@available(iOS 26.0, *)
struct CancelRestIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Cancelar el descanso"
  static let isDiscoverable = false

  @Parameter(title: "Alarma")
  var alarmID: String

  init() {}

  init(alarmID: String) {
    self.alarmID = alarmID
  }

  func perform() async throws -> some IntentResult {
    if let id = UUID(uuidString: alarmID) {
      try AlarmManager.shared.cancel(id: id)
      RestTimerStore.clear()
    }
    return .result()
  }
}
