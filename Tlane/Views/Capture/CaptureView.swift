import SwiftUI
import SwiftData

struct CaptureView: View {
  @Environment(\.modelContext) private var context
  @State private var viewModel: CaptureViewModel?

  private let columns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12)
  ]

    var body: some View {
      ZStack {
        Color.tlaneBackground.ignoresSafeArea()

        if let viewModel {
          content(vm: viewModel)
        } else {
          ProgressView()
        }
      }
      .navigationTitle("Cobrar")
      .onAppear {
        if viewModel == nil {
          viewModel = CaptureViewModel(context: context)
        }
      }
    }

  @ViewBuilder
  private func content(vm: CaptureViewModel) -> some View {
    let products = vm.availableProducts

    if products.isEmpty {
      emptyState
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("Tappea una pieza para cobrar")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal)

          LazyVGrid(columns: columns, spacing: 12) {
            ForEach(products) { product in
              productCard(product: product)
                .onTapGesture { vm.selectProduct(product) }
            }
          }
          .padding(.horizontal)
          .padding(.bottom, 32)
        }
        .padding(.top, 8)
      }
      .floatingBottomSheet(isPresented: Binding(
        get: { vm.isShowingPaymentSheet },
        set: { vm.isShowingPaymentSheet = $0 }
      )) {
        paymentMethodSheet(vm: vm)
      }
      .fullScreenCover(isPresented: Binding(
        get: { vm.isShowingTapToPay },
        set: { vm.isShowingTapToPay = $0 }
      )) {
        if let product = vm.selectedProduct {
          TapToPayMockView(
            amount: product.price,
            onSuccess: { vm.completeTapToPay() },
            onCancel:  { vm.cancelTapToPay() }
          )
          .background(Color.tlaneBackground)
        }
      }
    }
  }

  // MARK: - Empty state

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "tray")
        .font(.system(size: 64))
        .foregroundStyle(.secondary)
      Text("No hay piezas en inventario")
        .font(.headline)
      Text("Agrega productos desde la pestaña Inventario para empezar a cobrar.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
  }

  // MARK: - Product card

  private func productCard(product: Product) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 14)
          .fill(Color.tlaneEarth.opacity(0.15))
        if let data = product.imageData,
           let uiImage = UIImage(data: data) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
          Image(systemName: categoryIcon(product.category))
            .font(.system(size: 40))
            .foregroundStyle(Color.tlaneEarth)
        }
      }
      .aspectRatio(1, contentMode: .fit)

      VStack(alignment: .leading, spacing: 2) {
        Text(product.name)
          .font(.subheadline.weight(.semibold))
          .lineLimit(2)
        Text(product.price.formatted(.currency(code: "MXN")))
          .font(.headline)
          .foregroundStyle(Color.tlaneGreen)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(in: RoundedRectangle(cornerRadius: 18))
  }

  private func categoryIcon(_ category: String) -> String {
    switch category {
    case "textil":  "scissors"
    case "barro":   "cup.and.saucer.fill"
    case "madera":  "tree.fill"
    case "joyería": "sparkle"
    default:        "cube.fill"
    }
  }

  // MARK: - Payment method sheet

  private func paymentMethodSheet(vm: CaptureViewModel) -> some View {
    VStack(spacing: 24) {
      if let product = vm.selectedProduct {
        VStack(spacing: 4) {
          Text(product.name)
            .font(.headline)
          Text(product.price.formatted(.currency(code: "MXN")))
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(Color.tlaneGreen)
        }
        .padding(.top, 16)
      }

      Text("¿Cómo va a pagar?")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      VStack(spacing: 12) {
        paymentButton(
          title: "Efectivo",
          systemImage: "banknote",
          color: .tlaneEarth,
          action: { vm.registerCashSale() }
        )
        paymentButton(
          title: "Tap to Pay",
          systemImage: "wave.3.right.circle.fill",
          color: .tlaneGreen,
          action: { vm.startTapToPay() }
        )
      }
      .padding(.horizontal, 20)

      Spacer()
    }
    .padding(.vertical, 20)
  }

  private func paymentButton(
    title: String,
    systemImage: String,
    color: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: systemImage)
          .font(.title2)
        Text(title)
          .font(.title3.weight(.semibold))
        Spacer()
        Image(systemName: "chevron.right")
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.7))
      }
      .padding()
      .frame(maxWidth: .infinity)
      .background(color)
      .foregroundStyle(.white)
      .clipShape(RoundedRectangle(cornerRadius: 16))
    }
  }
}

#Preview {
  NavigationStack {
    CaptureView()
  }
  .modelContainer(AppContainer.preview)
}
