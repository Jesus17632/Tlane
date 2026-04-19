import SwiftUI

enum TapToPayPhase: Int, CaseIterable {
  case waiting    // "Acerca la tarjeta..."
  case processing // "Procesando..."
  case success    // "¡Cobro exitoso!"
}

/// Vista que simula el flujo de Tap to Pay con PhaseAnimator.
/// Al completarse, invoca onSuccess para que la capa superior
/// persista la venta en SwiftData.
///
/// TODO: Reemplazar con ProximityReader al obtener permisos
/// comerciales de Apple para Tap to Pay on iPhone.
struct TapToPayMockView: View {
  let amount: Decimal
  let onSuccess: () -> Void
  let onCancel: () -> Void

  @State private var triggerAnimation = false
  @State private var hasCompleted = false

  var body: some View {
    VStack(spacing: 32) {
      Text(amount.formatted(.currency(code: "MXN")))
        .font(.system(size: 48, weight: .bold, design: .rounded))
        .foregroundStyle(Color.tlaneGreen)

      PhaseAnimator(TapToPayPhase.allCases, trigger: triggerAnimation) { phase in
        phaseView(phase)
      } animation: { phase in
        switch phase {
        case .waiting:    .easeInOut(duration: 1.5)
        case .processing: .easeInOut(duration: 1.2)
        case .success:    .spring(response: 0.5, dampingFraction: 0.7)
        }
      }
      .frame(height: 220)

      if !hasCompleted {
        Button("Cancelar", role: .cancel, action: onCancel)
          .buttonStyle(.bordered)
      }
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      triggerAnimation.toggle()
      scheduleCompletion()
    }
  }

  @ViewBuilder
  private func phaseView(_ phase: TapToPayPhase) -> some View {
    switch phase {
    case .waiting:
      VStack(spacing: 20) {
        Image(systemName: "wave.3.right.circle.fill")
          .resizable()
          .scaledToFit()
          .frame(width: 100, height: 100)
          .foregroundStyle(Color.tlaneEarth)
          .symbolEffect(.pulse, options: .repeating)
        Text("Acerca la tarjeta…")
          .font(.title3.weight(.medium))
          .foregroundStyle(.secondary)
      }

    case .processing:
      VStack(spacing: 20) {
        ProgressView()
          .scaleEffect(2)
          .tint(.tlaneEarth)
          .frame(width: 100, height: 100)
        Text("Procesando…")
          .font(.title3.weight(.medium))
          .foregroundStyle(.secondary)
      }

    case .success:
      VStack(spacing: 20) {
        PhaseCheckmark()
          .frame(width: 100, height: 100)
        Text("¡Cobro exitoso!")
          .font(.title2.weight(.bold))
          .foregroundStyle(Color.tlaneGreen)
      }
    }
  }

  /// Programamos la finalización para que coincida con el final
  /// de la tercera fase. PhaseAnimator no expone un callback
  /// directo de "terminé la última fase", así que usamos timing.
  private func scheduleCompletion() {
    // waiting 1.5 + processing 1.2 + pequeño buffer para que se vea el success
    let totalDuration: TimeInterval = 1.5 + 1.2 + 1.2
    DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
      guard !hasCompleted else { return }
      hasCompleted = true
      onSuccess()
    }
  }
}

#Preview {
  TapToPayMockView(
    amount: 850,
    onSuccess: { print("success") },
    onCancel:  { print("cancel") }
  )
}
