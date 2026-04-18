import SwiftUI

struct FallbackConsejeroCardView: View {
  /// Los consejos rotan según el día del año para que en demos
  /// sucesivos no aparezca siempre el mismo.
  private static let consejos: [FallbackAdvice] = [
    FallbackAdvice(
      mainAdvice: "Los días soleados aumentan el flujo en el mercado.",
      reasoning: "La gente pasea más y se detiene en puestos con piezas visibles desde lejos.",
      suggestedAction: "Colocar tus piezas más coloridas al frente."
    ),
    FallbackAdvice(
      mainAdvice: "Tus ventas del fin de semana suelen duplicar las de entre semana.",
      reasoning: "Sábados y domingos concentran a turistas y familias que pagan en efectivo.",
      suggestedAction: "Llevar cambio suficiente en billetes de $50 y $100."
    ),
    FallbackAdvice(
      mainAdvice: "Las piezas únicas se venden mejor con una historia detrás.",
      reasoning: "Los compradores de artesanía valoran el origen y quién la hizo.",
      suggestedAction: "Anotar en el inventario una frase corta sobre cada pieza."
    )
  ]

  private var adviceOfTheDay: FallbackAdvice {
    let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1
    return Self.consejos[dayOfYear % Self.consejos.count]
  }

  var body: some View {
    ConsejeroCardContent(
      mainAdvice: adviceOfTheDay.mainAdvice,
      reasoning: adviceOfTheDay.reasoning,
      suggestedAction: adviceOfTheDay.suggestedAction,
      isLoading: false
    )
  }
}

private struct FallbackAdvice {
  let mainAdvice: String
  let reasoning: String
  let suggestedAction: String
}

/// Contenido compartido entre FallbackConsejeroCardView y el ConsejeroCardView real.
/// Cuando conectemos Apple Intelligence reutilizamos esta misma vista.
struct ConsejeroCardContent: View {
  let mainAdvice: String
  let reasoning: String
  let suggestedAction: String
  let isLoading: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 10) {
        Image(systemName: "sparkles")
          .font(.title2)
          .foregroundStyle(.white)
        Text("El Consejero")
          .font(.headline)
          .foregroundStyle(.white)
        Spacer()
      }

      if isLoading {
        HStack(spacing: 10) {
          ProgressView()
            .tint(.white)
          Text("El Consejero está pensando…")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.9))
        }
      } else {
        VStack(alignment: .leading, spacing: 12) {
          Text(mainAdvice)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)

          Text(reasoning)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.85))

          HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.right.circle.fill")
              .foregroundStyle(.white.opacity(0.9))
            Text(suggestedAction)
              .font(.subheadline.weight(.medium))
              .foregroundStyle(.white)
          }
          .padding(.top, 4)
        }
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.tlaneGreen)
    .clipShape(RoundedRectangle(cornerRadius: 20))
  }
}

#Preview {
  FallbackConsejeroCardView()
    .padding()
    .background(Color.tlaneBackground)
}
