// Cómo se ve el temporizador del descanso fuera de la app: en la isla dinámica
// (compacta, mínima y expandida) y en la pantalla bloqueada, con botones para
// pausar, seguir y cancelar. La cuenta la lleva el sistema (AlarmKit): sigue
// aunque la app esté cerrada y al terminar suena la alarma.

import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
import WidgetKit

typealias RestAttributes = AlarmAttributes<RestTimerMetadata>

struct RestTimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RestAttributes.self) { context in
      RestLockScreenView(state: context.state, attributes: context.attributes)
        .activityBackgroundTint(Color.black.opacity(0.55))
        .activitySystemActionForegroundColor(context.attributes.tintColor)
    } dynamicIsland: { context in
      let tint = context.attributes.tintColor
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label {
            Text(RestText.title(context.state))
          } icon: {
            Image(systemName: RestText.icon(context.state))
          }
          .font(.headline)
          .foregroundStyle(tint)
          .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          RestCountdown(state: context.state)
            .font(.system(size: 30, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(tint)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 110, alignment: .trailing)
            .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.bottom) {
          RestControls(state: context.state, tint: tint)
            .padding(.top, 6)
        }
      } compactLeading: {
        Image(systemName: RestText.icon(context.state))
          .foregroundStyle(tint)
      } compactTrailing: {
        RestCountdown(state: context.state)
          .monospacedDigit()
          .foregroundStyle(tint)
          .frame(maxWidth: 48)
      } minimal: {
        Image(systemName: RestText.icon(context.state))
          .foregroundStyle(tint)
      }
      .keylineTint(tint)
    }
  }
}

enum RestText {
  static func title(_ state: AlarmPresentationState) -> String {
    switch state.mode {
    case .countdown: return "Descanso"
    case .paused: return "En pausa"
    case .alert: return "¡A la siguiente serie!"
    @unknown default: return "Descanso"
    }
  }

  static func icon(_ state: AlarmPresentationState) -> String {
    switch state.mode {
    case .countdown: return "timer"
    case .paused: return "pause.circle.fill"
    case .alert: return "bell.fill"
    @unknown default: return "timer"
    }
  }

  /// "1:05" a partir de segundos.
  static func clock(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds.rounded(.up)))
    return String(format: "%d:%02d", s / 60, s % 60)
  }
}

/// Cuenta regresiva: la dibuja el sistema segundo a segundo, sin despertar la app.
struct RestCountdown: View {
  let state: AlarmPresentationState

  var body: some View {
    switch state.mode {
    case .countdown(let c):
      Text(timerInterval: Date.now...max(Date.now, c.fireDate), countsDown: true)
    case .paused(let p):
      Text(RestText.clock(p.totalCountdownDuration - p.previouslyElapsedDuration))
    case .alert:
      Text("0:00")
    @unknown default:
      Text("")
    }
  }
}

/// Pausar o seguir, y cancelar. Las acciones corren en la app (AlarmKit).
struct RestControls: View {
  let state: AlarmPresentationState
  let tint: Color

  var body: some View {
    let id = state.alarmID.uuidString
    HStack(spacing: 10) {
      switch state.mode {
      case .countdown:
        Button(intent: PauseRestIntent(alarmID: id)) {
          Label("Pausar", systemImage: "pause.fill").frame(maxWidth: .infinity)
        }
        .tint(tint)
      case .paused:
        Button(intent: ResumeRestIntent(alarmID: id)) {
          Label("Seguir", systemImage: "play.fill").frame(maxWidth: .infinity)
        }
        .tint(tint)
      default:
        EmptyView()
      }
      if case .alert = state.mode {
        EmptyView()
      } else {
        Button(intent: CancelRestIntent(alarmID: id)) {
          Label("Cancelar", systemImage: "xmark").frame(maxWidth: .infinity)
        }
        .tint(.gray)
      }
    }
    .buttonStyle(.borderedProminent)
    .buttonBorderShape(.capsule)
    .font(.subheadline.weight(.semibold))
  }
}

struct RestLockScreenView: View {
  let state: AlarmPresentationState
  let attributes: RestAttributes

  var body: some View {
    let tint = attributes.tintColor
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Label(RestText.title(state), systemImage: RestText.icon(state))
            .font(.headline)
            .foregroundStyle(tint)
          if let subtitle = attributes.metadata?.subtitle, !subtitle.isEmpty {
            Text(subtitle)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        Spacer()
        RestCountdown(state: state)
          .font(.system(size: 40, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(tint)
          .multilineTextAlignment(.trailing)
          .frame(maxWidth: 140, alignment: .trailing)
      }
      if case .countdown(let c) = state.mode {
        ProgressView(timerInterval: c.startDate...max(c.startDate, c.fireDate), countsDown: true) {
          EmptyView()
        } currentValueLabel: {
          EmptyView()
        }
        .tint(tint)
      }
      RestControls(state: state, tint: tint)
    }
    .padding(16)
  }
}
