import Foundation

@Observable
@MainActor
final class InsightsViewModel {
  var insight: SalesInsight?
  var isLoading: Bool = false
  var errorMessage: String?
  var usedFallback: Bool = false

  private let session = ConsejeroSession()

  /// Genera solo si no existe un insight previo. Úsalo en .onAppear.
  func generateIfNeeded(salesSummary: String) async {
    guard insight == nil, !isLoading else { return }
    await generateInsight(salesSummary: salesSummary)
  }

  /// Fuerza nueva generación. Úsalo en botón "Actualizar".
  func generateInsight(salesSummary: String) async {
    isLoading = true
    errorMessage = nil

    do {
      await session.resetSession() // Forzar contexto nuevo
      let result = try await session.generateInsight(salesSummary: salesSummary)
      insight = result
      usedFallback = false
    } catch ConsejeroError.notAvailable(let reason) {
      errorMessage = reason
      usedFallback = true
    } catch ConsejeroError.refusal {
      errorMessage = "No pude generar un consejo ahora. Revisa tus ventas del día."
      usedFallback = true
    } catch {
      errorMessage = "Hubo un problema generando el consejo."
      usedFallback = true
    }

    isLoading = false
  }
}
