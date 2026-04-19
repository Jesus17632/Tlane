import SwiftUI
import SwiftData

struct ConsejeroCardView: View {
    @Bindable var viewModel: InsightsViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 12) {
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
                FallbackConsejeroCardView()
            }

            Button {
                Task { await viewModel.generateInsight(context: modelContext) }
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
        .task {
            await viewModel.generateIfNeeded(context: modelContext)
        }
    }
}

#Preview {
    let vm = InsightsViewModel()
    return ConsejeroCardView(viewModel: vm)
        .padding()
        .background(Color.tlaneBackground)
}
