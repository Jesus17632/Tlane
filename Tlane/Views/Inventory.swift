import SwiftUI

struct InventoryView: View {
  var body: some View {
    Text("Inventario — próximamente")
      .navigationTitle("Inventario")
  }
}

#Preview {
  NavigationStack { InventoryView() }
}
