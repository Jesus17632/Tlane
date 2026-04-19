import SwiftUI
import SwiftData

struct CaptureView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel: CaptureViewModel?

    @Query(
        filter: #Predicate<Product> { $0.currentStock > 0 },
        sort: \Product.createdAt,
        order: .reverse
    ) private var products: [Product]

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
        .onAppear {
            if viewModel == nil {
                viewModel = CaptureViewModel(context: context)
            }
        }
    }

    @ViewBuilder
    private func content(vm: CaptureViewModel) -> some View {
        if products.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(products) { product in
                        productRow(product: product)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
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

    // MARK: - Product row

    private func productRow(product: Product) -> some View {
        HStack(spacing: 14) {

            // Imagen
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.tlaneEarth.opacity(0.15))
                if let data = product.imageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: categoryIcon(product.category))
                        .font(.system(size: 26))
                        .foregroundStyle(Color.tlaneEarth)
                }
            }
            .frame(width: 70, height: 70)
            .clipped()

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .lineLimit(2)

                Text(product.price.formatted(.currency(code: "MXN")))
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.tlaneGreen)
            }

            Spacer()

            // Unidades (fracción)
            VStack(alignment: .center, spacing: 2) {
                Text("\(product.currentStock)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(stockColor(product))
                Rectangle()
                    .frame(width: 22, height: 1.5)
                    .foregroundStyle(.secondary.opacity(0.5))
                Text("\(product.initialStock)")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: RoundedRectangle(cornerRadius: 18))
    }

    private func stockColor(_ product: Product) -> Color {
        let ratio = Double(product.currentStock) / Double(max(product.initialStock, 1))
        if ratio <= 0.25 { return .red }
        if ratio <= 0.5  { return .orange }
        return .primary
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
        CaptureView()
    }
    .modelContainer(AppContainer.preview)
}
