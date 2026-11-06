// Toma las capturas del panel de administración para la tesis, a 2× y sin ventana visible.
// Con el panel corriendo en http://localhost:5174 (npx vite --port 5174), desde app/:
//   swift scripts/capture_admin.swift ../figuras/interfaces
import AppKit
import WebKit

let shots: [(String, String)] = [
  ("cu10_lista", "/ejercicios"),
  ("cu10_repetido", "/ejercicios/nuevo?nombre=Press%20de%20banca%20con%20barra"),
  ("cu11_lista", "/reportes"),
  ("cu11_revisar", "/reportes/r1?ejemplo=1"),
]
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let size = NSRect(x: 0, y: 0, width: 1280, height: 800)

final class Capturer: NSObject, WKNavigationDelegate {
  let web = WKWebView(frame: size)
  var index = 0
  let window = NSWindow(contentRect: size, styleMask: .borderless, backing: .buffered, defer: false)

  func start() {
    window.contentView = web
    window.setFrameOrigin(NSPoint(x: -4000, y: -4000))
    window.orderBack(nil)
    web.navigationDelegate = self
    next()
  }

  func next() {
    guard index < shots.count else { NSApp.terminate(nil); return }
    // Una página nueva por captura, para partir sin el estado de la anterior.
    web.load(URLRequest(url: URL(string: "http://localhost:5174/admin.html?v=\(index)#\(shots[index].1)")!))
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
      let config = WKSnapshotConfiguration()
      config.rect = CGRect(origin: .zero, size: size.size)
      config.snapshotWidth = 2560
      webView.takeSnapshot(with: config) { image, error in
        let name = shots[self.index].0
        guard let image, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
          print("\(name): \(error?.localizedDescription ?? "sin imagen")")
          exit(1)
        }
        try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).jpg"))
        print(name)
        self.index += 1
        self.next()
      }
    }
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let capturer = Capturer()
capturer.start()
app.run()
