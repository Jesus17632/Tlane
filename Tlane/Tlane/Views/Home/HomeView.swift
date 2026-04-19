import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @State private var insightsVM = InsightsViewModel()

    private let verde = Color(red: 0.18, green: 0.47, blue: 0.20)
    private let arena = Color(red: 0.84, green: 0.76, blue: 0.63)
    private let arenaOscuro = Color(red: 0.72, green: 0.62, blue: 0.48)
    private let fondo = Color(red: 0.97, green: 0.96, blue: 0.95)
    private let oscuro = Color(red: 0.18, green: 0.18, blue: 0.18)
    private let rojo = Color(red: 0.75, green: 0.25, blue: 0.20)

    // MARK: - Animaciones
    @State private var animarCaja      = false
    @State private var animarBotones   = false
    @State private var animarHistorial = false

    // MARK: - @Query reactivos
    @Query private var todaysSales: [Sale]
    @Query(sort: \Sale.date, order: .reverse) private var allSales: [Sale]

    init() {
        let start = Calendar.current.startOfDay(for: .now)
        _todaysSales = Query(
            filter: #Predicate<Sale> { $0.date >= start },
            sort: [SortDescriptor(\Sale.date, order: .reverse)]
        )
    }

    // MARK: - Derivados computados
    private var cajaChica: Decimal {
        todaysSales.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var ultimasVentas: [Sale] { todaysSales }

    private var salesSummaryForAdvisor: String {
        let total = cajaChica.formatted(.currency(code: "MXN"))
        let count = todaysSales.count
        let byCategory = Dictionary(grouping: todaysSales.flatMap(\.items), by: \.productName)
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { "\($0.key) (\($0.value))" }
            .joined(separator: ", ")
        return """
        Ventas de hoy: \(count) operaciones, total \(total).
        Productos más vendidos: \(byCategory.isEmpty ? "ninguno aún" : byCategory).
        """
    }

    // MARK: - Estado local UI
    @State private var mostrarTodasVentas = false
    @State private var mostrarChatBot     = false
    @State private var mostrarPagar       = false
    @State private var mostrarCobrar      = false
    @State private var mostrarCajaGrande  = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            fondo.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    cajaChicaSection
                        .opacity(animarCaja ? 1 : 0)
                        .offset(y: animarCaja ? 0 : 20)

                    botonesSection
                        .opacity(animarBotones ? 1 : 0)
                        .offset(y: animarBotones ? 0 : 20)

                    ultimasVentasSection
                        .opacity(animarHistorial ? 1 : 0)
                        .offset(y: animarHistorial ? 0 : 20)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .padding(.bottom, 90)
            }

            if mostrarChatBot { chatBotPopup }
            chatBotButton
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: CajaView()) {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundStyle(oscuro)
                        .padding(8)
                        .glassEffect(in: Circle())
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                animarCaja = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25)) {
                animarBotones = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4)) {
                animarHistorial = true
            }
        }
        .sheet(isPresented: $mostrarCajaGrande) { CajaGrandeView() }
        .sheet(isPresented: $mostrarCobrar) {
            CobrarSheetView(onVentaRegistrada: { _, _ in })
        }
        .sheet(isPresented: $mostrarPagar) { PagarSheetView() }
    }

    // MARK: - Caja Chica
    private var cajaChicaSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Caja")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(oscuro)
                Text("Hoy:")
                    .font(.caption)
                    .foregroundStyle(oscuro)
                Text(cajaChica.formatted(.currency(code: "MXN")))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(verde)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.easeInOut, value: cajaChica)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Botones
    private var botonesSection: some View {
        HStack(alignment: .center, spacing: 7) {

            // Caja Grande
            Button { mostrarCajaGrande = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2.weight(.semibold))
                    Text("Caja Grande")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .tint(arenaOscuro)
            .cornerRadius(16)

            // Cobrar
            Button { mostrarCobrar = true } label: {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.title3.weight(.bold))
                    Text("Cobrar")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(width: 70, height: 55)
                .background(verde)
                .cornerRadius(50)
            }
            .scaleEffect(animarBotones ? 1 : 0.8)
            .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.3), value: animarBotones)

            // Pagar
            Button { mostrarPagar = true } label: {
                VStack(spacing: 3) {
                    Image(systemName: "arrow.up")
                        .font(.title3.weight(.bold))
                    Text("Pagar")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(width: 70, height: 55)
                .background(rojo)
                .cornerRadius(50)
            }
            .scaleEffect(animarBotones ? 1 : 0.8)
            .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.4), value: animarBotones)
        }
    }

    // MARK: - Historial
    private var ultimasVentasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Historial")
                .font(.headline)
                .foregroundStyle(oscuro)

            if ultimasVentas.isEmpty {
                emptyVentasRow
            } else {
                VStack(spacing: 8) {
                    let visibles = mostrarTodasVentas
                        ? ultimasVentas
                        : Array(ultimasVentas.prefix(3))

                    ForEach(Array(visibles.enumerated()), id: \.element.id) { index, sale in
                        ventaRow(sale: sale)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal:   .move(edge: .leading).combined(with: .opacity)
                            ))
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.06),
                                value: animarHistorial
                            )
                    }

                    if ultimasVentas.count > 3 {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                mostrarTodasVentas.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(mostrarTodasVentas ? "Ver menos" : "Ver más")
                                    .font(.subheadline.weight(.medium))
                                Image(systemName: mostrarTodasVentas ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(verde)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private var emptyVentasRow: some View {
        HStack {
            Image(systemName: "tray")
                .foregroundStyle(arena)
            Text("Aún no hay ventas hoy.")
                .font(.subheadline)
                .foregroundStyle(oscuro.opacity(0.5))
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(arena.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
    }

    private func ventaRow(sale: Sale) -> some View {
        let esCobro = sale.amount > 0
        let color: Color = esCobro ? verde : rojo

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: esCobro
                      ? sale.paymentMethod.systemImage
                      : "arrow.up.circle.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                if !sale.items.isEmpty {
                    Text(sale.items.map { $0.productName }.joined(separator: ", "))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(oscuro)
                        .lineLimit(1)
                } else {
                    Text(sale.paymentMethod.rawValue)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(oscuro)
                }
                Text(sale.paymentMethod.rawValue)
                    .font(.caption)
                    .foregroundStyle(oscuro.opacity(0.45))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text((esCobro ? "+" : "-") + abs(sale.amount).formatted(.currency(code: "MXN")))
                    .font(.body.weight(.bold))
                    .foregroundStyle(color)
                Text(sale.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(oscuro.opacity(0.45))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(arena.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - ChatBot
    private var chatBotPopup: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(verde)
                Text("Asistente")
                    .font(.headline)
                    .foregroundStyle(oscuro)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        mostrarChatBot = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(arena)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().overlay(arena.opacity(0.4))

            ConsejeroCardView(viewModel: insightsVM)
                .padding(12)
        }
        .background(fondo, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(arena.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: oscuro.opacity(0.12), radius: 20, x: 0, y: 8)
        .frame(width: 300)
        .padding(.trailing, 20)
        .padding(.bottom, 94)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity),
            removal:   .scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity)
        ))
    }

    private var chatBotButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                mostrarChatBot.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(verde)
                    .frame(width: 60, height: 60)
                    .shadow(color: verde.opacity(0.4), radius: 12, x: 0, y: 6)
                Image(systemName: mostrarChatBot
                      ? "xmark"
                      : "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .animation(.spring(response: 0.3), value: mostrarChatBot)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(AppContainer.preview)
}
