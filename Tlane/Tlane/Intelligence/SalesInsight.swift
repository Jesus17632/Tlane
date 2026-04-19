import FoundationModels

@Generable
struct SalesInsight {
  @Guide(description: "Consejo principal para el comerciante. Máximo 2 oraciones. Tono cercano, español mexicano.")
  var mainAdvice: String

  @Guide(description: "Razón breve basada en los datos de ventas proporcionados. Una oración.")
  var reasoning: String

  @Guide(description: "Una acción concreta sugerida, comenzando con verbo en infinitivo. Máximo 15 palabras.")
  var suggestedAction: String
}
