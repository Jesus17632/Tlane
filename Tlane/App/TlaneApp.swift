import SwiftUI
import SwiftData

@main
struct TlaneApp: App {
  @AppStorage("onboarding_completo") private var onboardingCompleto: Bool = false

  var body: some Scene {
    WindowGroup {
      if onboardingCompleto {
        ContentView()
      } else {
        WelcomeView()
      }
    }
    .modelContainer(AppContainer.makeProduction())
  }
}
