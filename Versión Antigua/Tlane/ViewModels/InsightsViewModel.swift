import Foundation
import SwiftData

@Observable
@MainActor
final class InsightsViewModel {
    var insight: SalesInsight?
    var isLoading: Bool = false
    var errorMessage: String?
    var usedFallback: Bool = false

    private let session = ConsejeroSession()

    func generateIfNeeded(context: ModelContext) async {
        guard insight == nil, !isLoading else { return }
        await generateInsight(context: context)
    }

    func generateInsight(context: ModelContext) async {
        print("🚀 generateInsight llamado")
        let summary = AppContextBuilder.build(context: context)
        print("✅ Summary listo, mandando al modelo...")

        isLoading = true
        errorMessage = nil

        do {
            await session.resetSession()
            let result = try await session.generateInsight(salesSummary: summary)
            print("🎉 Modelo respondió: \(result.mainAdvice)")
            insight = result
            usedFallback = false
        } catch ConsejeroError.notAvailable(let reason) {
            print("❌ No disponible: \(reason)")
            errorMessage = reason
            usedFallback = true
        } catch ConsejeroError.refusal {
            print("❌ Refusal")
            errorMessage = "No pude generar un consejo ahora. Revisa tus ventas del día."
            usedFallback = true
        } catch {
            print("❌ Error genérico: \(error)")
            errorMessage = "Hubo un problema generando el consejo."
            usedFallback = true
        }

        isLoading = false
    }
}
