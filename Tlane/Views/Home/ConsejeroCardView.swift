import SwiftUI

struct ConsejeroCardView: View {
  @Bindable var viewModel: InsightsViewModel
  let onRefresh: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      // Estado visual principal
      if viewModel.isLoading {
        ConsejeroCardContent(
          icon: "sparkles",
          mainAdvice: "",
          reasoning: "",
          suggestedAction: "",
          isLoading: true
        )
      } else if let insight = viewModel.insight, !viewModel.usedFallback {
        ConsejeroCardContent(
          icon: "sparkles",
          mainAdvice: insight.mainAdvice,
          reasoning: insight.reasoning,
          suggestedAction: insight.suggestedAction,
          isLoading: false
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
      } else {
        // Fallback: ya sea porque Apple Intelligence no está disponible
        // o porque hubo un error de generación.
        FallbackConsejeroCardView()
      }

      // Botón de refresh — deshabilitado mientras carga
      Button {
        onRefresh()
      } label: {
        Label("Actualizar consejo", systemImage: "arrow.clockwise")
          .font(.caption.weight(.semibold))
      }
      .buttonStyle(.bordered)
      .tint(.tlaneGreen)
      .disabled(viewModel.isLoading)
    }
    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
    .animation(.easeInOut(duration: 0.3), value: viewModel.usedFallback)
  }
}

#Preview {
  let vm = InsightsViewModel()
  return ConsejeroCardView(viewModel: vm, onRefresh: {})
    .padding()
    .background(Color.tlaneBackground)
}
