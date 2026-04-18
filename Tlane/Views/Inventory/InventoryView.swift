import SwiftUI
import SwiftData

struct InventoryView: View {
  @Environment(\.modelContext) private var context
  @State private var viewModel: InventoryViewModel?

    var body: some View {
      ZStack {
        Color.tlaneBackground.ignoresSafeArea()

        if let viewModel {
          content(vm: viewModel)
        } else {
          ProgressView()
        }
      }
      .navigationTitle("Inventario")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button {
            viewModel?.isShowingAddProduct = true
          } label: {
            Image(systemName: "plus")
              .font(.headline)
          }
        }
      }
      .onAppear {
        if viewModel == nil {
          viewModel = InventoryViewModel(context: context)
        }
      }
    }

  @ViewBuilder
  private func content(vm: InventoryViewModel) -> some View {
    ScrollView {
      VStack(spacing: 16) {
        statsHeader(vm: vm)

        if vm.products.isEmpty {
          emptyState
        } else {
          productList(vm: vm)
        }
      }
      .padding()
    }
    .sheet(isPresented: Binding(
      get: { vm.isShowingAddProduct },
      set: { vm.isShowingAddProduct = $0 }
    )) {
        AddProductView { name, category, price, imageData in
          vm.addProduct(
            name: name,
            category: category,
            price: price,
            imageData: imageData
          )
        }
    }
  }

  // MARK: - Stats header

  private func statsHeader(vm: InventoryViewModel) -> some View {
    HStack(spacing: 10) {
      statCard(titulo: "Disponibles", valor: "\(vm.availableCount)", color: .tlaneGreen)
      statCard(titulo: "Vendidas",    valor: "\(vm.soldCount)",      color: .tlaneEarth)
      statCard(
        titulo: "Valor stock",
        valor: vm.totalStockValue.formatted(.currency(code: "MXN").precision(.fractionLength(0))),
        color: .tlaneGreen
      )
    }
  }

  private func statCard(titulo: String, valor: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(titulo)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(valor)
        .font(.title3.weight(.bold))
        .foregroundStyle(color)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
  }

  // MARK: - Empty state

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "square.grid.2x2")
        .font(.system(size: 56))
        .foregroundStyle(.secondary)
      Text("Aún no tienes piezas")
        .font(.headline)
      Text("Tappea + arriba a la derecha para agregar tu primera pieza.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
    }
    .padding(.top, 60)
  }

  // MARK: - Product list

  private func productList(vm: InventoryViewModel) -> some View {
    VStack(spacing: 10) {
      ForEach(vm.products) { product in
        productRow(product: product)
          .contextMenu {
            Button("Eliminar", systemImage: "trash", role: .destructive) {
              vm.delete(product: product)
            }
          }
      }
    }
  }

  private func productRow(product: Product) -> some View {
    HStack(spacing: 14) {
      thumbnail(for: product)

      VStack(alignment: .leading, spacing: 3) {
        Text(product.name)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
        Text(product.category.capitalized)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(product.price.formatted(.currency(code: "MXN")))
          .font(.subheadline.weight(.medium))
          .foregroundStyle(Color.tlaneGreen)
      }

      Spacer()

      statusBadge(for: product)
    }
    .padding(12)
    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
  }

  private func thumbnail(for product: Product) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.tlaneEarth.opacity(0.15))
      if let data = product.imageData,
         let uiImage = UIImage(data: data) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()
          .clipShape(RoundedRectangle(cornerRadius: 12))
      } else {
        Image(systemName: categoryIcon(product.category))
          .font(.title2)
          .foregroundStyle(Color.tlaneEarth)
      }
    }
    .frame(width: 56, height: 56)
  }

  private func statusBadge(for product: Product) -> some View {
    let isSold = product.isSold
    return Text(isSold ? "Vendida" : "Disponible")
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background((isSold ? Color.tlaneEarth : .tlaneGreen).opacity(0.18))
      .foregroundStyle(isSold ? Color.tlaneEarth : .tlaneGreen)
      .clipShape(Capsule())
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
}

#Preview {
  NavigationStack {
    InventoryView()
  }
  .modelContainer(AppContainer.preview)
}
