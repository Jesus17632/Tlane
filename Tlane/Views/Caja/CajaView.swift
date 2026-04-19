import SwiftUI
import SwiftData
import Charts
import PhotosUI
import UserNotifications

struct IngresoDia {
    let dia: Date
    let total: Decimal
}

struct CajaView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Sale.date, order: .reverse) private var allSales: [Sale]

    @AppStorage("usuario_nombre") private var usuarioNombre: String = "Mi cuenta"
    @AppStorage("usuario_rol")    private var usuarioRol: String    = "Vendedor independiente"
    @AppStorage("usuario_avatar") private var avatarBase64: String  = ""

    @State private var photoItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var editandoNombre  = false
    @State private var editandoRol     = false
    @State private var nombreTemp      = ""
    @State private var rolTemp         = ""

    // Animaciones
    @State private var totalVisible    = false
    @State private var cardOffsets: [Int: CGFloat] = [:]
    @State private var avatarScale     = 1.0
    @State private var chartVisible    = false

    // MARK: - Derivados

    private var currentMonthSales: [Sale] {
        guard let start = Calendar.current.dateInterval(of: .month, for: .now)?.start
        else { return [] }
        return allSales.filter { $0.date >= start }
    }

    private var totalMes: Decimal {
        currentMonthSales.reduce(.zero) { $0 + $1.amount }
    }

    private var totalEfectivoMes: Decimal {
        currentMonthSales
            .filter { $0.paymentMethod == .cash && $0.amount > 0 }
            .reduce(.zero) { $0 + $1.amount }
    }

    private var totalDigitalMes: Decimal {
        currentMonthSales
            .filter { $0.paymentMethod == .digital && $0.amount > 0 }
            .reduce(.zero) { $0 + $1.amount }
    }

    private var operacionesMes: Int { currentMonthSales.count }

    private var efectivoRatio: Double {
        guard totalMes > 0 else { return 0 }
        return NSDecimalNumber(decimal: totalEfectivoMes).doubleValue
             / NSDecimalNumber(decimal: totalMes).doubleValue
    }

    private var monthLabel: String {
        let fmt = DateFormatter()
        fmt.locale     = Locale(identifier: "es_MX")
        fmt.dateFormat = "LLLL yyyy"
        return fmt.string(from: .now).capitalized
    }

    private var ingresosPorDia: [IngresoDia] {
        var grupos: [Date: Decimal] = [:]
        for sale in currentMonthSales {
            let inicio = Calendar.current.startOfDay(for: sale.date)
            grupos[inicio, default: .zero] += sale.amount
        }
        return grupos
            .map { IngresoDia(dia: $0.key, total: $0.value) }
            .sorted { $0.dia < $1.dia }
    }

    private var tickerMes: String {
        let ops = operacionesMes
        let avg: Decimal = ops > 0 ? totalMes / Decimal(ops) : .zero
        return "Promedio por venta: \(avg.formatted(.currency(code: "MXN")))"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Fondo degradado igual que CobrarSheetView
            LinearGradient(
                colors: [
                    Color.tlaneBackground,
                    Color.tlaneGreen.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    avatarSection
                    totalCard
                    statsRow
                    ingresosChart
                    desgloseSection
                    operacionesCard
                    historicoPlaceholder
                }
                .padding()
            }
        }
        .navigationTitle("Mi Perfil")
        .onAppear {
            cargarAvatar()
            animarEntrada()
        }
        .onChange(of: photoItem) { _, newItem in
            Task { await cargarFoto(newItem) }
        }
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let img = avatarImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.tlaneGreen, Color.tlaneGreen.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2.5
                                        )
                                }
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.tlaneGreen.opacity(0.1))
                                    .frame(width: 96, height: 96)
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.tlaneGreen, Color.tlaneGreen.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2.5
                                    )
                                    .frame(width: 96, height: 96)
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 68))
                                    .foregroundStyle(Color.tlaneGreen)
                            }
                        }
                    }
                    .shadow(color: Color.tlaneGreen.opacity(0.2), radius: 12, y: 4)

                    // Badge cámara
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.tlaneGreen, Color.tlaneGreen.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                            .shadow(color: Color.tlaneGreen.opacity(0.4), radius: 4)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 2, y: 2)
                }
            }
            .scaleEffect(avatarScale)
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    avatarScale = 0.92
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring()) { avatarScale = 1.0 }
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            // Nombre editable
            Group {
                if editandoNombre {
                    HStack(spacing: 6) {
                        TextField("Nombre", text: $nombreTemp)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                            .submitLabel(.done)
                            .onSubmit { guardarNombre() }
                        Button { guardarNombre() } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.tlaneGreen)
                                .symbolEffect(.bounce, value: editandoNombre)
                        }
                    }
                    .padding(.horizontal, 32)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button {
                        nombreTemp     = usuarioNombre
                        editandoNombre = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 4) {
                            Text(usuarioNombre)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35), value: editandoNombre)

            // Rol editable
            Group {
                if editandoRol {
                    HStack(spacing: 6) {
                        TextField("Descripción", text: $rolTemp)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .submitLabel(.done)
                            .onSubmit { guardarRol() }
                        Button { guardarRol() } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.tlaneGreen)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 40)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button {
                        rolTemp     = usuarioRol
                        editandoRol = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 4) {
                            Text(usuarioRol)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "pencil")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35), value: editandoRol)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Total card

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total del mes")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(monthLabel)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                // Badge tendencia
                Label(operacionesMes > 0 ? "+\(operacionesMes) ventas" : "Sin ventas",
                      systemImage: operacionesMes > 0 ? "arrow.up.right" : "minus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(operacionesMes > 0 ? Color.tlaneGreen : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        (operacionesMes > 0 ? Color.tlaneGreen : Color(.systemGray5)).opacity(0.12),
                        in: Capsule()
                    )
            }

            Text(totalMes.formatted(.currency(code: "MXN")))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Color.tlaneGreen)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.spring(), value: totalMes)
                .shadow(color: Color.tlaneGreen.opacity(0.2), radius: 8)
                .opacity(totalVisible ? 1 : 0)
                .offset(y: totalVisible ? 0 : 12)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: totalVisible)

            // Ticker subtítulo
            if operacionesMes > 0 {
                Text(tickerMes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Stats rápidas (fila de 2 chips)

    private var statsRow: some View {
        HStack(spacing: 12) {
            statChip(
                icon: "cart.fill",
                color: .tlaneGreen,
                valor: "\(operacionesMes)",
                label: "Ventas"
            )
            statChip(
                icon: "banknote",
                color: .tlaneEarth,
                valor: "\(Int((efectivoRatio * 100).rounded()))%",
                label: "Efectivo"
            )
        }
    }

    private func statChip(icon: String, color: Color, valor: String, label: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(valor)
                    .font(.title3.weight(.bold))
                    .contentTransition(.numericText())
                    .animation(.spring(), value: valor)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .glassEffect(in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Gráfica

    private var ingresosChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingresos por día")
                    .font(.headline)
                Spacer()
                Text(monthLabel)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if ingresosPorDia.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundStyle(.secondary)
                    Text("Sin datos este mes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                Chart {
                    ForEach(ingresosPorDia, id: \.dia) { punto in
                        BarMark(
                            x: .value("Día", punto.dia, unit: .day),
                            y: .value("Ingreso",
                                      chartVisible
                                        ? NSDecimalNumber(decimal: punto.total).doubleValue
                                        : 0)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.tlaneGreen, Color.tlaneGreen.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(5)
                    }

                    // Línea del promedio
                    if operacionesMes > 0 {
                        let avg = NSDecimalNumber(decimal: totalMes / Decimal(operacionesMes)).doubleValue
                        RuleMark(y: .value("Promedio", avg))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Color.tlaneGreen.opacity(0.4))
                            .annotation(position: .trailing) {
                                Text("avg")
                                    .font(.caption2)
                                    .foregroundStyle(Color.tlaneGreen.opacity(0.6))
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        AxisValueLabel(format: .dateTime.day())
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text("$\(Int(d))").font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
                .animation(.spring(response: 0.7, dampingFraction: 0.8), value: chartVisible)
            }
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Desglose

    private var desgloseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Desglose por método")
                .font(.headline)

            VStack(spacing: 10) {
                metodoRow(
                    titulo:      "Efectivo",
                    systemImage: "banknote",
                    color:       .tlaneEarth,
                    monto:       totalEfectivoMes,
                    ratio:       efectivoRatio
                )
                metodoRow(
                    titulo:      "Digital",
                    systemImage: "wave.3.right.circle.fill",
                    color:       .tlaneGreen,
                    monto:       totalDigitalMes,
                    ratio:       1 - efectivoRatio
                )
            }
        }
    }

    private func metodoRow(
        titulo: String,
        systemImage: String,
        color: Color,
        monto: Decimal,
        ratio: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: systemImage)
                        .font(.body)
                        .foregroundStyle(color)
                }

                Text(titulo)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(monto.formatted(.currency(code: "MXN")))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .animation(.spring(), value: monto)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.12))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * (chartVisible ? ratio : 0))
                        .animation(
                            .spring(response: 0.7, dampingFraction: 0.75).delay(0.2),
                            value: chartVisible
                        )
                }
            }
            .frame(height: 7)

            Text("\(Int((ratio * 100).rounded()))% del total")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Operaciones

    private var operacionesCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.tlaneGreen.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "list.bullet.rectangle")
                    .font(.title3)
                    .foregroundStyle(Color.tlaneGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(operacionesMes)")
                    .font(.title2.weight(.bold))
                    .contentTransition(.numericText())
                    .animation(.spring(), value: operacionesMes)
                Text(operacionesMes == 1 ? "operación este mes" : "operaciones este mes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            // Mini sparkline decorativo
            Image(systemName: operacionesMes > 5 ? "chart.line.uptrend.xyaxis" : "chart.line.flattrend.xyaxis")
                .font(.title2)
                .foregroundStyle(operacionesMes > 5 ? Color.tlaneGreen : .secondary)
                .symbolEffect(.pulse, isActive: operacionesMes > 0)
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Placeholder histórico

    private var historicoPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title)
                .foregroundStyle(Color.tlaneGreen.opacity(0.5))
                .symbolEffect(.pulse)
            Text("Historial completo próximamente")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Podrás ver todas tus ventas por periodo")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .glassEffect(in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func cargarAvatar() {
        guard !avatarBase64.isEmpty,
              let data = Data(base64Encoded: avatarBase64),
              let img  = UIImage(data: data)
        else { return }
        avatarImage = img
    }

    private func cargarFoto(_ item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self),
              let img  = UIImage(data: data)
        else { return }
        withAnimation(.spring()) { avatarImage = img }
        avatarBase64 = data.base64EncodedString()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func guardarNombre() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        usuarioNombre  = nombreTemp.isEmpty ? "Mi cuenta" : nombreTemp
        withAnimation(.spring()) { editandoNombre = false }
    }

    private func guardarRol() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        usuarioRol  = rolTemp.isEmpty ? "Vendedor independiente" : rolTemp
        withAnimation(.spring()) { editandoRol = false }
    }

    private func animarEntrada() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                totalVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                chartVisible = true
            }
        }
    }
}

#Preview {
    NavigationStack { CajaView() }
        .modelContainer(AppContainer.preview)
}
