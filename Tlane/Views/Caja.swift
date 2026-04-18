import SwiftUI

struct CajaView: View {
  var body: some View {
    Text("Mi Caja — próximamente")
      .navigationTitle("Mi Caja")
  }
}

#Preview {
  NavigationStack { CajaView() }
}
