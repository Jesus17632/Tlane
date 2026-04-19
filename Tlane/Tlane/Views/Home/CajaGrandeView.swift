import SwiftUI
import SwiftData

struct IngresoDelDia: Identifiable {
    let id    = UUID()
    let fecha: Date
    let total: Decimal
}

struct CajaGrandeView: View {
    @Environment(\.dismiss) private var dismiss

    // Paleta reducida: solo tlaneGreen + arenaOscuro para info MUY secundaria
    private let arenaOscuro = Color(red: 0.48, green: 0.40, blue: 0.30)

    @State private var animarResumen   = false
    @State private var animarHistorial = false

    @Query(sort: \Sale.date, order: .reverse) private var allSales: [Sale]
    private let calendar = Calendar.current

    // MARK: - Derivados

    private var totalCajaGrande: Decimal {
        allSales.reduce(.zero) { $0 + $1.amount }
    }

    private var ingresosPorDia: [IngresoDelDia] {
        var grouped: [Date: Decimal] = [:]
        for venta in allSales {
            let inicio = calendar.startOfDay(for: venta.date)
            grouped[inicio, default: 0] += venta.amount
        }
        return grouped
            .map { IngresoDelDia(fecha: $0.key, total: $0.value) }
            .sorted { $0.fecha > $1.fecha }
    }

    private var mejorDia: Decimal {
        ingresosPorDia.max(by: { $0.total < $1.total })?.total ?? .zero
    }

    private var promedioDiario: Decimal {
        ingresosPorDia.isEmpty ? .zero : totalCajaGrande / Decimal(ingresosPorDia.count)
    }

