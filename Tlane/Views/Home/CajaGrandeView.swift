import SwiftUI
import SwiftData

// MARK: - Modelo de ingreso diario

struct IngresoDelDia: Identifiable {
    let id = UUID()
    let fecha: Date
    let total: Decimal
}

// MARK: - ViewModel

@Observable
class CajaGrandeViewModel {
    var ingresosPorDia: [IngresoDelDia] = []
    var totalCajaGrande: Decimal = 0

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        cargarDatos()
    }

    func cargarDatos() {
        let descriptor = FetchDescriptor<Sale>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let ventas = try? context.fetch(descriptor) else { return }

        let calendar = Calendar.current
        var grouped: [Date: Decimal] = [:]

        for venta in ventas {
            let inicio = calendar.startOfDay(for: venta.date)
            grouped[inicio, default: 0] += venta.amount
        }

        ingresosPorDia = grouped
            .map { IngresoDelDia(fecha: $0.key, total: $0.value) }
            .sorted { $0.fecha > $1.fecha }

        totalCajaGrande = ventas.reduce(Decimal(0)) { $0 + $1.amount }
    }
}

// MARK: - Vista principal

struct CajaGrandeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CajaGrandeViewModel?

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if let vm = viewModel {
                    ScrollView {
                        VStack(spacing: 20) {
                            resumenCard(vm: vm)
                            historialSection(vm: vm)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .padding(.bottom, 32)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Caja Grande")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = CajaGrandeViewModel(context: context)
                }
            }
        }
    }

    // MARK: - Card de resumen total

    private func resumenCard(vm: CajaGrandeViewModel) -> some View {
        VStack(spacing: 0) {
            // Encabezado
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.tlaneGreen.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "building.columns.fill")
                        .font(.title3)
                        .foregroundStyle(Color.tlaneGreen)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total acumulado")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Caja Grande")
                        .font(.headline.weight(.semibold))
                }
                Spacer()
            }
            .padding(20)

            Divider().padding(.horizontal, 20)

            // Monto total
            VStack(spacing: 6) {
                Text(vm.totalCajaGrande.formatted(.currency(code: "MXN")))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.tlaneGreen)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("\(vm.ingresosPorDia.count) días con ingresos registrados")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)

            // Métricas secundarias
            if !vm.ingresosPorDia.isEmpty {
                Divider().padding(.horizontal, 20)

                HStack(spacing: 0) {
                    metricaMini(
                        titulo: "Mejor día",
                        valor: vm.ingresosPorDia.max(by: { $0.total < $1.total })?.total ?? 0
                    )
                    Divider().frame(height: 40)
                    metricaMini(
                        titulo: "Promedio diario",
                        valor: vm.ingresosPorDia.isEmpty ? 0 :
                            vm.totalCajaGrande / Decimal(vm.ingresosPorDia.count)
                    )
                    Divider().frame(height: 40)
                    metricaMini(
                        titulo: "Hoy",
                        valor: vm.ingresosPorDia.first(where: {
                            calendar.isDateInToday($0.fecha)
                        })?.total ?? 0
                    )
                }
                .padding(.vertical, 16)
            }
        }
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 20))
    }

    private func metricaMini(titulo: String, valor: Decimal) -> some View {
        VStack(spacing: 4) {
            Text(valor.formatted(.currency(code: "MXN")))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(titulo)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Historial por día

    private func historialSection(vm: CajaGrandeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Historial diario")
                .font(.headline)
                .padding(.horizontal, 4)

            if vm.ingresosPorDia.isEmpty {
                emptyState
            } else {
                let porMes = agruparPorMes(vm.ingresosPorDia)

                VStack(spacing: 0) {
                    ForEach(porMes, id: \.mes) { grupo in
                        HStack {
                            Text(grupo.mes)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Spacer()
                            Text(grupo.total.formatted(.currency(code: "MXN")))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.tlaneGreen)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 8)

                        VStack(spacing: 0) {
                            ForEach(Array(grupo.dias.enumerated()), id: \.element.id) { index, ingreso in
                                filaDia(ingreso: ingreso,
                                        esUltima: index == grupo.dias.count - 1,
                                        totalGeneral: vm.totalCajaGrande)
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    private func filaDia(ingreso: IngresoDelDia, esUltima: Bool, totalGeneral: Decimal) -> some View {
        // Convierte a CGFloat solo aquí donde SwiftUI lo necesita
        let porcentaje: CGFloat = totalGeneral > 0
            ? CGFloat(truncating: (ingreso.total / totalGeneral) as NSDecimalNumber)
            : 0

        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Día
                VStack(spacing: 2) {
                    Text(diaSemana(ingreso.fecha))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.tlaneGreen)
                    Text(numeroDia(ingreso.fecha))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 40)

                // Barra de progreso + fecha
                VStack(alignment: .leading, spacing: 5) {
                    Text(fechaLarga(ingreso.fecha))
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.tlaneGreen)
                                .frame(width: geo.size.width * porcentaje, height: 5)
                        }
                    }
                    .frame(height: 5)
                }

                Spacer()

                // Monto
                Text(ingreso.total.formatted(.currency(code: "MXN")))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !esUltima {
                Divider().padding(.leading, 70)
            }
        }
    }

    // MARK: - Estado vacío

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color(.systemGray4))
            Text("Sin ingresos registrados")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Los cobros que realices aparecerán aquí agrupados por día.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers de fecha

    private func diaSemana(_ fecha: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.locale = Locale(identifier: "es_MX")
        return f.string(from: fecha).capitalized
    }

    private func numeroDia(_ fecha: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: fecha)
    }

    private func fechaLarga(_ fecha: Date) -> String {
        if calendar.isDateInToday(fecha) { return "Hoy" }
        if calendar.isDateInYesterday(fecha) { return "Ayer" }
        let f = DateFormatter()
        f.dateFormat = "EEEE d 'de' MMMM"
        f.locale = Locale(identifier: "es_MX")
        return f.string(from: fecha).capitalized
    }

    // MARK: - Agrupación por mes

    struct GrupoMes {
        let mes: String
        let dias: [IngresoDelDia]
        var total: Decimal { dias.reduce(Decimal(0)) { $0 + $1.total } }
    }

    private func agruparPorMes(_ ingresos: [IngresoDelDia]) -> [GrupoMes] {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "es_MX")

        var dict: [String: [IngresoDelDia]] = [:]
        var orden: [String] = []

        for ingreso in ingresos {
            let clave = f.string(from: ingreso.fecha).capitalized
            if dict[clave] == nil {
                orden.append(clave)
                dict[clave] = []
            }
            dict[clave]!.append(ingreso)
        }

        return orden.map { GrupoMes(mes: $0, dias: dict[$0]!) }
    }
}

#Preview {
    CajaGrandeView()
        .modelContainer(AppContainer.preview)
}
