import SwiftUI

struct FloatingBottomSheet<SheetContent: View>: ViewModifier {
  @Binding var isPresented: Bool
  let sheetContent: () -> SheetContent

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: $isPresented) {
        sheetContent()
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.visible)
          .presentationBackground(.ultraThinMaterial)
          .presentationCornerRadius(20)
      }
  }
}

extension View {
  func floatingBottomSheet<Content: View>(
    isPresented: Binding<Bool>,
    @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    modifier(FloatingBottomSheet(isPresented: isPresented, sheetContent: content))
  }
}
