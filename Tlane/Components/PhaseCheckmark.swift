import SwiftUI

/// Checkmark animado que se dibuja al completarse una fase.
struct PhaseCheckmark: View {
  @State private var trim: CGFloat = 0

  var body: some View {
    Image(systemName: "checkmark.circle.fill")
      .resizable()
      .scaledToFit()
      .foregroundStyle(.white, Color.tlaneGreen)
      .scaleEffect(trim)
      .onAppear {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
          trim = 1
        }
      }
  }
}

#Preview {
  PhaseCheckmark()
    .frame(width: 100, height: 100)
}
