//
//  PagarSheetView.swift
//  Tlane
//
import SwiftUI
import SwiftData

// MARK: - Modelos

enum MetodoPago: String, CaseIterable, Identifiable {
    case applePay      = "Apple Pay"
    case transferencia = "Transferencia"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .applePay:      return "apple.logo"
        case .transferencia: return "arrow.left.arrow.right.circle.fill"
        }
    }

    var paymentMethod: PaymentMethod { .digital }
}

// MARK: - View Principal

struct PagarSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let verde      = Color(red: 0.18, green: 0.47, blue: 0.20)
    private let arena      = Color(red: 0.72, green: 0.62, blue: 0.48)
    private let arenaOscuro = Color(red: 0.72, green: 0.62, blue: 0.48)
    private let fondo      = Color(red: 0.97, green: 0.96, blue: 0.95)
    private let oscuro     = Color(red: 0.18, green: 0.18, blue: 0.18)
    private let rojo       = Color(red: 0.75, green: 0.25, blue: 0.20)

    @State private var montoTexto: String = ""
    @State private var metodoSeleccionado: MetodoPago? = nil
    @State private var clabe: String = ""
    @State private var banco: String = ""
    @State private var concepto: String = ""
    @State private var paso: Int = 1
    @State private var mostrarExito: Bool = false
    @State private var procesando: Bool = false

    // Animaciones de entrada
    @State private var animarContenido = false

    private var montoDecimal: Decimal { Decimal(string: montoTexto) ?? 0 }
    private var monto: Double { Double(montoTexto) ?? 0 }
    private var montoValido: Bool { montoDecimal > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                mainContent
                if mostrarExito { overlayExito }
            }
            .navigationTitle("Pagar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(rojo)
                }
            }
        }
    }

    // MARK: - Contenido principal

    private var mainContent: some View {
        VStack(spacing: 0) {
            stepIndicator
            ScrollView {
                VStack(spacing: 24) {
                    switch paso {
                    case 1: paso1Monto
                    case 2: paso2Metodo
                    case 3: paso3Datos
                    default: EmptyView()
                    }
                }
                .padding(20)
                .opacity(animarContenido ? 1 : 0)
                .offset(y: animarContenido ? 0 : 24)
            }
            botonAccion.padding(20)
        }
        .background(fondo)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
                animarContenido = true
            }
        }
        .onChange(of: paso) { _, _ in
            animarContenido = false
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.05)) {
                animarContenido = true
            }
        }
    }

    // MARK: - Step indicator

    private var stepIndicator: some View {
        HStack(spacing: 4) {
            ForEach(1...3, id: \.self) { n in
                Capsule()
                    .fill(n <= paso ? verde : arena.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: 4)
                    .animation(.easeInOut(duration: 0.3), value: paso)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Paso 1

    private var paso1Monto: some View {
        VStack(spacing: 20) {
            Text("¿Cuánto vas a pagar?")
                .font(.title2.weight(.semibold))
                .foregroundStyle(oscuro)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(monto == 0 ? "$0.00" : monto.formatted(.currency(code: "MXN")))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(montoValido ? rojo : oscuro.opacity(0.3))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(montoValido ? rojo.opacity(0.4) : arena.opacity(0.4), lineWidth: 1.5)
                )
                .animation(.easeInOut(duration: 0.2), value: montoValido)

            tecladoNumerico
        }
    }

    private var tecladoNumerico: some View {
        let teclas: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            [".", "0", "⌫"]
        ]
        return VStack(spacing: 12) {
            ForEach(teclas, id: \.self) { fila in
                HStack(spacing: 12) {
                    ForEach(fila, id: \.self) { tecla in
                        Button { presionarTecla(tecla) } label: {
                            Text(tecla)
                                .font(.title2.weight(.medium))
                                .foregroundStyle(tecla == "⌫" ? rojo : oscuro)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white.opacity(0.8),
                                            in: RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(arena.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
    }

    private func presionarTecla(_ tecla: String) {
        switch tecla {
        case "⌫":
            if !montoTexto.isEmpty { montoTexto.removeLast() }
        case ".":
            if !montoTexto.contains(".") { montoTexto += "." }
        default:
            if let punto = montoTexto.firstIndex(of: "."),
               montoTexto.distance(from: punto, to: montoTexto.endIndex) > 2 { return }
            montoTexto += tecla
        }
    }

    // MARK: - Paso 2

    private var paso2Metodo: some View {
        VStack(spacing: 20) {
            Text("¿Cómo vas a pagar?")
                .font(.title2.weight(.semibold))
                .foregroundStyle(oscuro)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(monto.formatted(.currency(code: "MXN")))
                .font(.headline)
                .foregroundStyle(rojo)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                ForEach(MetodoPago.allCases) { metodoCard($0) }
            }
        }
    }

    private func metodoCard(_ metodo: MetodoPago) -> some View {
        let seleccionado = metodoSeleccionado == metodo
        return Button {
            withAnimation(.spring(response: 0.3)) { metodoSeleccionado = metodo }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: metodo.systemImage)
                    .font(.title2)
                    .foregroundStyle(seleccionado ? verde : arenaOscuro)
                    .frame(width: 32)
                Text(metodo.rawValue)
                    .font(.body.weight(.medium))
                    .foregroundStyle(oscuro)
                Spacer()
                Image(systemName: seleccionado ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(seleccionado ? verde : arena)
            }
            .padding(16)
            .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(seleccionado ? verde : arena.opacity(0.4), lineWidth: 2)
            }
        }
        .scaleEffect(seleccionado ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: seleccionado)
    }

    // MARK: - Paso 3

    private var paso3Datos: some View {
        VStack(spacing: 20) {
            if metodoSeleccionado == .applePay { applePayView }
            else { transferenciaView }
        }
    }

    private var applePayView: some View {
        VStack(spacing: 24) {
            Text("Confirmar con Apple Pay")
                .font(.title2.weight(.semibold))
                .foregroundStyle(oscuro)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 60))
                    .foregroundStyle(oscuro)
                Text("Usa Face ID o Touch ID para autorizar el pago")
                    .font(.subheadline)
                    .foregroundStyle(oscuro.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(arena.opacity(0.4), lineWidth: 1)
            )

            resumenPago
        }
    }

    private var transferenciaView: some View {
        VStack(spacing: 16) {
            Text("Datos de transferencia")
                .font(.title2.weight(.semibold))
                .foregroundStyle(oscuro)
                .frame(maxWidth: .infinity, alignment: .leading)

            resumenPago

            VStack(spacing: 12) {
                campoTransferencia(titulo: "CLABE", placeholder: "18 dígitos", texto: $clabe)
                    .keyboardType(.numberPad)
                campoTransferencia(titulo: "Banco", placeholder: "Ej. BBVA, Banorte...", texto: $banco)
                campoTransferencia(titulo: "Concepto", placeholder: "Descripción del pago", texto: $concepto)
            }
        }
    }

    private func campoTransferencia(titulo: String, placeholder: String, texto: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo)
                .font(.caption.weight(.medium))
                .foregroundStyle(arenaOscuro)
            TextField(placeholder, text: texto)
                .foregroundStyle(oscuro)
                .padding(12)
                .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(arena.opacity(0.4), lineWidth: 1)
                )
        }
    }

    private var resumenPago: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total a pagar")
                    .font(.caption)
                    .foregroundStyle(arenaOscuro)
                Text(monto.formatted(.currency(code: "MXN")))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(rojo)
            }
            Spacer()
            Text(metodoSeleccionado?.rawValue ?? "")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(verde.opacity(0.12), in: Capsule())
                .foregroundStyle(verde)
        }
        .padding(14)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(arena.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Botón

    private var botonAccion: some View {
        Button { accionPrincipal() } label: {
            Group {
                if procesando {
                    ProgressView().tint(.white)
                } else {
                    Text(labelBoton).font(.body.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                botonHabilitado ? (paso == 3 ? rojo : verde) : arena.opacity(0.4),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .foregroundStyle(.white)
        }
        .disabled(!botonHabilitado || procesando)
        .animation(.easeInOut(duration: 0.2), value: botonHabilitado)
    }

    private var labelBoton: String {
        switch paso {
        case 1: return "Continuar"
        case 2: return "Seleccionar método"
        case 3: return "Confirmar pago"
        default: return "Continuar"
        }
    }

    private var botonHabilitado: Bool {
        switch paso {
        case 1: return montoValido
        case 2: return metodoSeleccionado != nil
        case 3:
            if metodoSeleccionado == .transferencia {
                return !clabe.isEmpty && !banco.isEmpty
            }
            return true
        default: return false
        }
    }

    private func accionPrincipal() {
        if paso < 3 {
            withAnimation(.spring(response: 0.4)) { paso += 1 }
        } else {
            confirmarPago()
        }
    }

    // MARK: - Confirmar pago

    private func confirmarPago() {
        procesando = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let metodo = metodoSeleccionado ?? .applePay
            let sale = Sale(
                amount: -montoDecimal,
                date: .now,
                paymentMethod: metodo.paymentMethod,
                items: []
            )
            context.insert(sale)
            try? context.save()

            procesando = false
            withAnimation(.spring(response: 0.4)) { mostrarExito = true }
        }
    }

    // MARK: - Overlay éxito

    private var overlayExito: some View {
        ZStack {
            fondo.opacity(0.97).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(verde.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Circle()
                        .strokeBorder(verde.opacity(0.3), lineWidth: 2)
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(verde)
                }
                .scaleEffect(mostrarExito ? 1 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: mostrarExito)

                Text("¡Pago exitoso!")
                    .font(.title.weight(.bold))
                    .foregroundStyle(oscuro)

                Text(monto.formatted(.currency(code: "MXN")))
                    .font(.title2)
                    .foregroundStyle(rojo)

                Text("Vía \(metodoSeleccionado?.rawValue ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(arenaOscuro)

                Button { dismiss() } label: {
                    Text("Listo")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(verde, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.top, 8)
            }
            .padding(32)
            .opacity(mostrarExito ? 1 : 0)
            .offset(y: mostrarExito ? 0 : 30)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: mostrarExito)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
