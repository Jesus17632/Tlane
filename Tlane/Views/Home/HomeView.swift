import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @State private var insightsVM = InsightsViewModel()
// MARK: - @Query reactivos (reemplazan HomeViewModel)

  @Query private var todaysSales: [Sale]
  @Query(sort: \Sale.date, order: .reverse) private var allSales: [Sale]

  init() {
    let start = Calendar.current.startOfDay(for: .now)
    _todaysSales = Query(
      filter: #Predicate<Sale> { $0.date >= start },
      sort: [SortDescriptor(\Sale.date, order: .reverse)]
    )
  }

  // MARK: - Derivados computados (re-evaluados en cada render del body)

  private var cajaChica: Decimal {
    todaysSales.reduce(Decimal(0)) { $0 + $1.amount }
  }

  private var ultimasVentas: [Sale] {
    todaysSales // ya ordenado por @Query
  }

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
  @State private var mostrarChatBot = false
  @State private var mostrarPagar = false
  @State private var mostrarCobrar = false
  @State private var mostrarCajaGrande = false

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      ScrollView {
        VStack(spacing: 10) {
          cajaChicaSection
          botonesSection
          ultimasVentasSection
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .padding(.bottom, 90)
      }
      .background(Color.tlaneBackground)

      if mostrarChatBot {
        chatBotPopup
      }

      chatBotButton
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        NavigationLink(destination: CajaView()) {
          Image(systemName: "person.circle.fill")
            .font(.title2)
            .foregroundStyle(Color.tlaneGreen)
        }
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
        Text("Caja Chica")
          .font(.largeTitle.weight(.bold))
          .foregroundStyle(.primary)
        Text("Hoy")
          .font(.caption)
          .foregroundStyle(.tertiary)
        Text(cajaChica.formatted(.currency(code: "MXN")))
          .font(.largeTitle.weight(.bold))
          .foregroundStyle(Color.tlaneGreen)
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
      .tint(Color.blue)
      .cornerRadius(16)

      Button { mostrarCobrar = true } label: {
        VStack(spacing: 2) {
          Image(systemName: "arrow.down")
            .font(.title3.weight(.bold))
          Text("Cobrar")
            .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(width: 70, height: 55)
        .background(Color.green)
        .cornerRadius(50)
      }

      Button { mostrarPagar = true } label: {
        VStack(spacing: 3) {
          Image(systemName: "arrow.up")
            .font(.title3.weight(.bold))
          Text("Pagar")
            .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(width: 70, height: 55)
        .background(Color.red)
        .cornerRadius(50)
      }
    }
  }

  // MARK: - Historial
  private var ultimasVentasSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Historial")
        .font(.headline)

      if ultimasVentas.isEmpty {
        emptyVentasRow
      } else {
        VStack(spacing: 8) {
          let visibles = mostrarTodasVentas
            ? ultimasVentas
            : Array(ultimasVentas.prefix(3))

          ForEach(visibles) { sale in
            ventaRow(sale: sale)
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
              .foregroundStyle(Color.tlaneGreen)
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
        .foregroundStyle(.secondary)
      Text("Aún no hay ventas hoy.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Spacer()
    }
    .padding(16)
    .frame(maxWidth: .infinity)
    .glassEffect(in: RoundedRectangle(cornerRadius: 16))
  }

  private func ventaRow(sale: Sale) -> some View {
    let esCobro = sale.amount > 0
    let color: Color = esCobro ? Color.tlaneGreen : .red

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
            .lineLimit(1)
        } else {
          Text(sale.paymentMethod.rawValue)
            .font(.subheadline.weight(.medium))
        }
        Text(sale.paymentMethod.rawValue)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
          Text((esCobro ? "+" : "-") + abs(sale.amount).formatted(.currency(code: "MXN")))
          .font(.body.weight(.bold))
          .foregroundStyle(color)
        Text(sale.date.formatted(date: .omitted, time: .shortened))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
  }

  // MARK: - ChatBot

  private var chatBotPopup: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Image(systemName: "bubble.left.and.bubble.right.fill")
          .foregroundStyle(Color.tlaneGreen)
        Text("Asistente")
          .font(.headline)
        Spacer()
        Button {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            mostrarChatBot = false
          }
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
            .font(.title3)
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 10)

      Divider()

    ConsejeroCardView(viewModel: insightsVM)
        .padding(12)
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8)
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
          .fill(Color.tlaneGreen)
          .frame(width: 60, height: 60)
          .shadow(color: Color.tlaneGreen.opacity(0.4), radius: 12, x: 0, y: 6)
        Image(systemName: mostrarChatBot ? "xmark" : "bubble.left.and.bubble.right.fill")
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
