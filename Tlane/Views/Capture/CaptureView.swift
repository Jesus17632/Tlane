import SwiftUI
import SwiftData

struct InventoryView: View {
  @Environment(\.modelContext) private var context
  @State private var viewModel: InventoryViewModel?

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if let viewModel {
        content(vm: viewModel)
      } else {
        ProgressView()
          .tint(.white)
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .task {
      if viewModel == nil {
        viewModel = InventoryViewModel(context: context)
      }
      if case .requestingPermission = viewModel?.state {
        await viewModel?.requestCameraPermission()
      }
    }
  }

  @ViewBuilder
  private func content(vm: InventoryViewModel) -> some View {
    ZStack {
      CameraPreviewView(session: vm.cameraSession)
        .ignoresSafeArea()

      switch vm.state {
      case .requestingPermission:
        permissionLoader
      case .denied:
        CameraPermissionDeniedView()
      case .scanning, .detected, .saving:
        scanningOverlay(vm: vm)
      }
    }
    .floatingBottomSheet(isPresented: sheetBinding(vm: vm)) {
      if case .detected(let category, let frame) = vm.state {
        ConfirmationSheetView(
          category: category,
          frame: frame,
          viewModel: vm
        )
      }
    }
  }

  private func sheetBinding(vm: InventoryViewModel) -> Binding<Bool> {
    Binding(
      get: {
        if case .detected = vm.state { return true }
        return false
      },
      set: { newValue in
        if !newValue { vm.resetToScanning() }
      }
    )
  }

  // MARK: - Overlays

  private var permissionLoader: some View {
    VStack(spacing: 12) {
      ProgressView().tint(.white)
      Text("Solicitando acceso a la cámara…")
        .foregroundStyle(.white)
        .font(.subheadline)
    }
    .padding(20)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
  }

  private func scanningOverlay(vm: InventoryViewModel) -> some View {
    VStack {
      Text("Apunta a una pieza para identificarla")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 60)

      Spacer()

      ZStack {
        FocusFrame()
          .frame(width: 260, height: 260)

        if case .saving = vm.state {
          SuccessCheckmark()
            .frame(width: 120, height: 120)
        }
      }

      Spacer()

      if case .saving = vm.state {
        Text("¡Pieza agregada!")
          .font(.headline)
          .foregroundStyle(.white)
          .padding(.bottom, 80)
      } else if case .detected = vm.state {
        Color.clear.frame(height: 80)
      } else {
        Text("Mantén la pieza centrada en el recuadro")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.8))
          .padding(.bottom, 60)
      }
    }
  }
}

// MARK: - Focus frame con PhaseAnimator

private struct FocusFrame: View {
  var body: some View {
    PhaseAnimator([0, 1]) { phase in
      ZStack {
        ForEach(FocusCorner.allCases, id: \.self) { corner in
          CornerBracketShape(corner: corner)
            .stroke(Color.tlaneGreen, lineWidth: 4)
            .opacity(phase == 0 ? 0.7 : 1.0)
            .scaleEffect(phase == 0 ? 1.0 : 1.05)
        }
      }
    } animation: { _ in
      .easeInOut(duration: 1.2)
    }
  }
}

private enum FocusCorner: CaseIterable { case tl, tr, bl, br }

private struct CornerBracketShape: Shape {
  let corner: FocusCorner

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let len: CGFloat = 28
    switch corner {
    case .tl:
      path.move(to: CGPoint(x: 0, y: len))
      path.addLine(to: CGPoint(x: 0, y: 0))
      path.addLine(to: CGPoint(x: len, y: 0))
    case .tr:
      path.move(to: CGPoint(x: rect.width - len, y: 0))
      path.addLine(to: CGPoint(x: rect.width, y: 0))
      path.addLine(to: CGPoint(x: rect.width, y: len))
    case .bl:
      path.move(to: CGPoint(x: 0, y: rect.height - len))
      path.addLine(to: CGPoint(x: 0, y: rect.height))
      path.addLine(to: CGPoint(x: len, y: rect.height))
    case .br:
      path.move(to: CGPoint(x: rect.width - len, y: rect.height))
      path.addLine(to: CGPoint(x: rect.width, y: rect.height))
      path.addLine(to: CGPoint(x: rect.width, y: rect.height - len))
    }
    return path
  }
}

private struct SuccessCheckmark: View {
  @State private var scale: CGFloat = 0.3
  @State private var opacity: Double = 0

  var body: some View {
    Image(systemName: "checkmark.circle.fill")
      .resizable()
      .scaledToFit()
      .foregroundStyle(.white, Color.tlaneGreen)
      .scaleEffect(scale)
      .opacity(opacity)
      .onAppear {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
          scale = 1.0
          opacity = 1.0
        }
      }
  }
}

// MARK: - Permission denied

private struct CameraPermissionDeniedView: View {
  var body: some View {
    VStack(spacing: 18) {
      Image(systemName: "camera.fill.badge.ellipsis")
        .font(.system(size: 54))
        .foregroundStyle(.white)
      Text("Necesitamos acceso a la cámara")
        .font(.title3.weight(.bold))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
      Text("Tlane usa la cámara para identificar tus piezas automáticamente.")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.85))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      Button {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
      } label: {
        Label("Abrir Ajustes", systemImage: "gear")
          .font(.headline)
      }
      .buttonStyle(.borderedProminent)
      .tint(.tlaneGreen)
      .padding(.top, 6)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.opacity(0.85))
  }
}

// MARK: - Confirmation sheet

private struct ConfirmationSheetView: View {
  let category: String
  let frame: UIImage
  @Bindable var viewModel: InventoryViewModel
  @FocusState private var nameFieldFocused: Bool

  private var isValid: Bool {
    !viewModel.productName.trimmingCharacters(in: .whitespaces).isEmpty
      && viewModel.productPrice > 0
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      header

      VStack(alignment: .leading, spacing: 6) {
        Text("Nombre de la pieza")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        TextField("Ej: Huipil bordado", text: $viewModel.productName)
          .textFieldStyle(.roundedBorder)
          .focused($nameFieldFocused)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("Precio")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        TextField("Precio", value: $viewModel.productPrice,
                  format: .currency(code: "MXN"))
          .textFieldStyle(.roundedBorder)
          .keyboardType(.decimalPad)
      }

      Spacer(minLength: 4)

      HStack(spacing: 12) {
        Button("Cancelar") {
          viewModel.resetToScanning()
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)

        Button {
          viewModel.saveProduct(
            category: category,
            imageData: frame.jpegData(compressionQuality: 0.7)
          )
        } label: {
          Text("Añadir al inventario")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.tlaneGreen)
        .disabled(!isValid)
      }
    }
    .padding(20)
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        nameFieldFocused = true
      }
    }
  }

  private var header: some View {
    HStack(spacing: 14) {
      Image(uiImage: frame)
        .resizable()
        .scaledToFill()
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 12))

      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Image(systemName: "sparkles")
            .foregroundStyle(Color.tlaneGreen)
          Text("Categoría detectada")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Text(category.capitalized)
          .font(.title2.weight(.bold))
          .foregroundStyle(Color.tlaneGreen)
      }
      Spacer()
    }
  }
}

#Preview {
  NavigationStack {
    InventoryView()
  }
  .modelContainer(AppContainer.preview)
}
