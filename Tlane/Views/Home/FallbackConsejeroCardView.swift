import SwiftUI

struct FallbackConsejeroCardView: View {
  private static let consejos: [FallbackAdvice] = [
    FallbackAdvice(
      icon: "sun.max.fill",
      mainAdvice: "Los días soleados aumentan el flujo en el mercado.",
      reasoning: "La gente pasea más y se detiene en puestos con piezas visibles desde lejos.",
      suggestedAction: "Coloca tus piezas más coloridas al frente hoy."
    ),
    FallbackAdvice(
      icon: "calendar.badge.clock",
      mainAdvice: "Tus ventas del fin de semana suelen duplicar las de entre semana.",
      reasoning: "Sábados y domingos concentran a turistas y familias que pagan en efectivo.",
      suggestedAction: "Lleva cambio suficiente en billetes de $50 y $100."
    ),
    FallbackAdvice(
      icon: "sparkles",
      mainAdvice: "Las piezas únicas se venden mejor con una historia detrás.",
      reasoning: "Los compradores de artesanía valoran el origen y quién la hizo.",
      suggestedAction: "Anota una frase corta sobre el origen de cada pieza."
    )
  ]

  private var adviceOfTheDay: FallbackAdvice {
    let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1
    return Self.consejos[dayOfYear % Self.consejos.count]
  }

  var body: some View {
    ConsejeroCardContent(
      icon: adviceOfTheDay.icon,
      mainAdvice: adviceOfTheDay.mainAdvice,
      reasoning: adviceOfTheDay.reasoning,
      suggestedAction: adviceOfTheDay.suggestedAction,
      isLoading: false
    )
  }
}

private struct FallbackAdvice {
  let icon: String
  let mainAdvice: String
  let reasoning: String
  let suggestedAction: String
}

struct ConsejeroCardContent: View {
  let icon: String
  let mainAdvice: String
  let reasoning: String
  let suggestedAction: String
  let isLoading: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {

      // — Header pill
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.caption.weight(.bold))
          .foregroundStyle(Color.tlaneGreen)
        Text("Consejo del día")
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color.tlaneGreen)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(Color.tlaneGreen.opacity(0.12), in: Capsule())
      .padding(.bottom, 14)

      if isLoading {
        HStack(spacing: 10) {
          ProgressView()
            .tint(Color.tlaneGreen)
          Text("Pensando…")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
      } else {
        // — Consejo principal
        Text(mainAdvice)
          .font(.system(.title3, design: .rounded, weight: .bold))
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.bottom, 10)

        // — Razón
        Text(reasoning)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.bottom, 14)

        // — Acción sugerida
        HStack(alignment: .top, spacing: 10) {
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.tlaneGreen)
            .frame(width: 3)
            .frame(maxHeight: .infinity)

          Text(suggestedAction)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(10)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(in: RoundedRectangle(cornerRadius: 20))
  }
}

#Preview {
  FallbackConsejeroCardView()
    .padding()
    .background(Color.tlaneBackground)
}
