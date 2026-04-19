//
//  CobrarSheetView.swift
//  Tlane
//
//  Created by Dev Jr.16 on 18/04/26.
//
import SwiftUI
import SwiftData

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
    @Environment(\.dismiss) private var dismiss

    let onVentaRegistrada: (Decimal, TipoCobro) -> Void

    // Pasos: 1 = productos, 2 = tipo cobro, 3 = simulación
    @State private var paso: Int = 1
    @State private var carrito: [ItemCarrito] = []
    @State private var tipoSeleccionado: TipoCobro? = nil
    @State private var estadoSimulacion: EstadoSim = .esperando
    @State private var mostrarExito = false
    @State private var busqueda: String = ""

    enum EstadoSim { case esperando, procesando, aprobado }

    private var productos: [Product] {
        let predicate = #Predicate<Product> { $0.currentStock > 0 }
        let descriptor = FetchDescriptor<Product>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private var productosFiltrados: [Product] {
        if busqueda.isEmpty { return productos }
        return productos.filter {
            $0.name.localizedCaseInsensitiveContains(busqueda)
        }
    }

    private var totalCarrito: Decimal {
        carrito.reduce(Decimal(0)) { $0 + $1.subtotal }
    }

    private var carritoVacio: Bool { carrito.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                mainContent
                if mostrarExito { overlayExito }
            }
            .navigationTitle(tituloNavegacion)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                if paso > 1 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.spring(response: 0.35)) { paso -= 1 }
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
    }

    private var tituloNavegacion: String {
        switch paso {
        case 1: return "Seleccionar productos"
        case 2: return "Forma de cobro"
        case 3: return "Cobrar"
        default: return "Cobrar"
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
                    case 2: paso2TipoCobro
                    case 3: paso3Simulacion
                    default: EmptyView()
                    }
                }
                .padding(20)
            }

            if paso < 3 {
                botonAccion
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.systemGroupedBackground))
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Indicador de pasos

    private var stepIndicator: some View {
        HStack(spacing: 4) {
            ForEach(1...3, id: \.self) { n in
                Capsule()
                    .fill(n <= paso ? Color.tlaneGreen : Color(.systemGray5))
                    .frame(maxWidth: .infinity, maxHeight: 4)
                    .animation(.easeInOut(duration: 0.3), value: paso)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Paso 1: Selección de productos

    private var paso1Productos: some View {
        VStack(spacing: 16) {

            // Buscador
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Buscar producto...", text: $busqueda)
                    .autocorrectionDisabled()
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12))

            // Carrito resumen (si hay items)
            if !carritoVacio {
                carritoResumen
            }

            // Lista de productos
            if productosFiltrados.isEmpty {
                emptyProductos
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(productosFiltrados.enumerated()), id: \.element.id) { index, product in
                        productoRow(product: product, esUltimo: index == productosFiltrados.count - 1)
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
                Text("Carrito")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(totalCarrito.formatted(.currency(code: "MXN")))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.tlaneGreen)
            }

            ForEach(carrito) { item in
                HStack(spacing: 12) {
                    // Foto o ícono
                    Group {
                        if let data = item.product.imageData,
                           let uiImg = UIImage(data: data) {
                            Image(uiImage: uiImg)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(Color.tlaneGreen)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text(item.product.name)
                        .font(.subheadline)
                        .lineLimit(1)

                    Spacer()

                    // Stepper de cantidad
                    HStack(spacing: 8) {
                        Button {
                            cambiarCantidad(product: item.product, delta: -1)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(Color(.systemGray3))
                                .font(.title3)
                        }

                        Text("\(item.cantidad)")
                            .font(.subheadline.weight(.semibold))
                            .frame(minWidth: 20)

                        Button {
                            cambiarCantidad(product: item.product, delta: +1)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.tlaneGreen)
                                .font(.title3)
                        }
                        .disabled(item.cantidad >= item.product.currentStock)
                    }

                    Text(item.subtotal.formatted(.currency(code: "MXN")))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 64, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.tlaneGreen.opacity(0.4), lineWidth: 1)
        }
    }

    private func productoRow(product: Product, esUltimo: Bool) -> some View {
        let enCarrito = carrito.first(where: { $0.product.id == product.id })

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Foto o ícono
                Group {
                    if let data = product.imageData,
                       let uiImg = UIImage(data: data) {
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: categoryIcon(product.category))
                            .foregroundStyle(Color.tlaneGreen)
                            .font(.title3)
                    }
                }
                .frame(width: 44, height: 44)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                .clipShape(RoundedRectangle(cornerRadius: 10))

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

                // Botón agregar / cantidad
                if let item = enCarrito {
                    HStack(spacing: 8) {
                        Button {
                            cambiarCantidad(product: product, delta: -1)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(Color(.systemGray3))
                                .font(.title3)
                        }
                        Text("\(item.cantidad)")
                            .font(.subheadline.weight(.bold))
                            .frame(minWidth: 18)
                        Button {
                            cambiarCantidad(product: product, delta: +1)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.tlaneGreen)
                                .font(.title3)
                        }
                        .disabled(item.cantidad >= product.currentStock)
                    }
                } else {
                    Button {
                        agregarAlCarrito(product: product)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.tlaneGreen)
                            .font(.title2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !esUltimo {
                Divider().padding(.leading, 72)
            }
        }
    }

    private var emptyProductos: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color(.systemGray4))
            Text(busqueda.isEmpty ? "Sin productos en inventario" : "Sin resultados para \"\(busqueda)\"")
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
            // Resumen del total
            VStack(spacing: 6) {
                Text("Total a cobrar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(totalCarrito.formatted(.currency(code: "MXN")))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.tlaneGreen)
                Text("\(carrito.reduce(0) { $0 + $1.cantidad }) producto(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16))

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
        case tapToPay   = "Tap to Pay"
        case qrCodi     = "QR / CoDi"
        case efectivo   = "Efectivo"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .tapToPay:  return "wave.3.right.circle.fill"
            case .qrCodi:    return "qrcode"
            case .efectivo:  return "banknote"
            }
        }

        var descripcion: String {
            switch self {
            case .tapToPay:  return "El cliente acerca su dispositivo"
            case .qrCodi:    return "El cliente escanea el código"
            case .efectivo:  return "Confirma el pago en mano"
            }
        }
    }

    private func tipoCobro(_ tipo: TipoCobro) -> some View {
        let seleccionado = tipoSeleccionado == tipo
        return Button {
            withAnimation(.spring(response: 0.3)) {
                tipoSeleccionado = tipo
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: tipo.systemImage)
                    .font(.title2)
                    .foregroundStyle(seleccionado ? Color.tlaneGreen : .secondary)
                    .frame(width: 36)

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
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(seleccionado ? Color.tlaneGreen : Color.clear, lineWidth: 2)
            }
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

    // Resumen compacto de productos (visible en paso 3)
    private var resumenProductosSim: some View {
        VStack(spacing: 0) {
            ForEach(Array(carrito.enumerated()), id: \.element.id) { index, item in
                HStack {
                    Text(item.product.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text("x\(item.cantidad)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.subtotal.formatted(.currency(code: "MXN")))
                        .font(.caption.weight(.semibold))
                        .frame(minWidth: 70, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                if index < carrito.count - 1 {
                    Divider().padding(.horizontal, 14)
                }
            }
            Divider()
            HStack {
                Text("Total")
                    .font(.subheadline.weight(.semibold))
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
                Circle()
                    .fill(Color.tlaneGreen.opacity(0.08))
                    .frame(width: 160, height: 160)
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.tlaneGreen)
                    .symbolEffect(.pulse, isActive: estadoSimulacion == .procesando)
            }

            VStack(spacing: 8) {
                Text(estadoSimulacion == .esperando ? "Listo para cobrar" :
                     estadoSimulacion == .procesando ? "Procesando..." : "¡Aprobado!")
                    .font(.title3.weight(.semibold))
                Text(estadoSimulacion == .aprobado
                     ? "Pago recibido correctamente"
                     : "Pide al cliente que acerque su dispositivo o tarjeta")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if estadoSimulacion == .esperando {
                botonSimular("Simular cobro")
            }
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
                Image(systemName: "qrcode")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                    .foregroundStyle(.primary)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.tlaneGreen, lineWidth: 2)
            }

            Text(estadoSimulacion == .esperando
                 ? "El cliente escanea este código con CoDi o su app bancaria"
                 : estadoSimulacion == .procesando ? "Esperando confirmación..."
                 : "¡Pago recibido!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if estadoSimulacion == .esperando {
                botonSimular("Confirmar escaneo")
            }
        }
    }

    // Efectivo
    private var simEfectivo: some View {
        VStack(spacing: 24) {
            resumenProductosSim

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 130, height: 130)
                Image(systemName: "banknote")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
            }

            Text("Recibe el efectivo del cliente y confirma el cobro.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if estadoSimulacion == .esperando {
                botonSimular("Efectivo recibido")
            }

            if estadoSimulacion == .procesando {
                ProgressView("Registrando venta...")
                    .tint(Color.tlaneGreen)
            }
        }
    }

    private func botonSimular(_ label: String) -> some View {
        Button {
            simularPago()
        } label: {
            Text(label)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.tlaneGreen, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Botón de acción (pasos 1 y 2)

    private var botonAccion: some View {
        Button {
            withAnimation(.spring(response: 0.4)) { paso += 1 }
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
                }
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(botonHabilitado ? Color.tlaneGreen : Color(.systemGray4),
                        in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.white)
        }
        .disabled(!botonHabilitado)
        .animation(.easeInOut(duration: 0.2), value: botonHabilitado)
    }

    private var botonHabilitado: Bool {
        paso == 1 ? !carritoVacio : tipoSeleccionado != nil
    }

    // MARK: - Lógica del carrito

    private func agregarAlCarrito(product: Product) {
        if let index = carrito.firstIndex(where: { $0.product.id == product.id }) {
            if carrito[index].cantidad < product.currentStock {
                carrito[index].cantidad += 1
            }
        } else {
            carrito.append(ItemCarrito(product: product, cantidad: 1))
        }
    }

    private func cambiarCantidad(product: Product, delta: Int) {
        guard let index = carrito.firstIndex(where: { $0.product.id == product.id }) else { return }
        let nuevaCantidad = carrito[index].cantidad + delta
        if nuevaCantidad <= 0 {
            carrito.remove(at: index)
        } else if nuevaCantidad <= product.currentStock {
            carrito[index].cantidad = nuevaCantidad
        }
    }

    // MARK: - Simulación de cobro

    private func simularPago() {
        withAnimation { estadoSimulacion = .procesando }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            persistirVenta()
            withAnimation(.spring(response: 0.4)) {
                estadoSimulacion = .aprobado
                mostrarExito = true
            }
            onVentaRegistrada(totalCarrito, tipoSeleccionado ?? .efectivo)
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
        let sale = Sale(
            amount: totalCarrito,
            paymentMethod: paymentMethod,
            items: items
        )
        context.insert(sale)

        // Descontar stock
        for item in carrito {
            item.product.currentStock -= item.cantidad
        }

        try? context.save()
    }

    // MARK: - Overlay de éxito

    private var overlayExito: some View {
        ZStack {
            Color(.systemBackground).opacity(0.95).ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.tlaneGreen.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.tlaneGreen)
                }

                Text("¡Venta registrada!")
                    .font(.title.weight(.bold))

                Text(totalCarrito.formatted(.currency(code: "MXN")))
                    .font(.title2)
                    .foregroundStyle(.secondary)

                // Detalle de productos vendidos
                VStack(spacing: 4) {
                    ForEach(carrito) { item in
                        HStack {
                            Text(item.product.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("x\(item.cantidad)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 32)

                Text("Vía \(tipoSeleccionado?.rawValue ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    dismiss()
                } label: {
                    Text("Listo")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.tlaneGreen, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.top, 8)
            }
            .padding(32)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Helper

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "textil":   return "tshirt.fill"
        case "barro":    return "cup.and.saucer.fill"
        case "madera":   return "tree.fill"
        case "joyería":  return "sparkles"
        default:         return "tag.fill"
        }
    }
}