    private var hoy: Decimal {
        ingresosPorDia.first(where: { calendar.isDateInToday($0.fecha) })?.total ?? .zero
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.tlaneBackground, Color.tlaneGreen.opacity(0.05)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        resumenCard
                            .opacity(animarResumen ? 1 : 0)
                            .offset(y: animarResumen ? 0 : 24)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1),
                                       value: animarResumen)

                        historialSection
                            .opacity(animarHistorial ? 1 : 0)
                            .offset(y: animarHistorial ? 0 : 24)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25),
                                       value: animarHistorial)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Caja Grande")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(.red)
                }
            }
            .onAppear {
                withAnimation { animarResumen   = true }
                withAnimation { animarHistorial = true }
            }
        }
    }

    // MARK: - Resumen card

    private var resumenCard: some View {
        VStack(spacing: 0) {

            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.tlaneGreen.opacity(0.12))
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
                // Badge días
                Text("\(ingresosPorDia.count) días")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.tlaneGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.tlaneGreen.opacity(0.1), in: Capsule())
            }
            .padding(20)

            Divider().padding(.horizontal, 20)

            // Total grande
            VStack(spacing: 4) {
                Text(totalCajaGrande.formatted(.currency(code: "MXN")))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.tlaneGreen)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.spring(), value: totalCajaGrande)
                    .shadow(color: Color.tlaneGreen.opacity(0.2), radius: 8)

                if !ingresosPorDia.isEmpty {
                    Text("en \(ingresosPorDia.count) días con ventas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)

            // Métricas mini — solo si hay datos
            if !ingresosPorDia.isEmpty {
                Divider().padding(.horizontal, 20)

                HStack(spacing: 0) {
                    metricaMini(icon: "trophy.fill",    titulo: "Mejor día",  valor: mejorDia)
                    Divider().frame(height: 40)
                    metricaMini(icon: "chart.bar.fill", titulo: "Promedio",   valor: promedioDiario)
                    Divider().frame(height: 40)
                    metricaMini(icon: "sun.max.fill",   titulo: "Hoy",        valor: hoy)
                }
                .padding(.vertical, 16)
            }
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
    }

    private func metricaMini(icon: String, titulo: String, valor: Decimal) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(valor > 0 ? Color.tlaneGreen : .secondary)
            Text(valor.formatted(.currency(code: "MXN")))
                .font(.subheadline.weight(.semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(valor > 0 ? .primary : .secondary)
            Text(titulo)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Historial

    private var historialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Historial diario")
                    .font(.headline)
                Spacer()
                if !ingresosPorDia.isEmpty {
                    Text(totalCajaGrande.formatted(.currency(code: "MXN")))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.tlaneGreen)
                }
            }
            .padding(.horizontal, 4)

            if ingresosPorDia.isEmpty {
                emptyState
            } else {
                let porMes = agruparPorMes(ingresosPorDia)
                VStack(spacing: 14) {
                    ForEach(Array(porMes.enumerated()), id: \.element.mes) { mesIdx, grupo in
                        VStack(alignment: .leading, spacing: 0) {

                            // Cabecera del mes
                            HStack {
                                Text(grupo.mes)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(arenaOscuro)
                                    .textCase(.uppercase)
                                Spacer()
                                Text(grupo.total.formatted(.currency(code: "MXN")))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.tlaneGreen)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .opacity(animarHistorial ? 1 : 0)
                            .animation(
                                .spring(response: 0.45).delay(Double(mesIdx) * 0.07),
                                value: animarHistorial
                            )

                            // Filas del mes
                            VStack(spacing: 0) {
                                ForEach(Array(grupo.dias.enumerated()), id: \.element.id) { i, ingreso in
                                    filaDia(
                                        ingreso: ingreso,
                                        esUltima: i == grupo.dias.count - 1,
                                        totalGeneral: totalCajaGrande
                                    )
                                    .opacity(animarHistorial ? 1 : 0)
                                    .offset(x: animarHistorial ? 0 : 24)
                                    .animation(
                                        .spring(response: 0.45, dampingFraction: 0.8)
                                            .delay(Double(mesIdx) * 0.07 + Double(i) * 0.045),
                                        value: animarHistorial
                                    )
                                }
                            }
                            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
        }
    }

    private func filaDia(
        ingreso: IngresoDelDia,
        esUltima: Bool,
        totalGeneral: Decimal
    ) -> some View {
        let pct: CGFloat = totalGeneral > 0
            ? CGFloat(truncating: (ingreso.total / totalGeneral) as NSDecimalNumber)
            : 0
        let esHoy = calendar.isDateInToday(ingreso.fecha)

        return VStack(spacing: 0) {
            HStack(spacing: 14) {

                // Día compacto
                VStack(spacing: 1) {
                    Text(diaSemana(ingreso.fecha))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(esHoy ? Color.tlaneGreen : .secondary)
                    Text(numeroDia(ingreso.fecha))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(esHoy ? Color.tlaneGreen : .primary)
                }
                .frame(width: 38)

                // Fecha + barra
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(fechaLarga(ingreso.fecha))
                            .font(.subheadline)
                        if esHoy {
                            Text("HOY")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.tlaneGreen, in: Capsule())
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray5))
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.tlaneGreen, Color.tlaneGreen.opacity(0.6)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * pct, height: 5)
                        }
                    }
                    .frame(height: 5)
                }

                Spacer()

                Text(ingreso.total.formatted(.currency(code: "MXN")))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.tlaneGreen)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !esUltima {
                Divider().padding(.leading, 68)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.tlaneGreen.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "tray.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.tlaneGreen.opacity(0.4))
                    .symbolEffect(.pulse)
            }
            Text("Sin ingresos registrados")
                .font(.subheadline.weight(.semibold))
            Text("Los cobros que realices aparecerán aquí agrupados por día.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
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
        if calendar.isDateInToday(fecha)     { return "Hoy" }
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
        var total: Decimal { dias.reduce(.zero) { $0 + $1.total } }
    }

    private func agruparPorMes(_ ingresos: [IngresoDelDia]) -> [GrupoMes] {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "es_MX")

        var dict:  [String: [IngresoDelDia]] = [:]
        var orden: [String] = []

        for ingreso in ingresos {
            let clave = f.string(from: ingreso.fecha).capitalized
            if dict[clave] == nil { orden.append(clave); dict[clave] = [] }
            dict[clave]!.append(ingreso)
        }
        return orden.map { GrupoMes(mes: $0, dias: dict[$0]!) }
    }
}

#Preview {
    CajaGrandeView()
        .modelContainer(AppContainer.preview)
}
