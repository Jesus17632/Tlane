//
//  CobrarSheetView.swift
//  Tlane
//
//  Created by Dev Jr.16 on 18/04/26.
//
import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Modelo del carrito

struct ItemCarrito: Identifiable {
    let id = UUID()
    let product: Product
    var cantidad: Int
    var subtotal: Decimal { product.price * Decimal(cantidad) }
}

// MARK: - View Principal

struct CobrarSheetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    let onVentaRegistrada: (Decimal, TipoCobro) -> Void

    @State private var paso: Int = 1
    @State private var carrito: [ItemCarrito] = []
    @State private var tipoSeleccionado: TipoCobro? = nil
    @State private var estadoSimulacion: EstadoSim = .esperando
    @State private var mostrarExito = false
    @State private var busqueda: String = ""
    @State private var pasoAnterior: Int = 1
    @State private var pulseTotal = false

    enum EstadoSim { case esperando, procesando, aprobado }

    private var productos: [Product] {
        let predicate  = #Predicate<Product> { $0.currentStock > 0 }
        let descriptor = FetchDescriptor<Product>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private var productosFiltrados: [Product] {
        busqueda.isEmpty ? productos : productos.filter {
            $0.name.localizedCaseInsensitiveContains(busqueda)
        }
    }

    private var totalCarrito: Decimal {
        carrito.reduce(.zero) { $0 + $1.subtotal }
    }
    private var carritoVacio: Bool { carrito.isEmpty }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Fondo degradado sutil
                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground),
                        Color.tlaneGreen.opacity(0.04)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                mainContent

                if mostrarExito { overlayExito }
            }
            .navigationTitle(tituloNavegacion)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                if paso > 1 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            avanzar(a: paso - 1)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Atrás")
                            }
                        }
                    }
                }
            }
        }
        .task { await pedirPermisoNotificaciones() }
    }

    private var tituloNavegacion: String {
        switch paso {
        case 1:  "Seleccionar productos"
        case 2:  "Forma de cobro"
        case 3:  "Cobrar"
        default: "Cobrar"
        }
    }

    // MARK: - Contenido principal

    private var mainContent: some View {
        VStack(spacing: 0) {
            stepIndicator

            ScrollView {
                VStack(spacing: 20) {
                    switch paso {
                    case 1: paso1Productos
                        .transition(transicion(hacia: paso))
                    case 2: paso2TipoCobro
                        .transition(transicion(hacia: paso))
                    case 3: paso3Simulacion
                        .transition(transicion(hacia: paso))
                    default: EmptyView()
                    }
                }
                .padding(20)
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: paso)
            }

            if paso < 3 {
                botonAccion
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 20,
                            topTrailingRadius: 20
                        )
                        .fill(Color(.systemGroupedBackground))
                        .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
                    )
            }
        }
    }

    // Dirección de la transición según avance/retroceso
    private func transicion(hacia nuevoPaso: Int) -> AnyTransition {
        let direction: Edge = nuevoPaso >= pasoAnterior ? .trailing : .leading
        return .asymmetric(
            insertion: .move(edge: direction).combined(with: .opacity),
            removal:   .move(edge: direction == .trailing ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func avanzar(a nuevoPaso: Int) {
        pasoAnterior = paso
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            paso = nuevoPaso
        }
    }

    // MARK: - Indicador de pasos

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(1...3, id: \.self) { n in
                ZStack {
                    Capsule()
                        .fill(n < paso ? Color.tlaneGreen : Color(.systemGray5))
                        .frame(maxWidth: .infinity, maxHeight: 4)
                    if n == paso {
                        Capsule()
                            .fill(Color.tlaneGreen)
                            .frame(maxWidth: .infinity, maxHeight: 4)
                            .matchedGeometryEffect(id: "activePaso", in: stepNS)
                    }
                }
                .animation(.spring(response: 0.4), value: paso)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @Namespace private var stepNS

    // MARK: - Paso 1: Productos

    private var paso1Productos: some View {
        VStack(spacing: 16) {
            // Buscador
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Buscar producto...", text: $busqueda)
                    .autocorrectionDisabled()
                if !busqueda.isEmpty {
                    Button {
                        withAnimation { busqueda = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12))

            if !carritoVacio { carritoResumen }

            if productosFiltrados.isEmpty {
                emptyProductos
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(productosFiltrados.enumerated()), id: \.element.id) { i, product in
                        productoRow(product: product, esUltimo: i == productosFiltrados.count - 1)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var carritoResumen: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Carrito", systemImage: "cart.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.tlaneGreen)
                Spacer()
                Text(totalCarrito.formatted(.currency(code: "MXN")))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.tlaneGreen)
                    .scaleEffect(pulseTotal ? 1.12 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: pulseTotal)
            }

            ForEach(carrito) { item in
                HStack(spacing: 12) {
                    productoThumb(item.product, size: 36)

                    Text(item.product.name)
                        .font(.subheadline)
                        .lineLimit(1)

                    Spacer()

                    stepperCompacto(product: item.product, cantidad: item.cantidad)

                    Text(item.subtotal.formatted(.currency(code: "MXN")))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 64, alignment: .trailing)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal:   .scale(scale: 0.6).combined(with: .opacity)
                ))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.tlaneGreen, Color.tlaneGreen.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
        .animation(.spring(response: 0.38), value: carrito.count)
    }

    private func productoRow(product: Product, esUltimo: Bool) -> some View {
        let enCarrito = carrito.first(where: { $0.product.id == product.id })
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                productoThumb(product, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(product.price.formatted(.currency(code: "MXN")))
                            .font(.caption)
                            .foregroundStyle(Color.tlaneGreen)
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("Stock: \(product.currentStock)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let item = enCarrito {
                    stepperCompacto(product: product, cantidad: item.cantidad)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Button {
                        agregarAlCarrito(product: product)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.tlaneGreen)
                            .symbolEffect(.bounce, value: enCarrito != nil)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(.spring(response: 0.35), value: enCarrito?.cantidad)

            if !esUltimo {
                Divider().padding(.leading, 72)
            }
        }
    }

    @ViewBuilder
    private func productoThumb(_ product: Product, size: CGFloat) -> some View {
        Group {
            if let data = product.imageData, let uiImg = UIImage(data: data) {
                Image(uiImage: uiImg).resizable().scaledToFill()
            } else {
                Image(systemName: categoryIcon(product.category))
                    .font(size > 40 ? .title3 : .body)
                    .foregroundStyle(Color.tlaneGreen)
            }
        }
        .frame(width: size, height: size)
        .background(Color.tlaneGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: size * 0.23))
        .clipShape(RoundedRectangle(cornerRadius: size * 0.23))
    }

    private func stepperCompacto(product: Product, cantidad: Int) -> some View {
        HStack(spacing: 8) {
            Button {
                cambiarCantidad(product: product, delta: -1)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Color(.systemGray3))
                    .font(.title3)
            }
            Text("\(cantidad)")
                .font(.subheadline.weight(.bold))
                .frame(minWidth: 20)
                .contentTransition(.numericText())
            Button {
                cambiarCantidad(product: product, delta: +1)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(cantidad >= product.currentStock
                                     ? Color(.systemGray3) : Color.tlaneGreen)
                    .font(.title3)
            }
            .disabled(cantidad >= product.currentStock)
        }
    }

    private var emptyProductos: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color(.systemGray4))
            Text(busqueda.isEmpty
                 ? "Sin productos en inventario"
                 : "Sin resultados para \"\(busqueda)\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Paso 2: Tipo de cobro

    private var paso2TipoCobro: some View {
        VStack(spacing: 20) {
            // Total con animación
            VStack(spacing: 6) {
                Text("Total a cobrar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(totalCarrito.formatted(.currency(code: "MXN")))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.tlaneGreen)
                    .contentTransition(.numericText())
                    .shadow(color: Color.tlaneGreen.opacity(0.25), radius: 8)
                Text("\(carrito.reduce(0) { $0 + $1.cantidad }) producto(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.tlaneGreen.opacity(0.2), lineWidth: 1)
                    }
            )

            Text("¿Cómo quieres cobrar?")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                ForEach(TipoCobro.allCases) { tipo in
                    tipoCobro(tipo)
                }
            }
        }
    }

    // MARK: - Tipos de cobro

    enum TipoCobro: String, CaseIterable, Identifiable {
        case tapToPay = "Tap to Pay"
        case qrCodi   = "QR / CoDi"
        case efectivo = "Efectivo"
        var id: String { rawValue }
        var systemImage: String {
            switch self {
            case .tapToPay: "wave.3.right.circle.fill"
            case .qrCodi:   "qrcode"
            case .efectivo: "banknote"
            }
        }
        var descripcion: String {
            switch self {
            case .tapToPay: "El cliente acerca su dispositivo"
            case .qrCodi:   "El cliente escanea el código"
            case .efectivo: "Confirma el pago en mano"
            }
        }
        var color: Color {
            switch self {
            case .tapToPay: .blue
            case .qrCodi:   .purple
            case .efectivo: .green
            }
        }
    }

    private func tipoCobro(_ tipo: TipoCobro) -> some View {
        let seleccionado = tipoSeleccionado == tipo
        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.3)) {
                tipoSeleccionado = tipo
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(seleccionado ? tipo.color.opacity(0.15) : Color(.systemGray6))
                        .frame(width: 44, height: 44)
                    Image(systemName: tipo.systemImage)
                        .font(.title3)
                        .foregroundStyle(seleccionado ? tipo.color : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(tipo.rawValue)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(tipo.descripcion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: seleccionado ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(seleccionado ? Color.tlaneGreen : Color(.systemGray4))
                    .font(.title3)
                    .symbolEffect(.bounce, value: seleccionado)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        seleccionado
                            ? LinearGradient(colors: [Color.tlaneGreen, tipo.color.opacity(0.6)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 2
                    )
            }
            .scaleEffect(seleccionado ? 1.01 : 1.0)
        }
    }

    // MARK: - Paso 3: Simulación

    @ViewBuilder
    private var paso3Simulacion: some View {
        switch tipoSeleccionado {
        case .tapToPay: simTapToPay
        case .qrCodi:   simQR
        case .efectivo: simEfectivo
        case .none:     EmptyView()
        }
    }

    private var resumenProductosSim: some View {
        VStack(spacing: 0) {
            ForEach(Array(carrito.enumerated()), id: \.element.id) { i, item in
                HStack {
                    Text(item.product.name)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Text("x\(item.cantidad)").font(.caption).foregroundStyle(.secondary)
                    Text(item.subtotal.formatted(.currency(code: "MXN")))
                        .font(.caption.weight(.semibold)).frame(minWidth: 70, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                if i < carrito.count - 1 { Divider().padding(.horizontal, 14) }
            }
            Divider()
            HStack {
                Text("Total").font(.subheadline.weight(.semibold))
                Spacer()
                Text(totalCarrito.formatted(.currency(code: "MXN")))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.tlaneGreen)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    // Tap to Pay
    private var simTapToPay: some View {
        VStack(spacing: 24) {
            resumenProductosSim

            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.tlaneGreen.opacity(0.15 - Double(i) * 0.04), lineWidth: 1)
                        .frame(width: CGFloat(160 + i * 40), height: CGFloat(160 + i * 40))
                        .scaleEffect(estadoSimulacion == .procesando ? 1.3 : 1.0)
                        .opacity(estadoSimulacion == .procesando ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.2).repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.3),
                            value: estadoSimulacion
                        )
                }
                Circle()
                    .fill(Color.tlaneGreen.opacity(0.1))
                    .frame(width: 140, height: 140)
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.tlaneGreen)
                    .symbolEffect(.pulse, isActive: estadoSimulacion == .procesando)
            }

            estadoLabel(
                esperando: "Listo para cobrar",
                procesando: "Procesando...",
                subtitulo: "Pide al cliente que acerque su dispositivo o tarjeta"
            )

            if estadoSimulacion == .esperando { botonSimular("Simular cobro") }
        }
    }

    // QR / CoDi
    private var simQR: some View {
        VStack(spacing: 24) {
            resumenProductosSim

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 180, height: 180)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.tlaneGreen, .purple.opacity(0.6)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
                Image(systemName: "qrcode")
                    .resizable().scaledToFit()
                    .frame(width: 130, height: 130)
                    .foregroundStyle(.primary)
                    .opacity(estadoSimulacion == .procesando ? 0.4 : 1)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                               value: estadoSimulacion)
            }

            estadoLabel(
                esperando: "El cliente escanea el código",
                procesando: "Esperando confirmación...",
                subtitulo: "Con CoDi o app bancaria"
            )

            if estadoSimulacion == .esperando { botonSimular("Confirmar escaneo") }
        }
    }

    // Efectivo
    private var simEfectivo: some View {
        VStack(spacing: 24) {
            resumenProductosSim

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.08))
                    .frame(width: 140, height: 140)
                Image(systemName: "banknote")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                    .rotationEffect(estadoSimulacion == .procesando ? .degrees(5) : .zero)
                    .animation(
                        .easeInOut(duration: 0.2).repeatForever(autoreverses: true),
                        value: estadoSimulacion
                    )
            }

            estadoLabel(
                esperando: "Recibe el efectivo",
                procesando: "Registrando venta...",
                subtitulo: "Recibe el efectivo del cliente y confirma el cobro"
            )

            if estadoSimulacion == .esperando {
                botonSimular("Efectivo recibido")
            }
            if estadoSimulacion == .procesando {
                ProgressView().tint(Color.tlaneGreen)
            }
        }
    }

    @ViewBuilder
    private func estadoLabel(esperando: String, procesando: String, subtitulo: String) -> some View {
        VStack(spacing: 8) {
            Text(estadoSimulacion == .aprobado ? "¡Aprobado!"
                 : estadoSimulacion == .procesando ? procesando : esperando)
                .font(.title3.weight(.semibold))
                .contentTransition(.interpolate)
                .animation(.spring(), value: estadoSimulacion)

            Text(estadoSimulacion == .aprobado
                 ? "Pago recibido correctamente" : subtitulo)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut, value: estadoSimulacion)
        }
    }

    private func botonSimular(_ label: String) -> some View {
        Button {
            simularPago()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                Text(label)
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [Color.tlaneGreen, Color.tlaneGreen.opacity(0.8)],
                    startPoint: .leading, endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .foregroundStyle(.white)
            .shadow(color: Color.tlaneGreen.opacity(0.35), radius: 10, y: 4)
        }
    }

    // MARK: - Botón acción pasos 1 y 2

    private var botonAccion: some View {
        Button {
            avanzar(a: paso + 1)
        } label: {
            HStack(spacing: 8) {
                if paso == 1 {
                    Text("Continuar")
                    if !carritoVacio {
                        Text("·")
                        Text(totalCarrito.formatted(.currency(code: "MXN")))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                } else {
                    Text("Ir a cobrar")
                    Image(systemName: "arrow.right")
                }
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                botonHabilitado
                    ? LinearGradient(colors: [Color.tlaneGreen, Color.tlaneGreen.opacity(0.85)],
                                     startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color(.systemGray4)],
                                     startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .foregroundStyle(.white)
            .shadow(color: botonHabilitado ? Color.tlaneGreen.opacity(0.3) : .clear,
                    radius: 10, y: 4)
        }
        .disabled(!botonHabilitado)
        .animation(.spring(response: 0.3), value: botonHabilitado)
    }

    private var botonHabilitado: Bool {
        paso == 1 ? !carritoVacio : tipoSeleccionado != nil
    }

    // MARK: - Lógica carrito

    private func agregarAlCarrito(product: Product) {
        withAnimation(.spring(response: 0.35)) {
            if let i = carrito.firstIndex(where: { $0.product.id == product.id }) {
                if carrito[i].cantidad < product.currentStock { carrito[i].cantidad += 1 }
            } else {
                carrito.append(ItemCarrito(product: product, cantidad: 1))
            }
        }
        animarTotal()
    }

    private func cambiarCantidad(product: Product, delta: Int) {
        guard let i = carrito.firstIndex(where: { $0.product.id == product.id }) else { return }
        let nueva = carrito[i].cantidad + delta
        withAnimation(.spring(response: 0.35)) {
            if nueva <= 0 { carrito.remove(at: i) }
            else if nueva <= product.currentStock { carrito[i].cantidad = nueva }
        }
        animarTotal()
    }

    private func animarTotal() {
        pulseTotal = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { pulseTotal = false }
    }

    // MARK: - Simulación y notificación

    private func simularPago() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.spring()) { estadoSimulacion = .procesando }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            persistirVenta()

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                estadoSimulacion = .aprobado
                mostrarExito     = true
            }

            onVentaRegistrada(totalCarrito, tipoSeleccionado ?? .efectivo)
            enviarNotificacionVenta()
        }
    }

    private func persistirVenta() {
        let paymentMethod: PaymentMethod = tipoSeleccionado == .efectivo ? .cash : .digital
        let items = carrito.map {
            SaleItem(
                productId: $0.product.id,
                productName: $0.product.name,
                quantity: $0.cantidad,
                priceAtSale: $0.product.price
            )
        }
        let sale = Sale(amount: totalCarrito, paymentMethod: paymentMethod, items: items)
        context.insert(sale)
        for item in carrito { item.product.currentStock -= item.cantidad }
        try? context.save()
    }

    // MARK: - Notificaciones

    private func pedirPermisoNotificaciones() async {
        try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    private func enviarNotificacionVenta() {
        let content         = UNMutableNotificationContent()
        content.title       = "✅ Venta registrada"
        content.body        = "\(totalCarrito.formatted(.currency(code: "MXN"))) vía \(tipoSeleccionado?.rawValue ?? ""). \(carrito.reduce(0) { $0 + $1.cantidad }) pieza(s) vendida(s)."
        content.sound       = .default
        content.badge       = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "venta-\(UUID())",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Overlay éxito

    private var overlayExito: some View {
        ZStack {
            Color(.systemBackground).opacity(0.97).ignoresSafeArea()

            VStack(spacing: 20) {
                // Ícono animado
                ZStack {
                    Circle()
                        .fill(Color.tlaneGreen.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Circle()
                        .fill(Color.tlaneGreen.opacity(0.06))
                        .frame(width: 150, height: 150)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.tlaneGreen)
                        .symbolEffect(.bounce, value: mostrarExito)
                }

                Text("¡Venta registrada!")
                    .font(.title.weight(.bold))

                Text(totalCarrito.formatted(.currency(code: "MXN")))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.tlaneGreen)

                // Productos vendidos
                VStack(spacing: 6) {
                    ForEach(carrito) { item in
                        HStack {
                            Text(item.product.name)
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("x\(item.cantidad)")
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)

                Label("Vía \(tipoSeleccionado?.rawValue ?? "")",
                      systemImage: tipoSeleccionado?.systemImage ?? "creditcard")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    dismiss()
                } label: {
                    Text("Listo")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [Color.tlaneGreen, Color.tlaneGreen.opacity(0.85)],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .foregroundStyle(.white)
                        .shadow(color: Color.tlaneGreen.opacity(0.4), radius: 12, y: 6)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .padding(24)
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.92).combined(with: .opacity),
            removal:   .opacity
        ))
    }

    // MARK: - Helper

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "textil":   "tshirt.fill"
        case "barro":    "cup.and.saucer.fill"
        case "madera":   "tree.fill"
        case "joyería":  "sparkles"
        default:         "tag.fill"
        }
    }
}
