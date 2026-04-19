import SwiftUI
import SwiftData

/// Identificadores de cada tab. Se usan tanto como value en el TabView
/// como para que InventoryView (escáner) sepa si está activo.
enum AppTab: Hashable {
    case home
    case scan
    case inventory
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Inicio", systemImage: "house.fill", value: AppTab.home) {
                NavigationStack { HomeView() }
            }

            Tab("Escanear", systemImage: "camera.fill", value: AppTab.scan) {
                NavigationStack {
                    InventoryView(selectedTab: $selectedTab)
                }
            }

            Tab("Inventario", systemImage: "square.grid.2x2.fill", value: AppTab.inventory) {
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
