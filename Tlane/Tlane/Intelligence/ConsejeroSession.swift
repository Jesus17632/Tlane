import FoundationModels
import Foundation

enum ConsejeroError: Error {
  case notAvailable(reason: String)
  case refusal
  case generationFailed(Error)
}

actor ConsejeroSession {
  private var session: LanguageModelSession?

  // MARK: - Availability

  struct AvailabilityStatus {
    let isAvailable: Bool
    let reason: String?
  }

  func checkAvailability() -> AvailabilityStatus {
    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
      return AvailabilityStatus(isAvailable: true, reason: nil)

    case .unavailable(let unavailableReason):
      let message: String
      switch unavailableReason {
      case .appleIntelligenceNotEnabled:
        message = "Apple Intelligence no está activado en este dispositivo."
      case .deviceNotEligible:
        message = "Este dispositivo no soporta Apple Intelligence."
      case .modelNotReady:
        message = "El modelo aún se está descargando. Intenta en unos minutos."
      @unknown default:
        message = "Apple Intelligence no está disponible."
      }
      return AvailabilityStatus(isAvailable: false, reason: message)
    }
  }

  // MARK: - Generación

  func generateInsight(salesSummary: String) async throws -> SalesInsight {
    let status = checkAvailability()
    guard status.isAvailable else {
      throw ConsejeroError.notAvailable(reason: status.reason ?? "No disponible")
    }

    let instructions = """
    Eres un consejero financiero cercano para comerciantes de tianguis y mercados mexicanos. \
    Hablas en español mexicano coloquial pero respetuoso, como un amigo con experiencia en negocios. \
    Das consejos prácticos, concretos y accionables. \
    Nunca inventes datos que no estén en el resumen de ventas proporcionado. \
    Si no hay ventas aún, da consejos generales de exhibición o atención al cliente.
    """

    let prompt = """
    Resumen del día del comerciante:
    \(salesSummary)

    Genera un consejo breve para ayudarle a vender más o gestionar mejor su negocio hoy.
    """

    // Reutilizamos la sesión entre llamadas para mantener el contexto coherente
    if session == nil {
      session = LanguageModelSession(instructions: instructions)
    }
    guard let session else {
      throw ConsejeroError.notAvailable(reason: "No se pudo crear la sesión")
    }

    do {
      let response = try await session.respond(
        to: prompt,
        generating: SalesInsight.self
      )
      return response.content
    } catch let error as LanguageModelSession.GenerationError {
      // Manejo específico de refusal
      if case .refusal = error {
        throw ConsejeroError.refusal
      }
      throw ConsejeroError.generationFailed(error)
    } catch {
      throw ConsejeroError.generationFailed(error)
    }
  }

  /// Limpia la sesión actual para forzar un nuevo contexto en la próxima llamada.
  func resetSession() {
    session = nil
  }
}   
