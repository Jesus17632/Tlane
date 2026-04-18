import SwiftUI

/// Placeholder. En el paso 6 este view consumirá InsightsViewModel
/// con el SalesInsight generado por FoundationModels.
/// Por ahora redirige al Fallback para que HomeView funcione.
struct ConsejeroCardView: View {
  var body: some View {
    FallbackConsejeroCardView()
  }
}

#Preview {
  ConsejeroCardView()
    .padding()
    .background(Color.tlaneBackground)
}
