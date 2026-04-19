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

    // Animaciones
    @State private var rowsVisible = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.tlaneBackground, Color.tlaneGreen.opacity(0.04)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            if let viewModel {
                content(vm: viewModel)
            } else {
                ProgressView().tint(Color.tlaneGreen)
            }
        }
        .navigationTitle("Inventario")
        .onAppear {
            if viewModel == nil {
                viewModel = CaptureViewModel(context: context)
            }
            animarEntrada()
        }
    }

    // MARK: - Contenido

    @ViewBuilder
    private func content(vm: CaptureViewModel) -> some View {
        if products.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    // Header resumen
                    resumenHeader

                    ForEach(Array(products.enumerated()), id: \.element.id) { i, product in
                        productRow(product: product)
                            .opacity(rowsVisible ? 1 : 0)
                            .offset(y: rowsVisible ? 0 : 20)
                            .animation(
                                .spring(response: 0.48, dampingFraction: 0.78)
                                    .delay(Double(i) * 0.055),
                                value: rowsVisible
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Header resumen

    private var resumenHeader: some View {
        HStack(spacing: 12) {
            statPill(
                icon: "shippingbox.fill",
                valor: "\(products.count)",
                label: "piezas"
            )
            statPill(
                icon: "exclamationmark.triangle.fill",
                valor: "\(productosBajoStock)",
                label: "bajo stock",
                alerta: productosBajoStock > 0
            )
        }
        .padding(.bottom, 4)
        .opacity(rowsVisible ? 1 : 0)
        .animation(.spring(response: 0.5).delay(0.05), value: rowsVisible)
    }

    private func statPill(
        icon: String,
        valor: String,
        label: String,
        alerta: Bool = false
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(alerta ? .orange : Color.tlaneGreen)
            Text(valor)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(alerta ? .orange : .primary)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
    }

    private var productosBajoStock: Int {
        products.filter { product in
            let ratio = Double(product.currentStock) / Double(max(product.initialStock, 1))
            return ratio <= 0.25
        }.count
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.tlaneGreen.opacity(0.08))
                    .frame(width: 100, height: 100)
                Image(systemName: "tray")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.tlaneGreen.opacity(0.5))
                    .symbolEffect(.pulse)
            }

            Text("Sin piezas en inventario")
                .font(.title3.weight(.bold))

            Text("Agrega productos desde la pestaña Inventario para empezar a cobrar.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Product row

    private func productRow(product: Product) -> some View {
        let ratio = Double(product.currentStock) / Double(max(product.initialStock, 1))

        return HStack(spacing: 14) {

            // Imagen / ícono
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.tlaneGreen.opacity(0.08))
                    .frame(width: 70, height: 70)

                if let data = product.imageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Image(systemName: categoryIcon(product.category))
                        .font(.system(size: 26))
                        .foregroundStyle(Color.tlaneGreen)
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                // Badge de alerta si stock muy bajo
                if ratio <= 0.25 {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                        .background(
                            Circle().fill(Color(.systemBackground)).padding(-2)
                        )
                        .offset(x: 4, y: 4)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 5) {
                Text(product.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .lineLimit(2)

                Text(product.price.formatted(.currency(code: "MXN")))
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.tlaneGreen)

                // Barra de stock
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(stockColor(product))
                            .frame(width: geo.size.width * ratio)
                    }
                }
                .frame(height: 4)
                .animation(.spring(response: 0.5), value: product.currentStock)
            }

            Spacer()

            // Stock numérico fracción
            VStack(alignment: .center, spacing: 2) {
                Text("\(product.currentStock)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(stockColor(product))
                    .contentTransition(.numericText())
                    .animation(.spring(), value: product.currentStock)

                Rectangle()
                    .frame(width: 22, height: 1.5)
                    .foregroundStyle(Color(.systemGray4))

                Text("\(product.initialStock)")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Helpers

    private func stockColor(_ product: Product) -> Color {
        let ratio = Double(product.currentStock) / Double(max(product.initialStock, 1))
        if ratio <= 0.25 { return .red }
        if ratio <= 0.5  { return .orange }
        return Color.tlaneGreen
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "textil":  "tshirt.fill"
        case "barro":   "cup.and.saucer.fill"
        case "madera":  "tree.fill"
        case "joyería": "sparkles"
        default:        "cube.fill"
        }
    }

    private func animarEntrada() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation { rowsVisible = true }
        }
    }
}

#Preview {
    NavigationStack { CaptureView() }
        .modelContainer(AppContainer.preview)
}
