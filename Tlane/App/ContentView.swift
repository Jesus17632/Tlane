import SwiftUI
import SwiftData

struct ContentView: View {
  var body: some View {
    TabView {
      Tab("Inicio", systemImage: "house.fill") {
        NavigationStack { HomeView() }
      }

      Tab("Cobrar", systemImage: "camera.fill") {
        NavigationStack { CaptureView() }
      }

      Tab("Inventario", systemImage: "square.grid.2x2.fill") {
        NavigationStack { InventoryView() }
      }

    }
    .tint(.tlaneGreen)
  }
}

#Preview {
  ContentView()
    .modelContainer(AppContainer.preview)
}
