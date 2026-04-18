import SwiftUI
import SwiftData

@main
struct TlaneApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(AppContainer.makeProduction())
  }
}
