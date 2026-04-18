import SwiftUI
import SwiftData

struct ContentView: View {
  var body: some View {
    TabView {
      Tab("Inicio", systemImage: "house.fill") {
        NavigationStack { HomeView() }
      }
        
    Tab("Escanear", systemImage: "camera.fill") {
        NavigationStack { InventoryView() }
        }


      Tab("Inventario", systemImage: "square.grid.2x2.fill") {
        NavigationStack { CaptureView() }
      }

    }
    .tint(.tlaneGreen)
  }
}

#Preview {
  ContentView()
    .modelContainer(AppContainer.preview)
}
