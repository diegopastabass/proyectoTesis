// Extensión de widgets: solo la actividad en vivo del temporizador del descanso.

import SwiftUI
import WidgetKit

@main
struct RestTimerWidgetBundle: WidgetBundle {
  var body: some Widget {
    RestTimerLiveActivity()
  }
}
