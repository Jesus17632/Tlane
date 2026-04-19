//
//  PagarSheetView.swift
//  Tlane
//
//  Created by Dev Jr.16 on 18/04/26.
//
import SwiftUI

// MARK: - Modelos

enum MetodoPago: String, CaseIterable, Identifiable {
    case applePay   = "Apple Pay"
    case transferencia = "Transferencia"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .applePay:      return "apple.logo"
        case .transferencia: return "arrow.left.arrow.right.circle.fill"
        }
    }
}

// MARK: - View Principal

struct PagarSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var montoTexto: String = ""
    @State private var metodoSeleccionado: MetodoPago? = nil
    @State private var clabe: String = ""
    @State private var banco: String = ""
    @State private var concepto: String = ""
    @State private var paso: Int = 1          // 1: monto, 2: método, 3: datos/confirmar
    @State private var mostrarExito: Bool = false
    @State private var procesando: Bool = false

    private var monto: Double { Double(montoTexto) ?? 0 }
    private var montoValido: Bool { monto > 0 }

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
                }
            }
        }
    }

    // MARK: - Contenido principal

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Indicador de pasos
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
            }

            // Botón de acción
            botonAccion
                .padding(20)
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

    // MARK: - Paso 1: Monto

    private var paso1Monto: some View {
        VStack(spacing: 20) {
            Text("¿Cuánto vas a pagar?")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Display del monto
            VStack(spacing: 4) {
                Text(monto == 0 ? "$0.00" : monto.formatted(.currency(code: "MXN")))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(montoValido ? Color.tlaneGreen : .secondary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }

            // Teclado numérico
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
                        Button {
                            presionarTecla(tecla)
                        } label: {
                            Text(tecla)
                                .font(.title2.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(.secondarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 14))
                        }
                        .tint(.primary)
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
            // Limitar a 2 decimales
            if let punto = montoTexto.firstIndex(of: "."),
               montoTexto.distance(from: punto, to: montoTexto.endIndex) > 2 { return }
            montoTexto += tecla
        }
    }

    // MARK: - Paso 2: Método de pago

    private var paso2Metodo: some View {
        VStack(spacing: 20) {
            Text("¿Cómo vas a pagar?")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(monto.formatted(.currency(code: "MXN")))
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                ForEach(MetodoPago.allCases) { metodo in
                    metodoCard(metodo)
                }
            }
        }
    }

    private func metodoCard(_ metodo: MetodoPago) -> some View {
        let seleccionado = metodoSeleccionado == metodo
        return Button {
            withAnimation(.spring(response: 0.3)) {
                metodoSeleccionado = metodo
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: metodo.systemImage)
                    .font(.title2)
                    .foregroundStyle(seleccionado ? Color.tlaneGreen : .secondary)
                    .frame(width: 32)

                Text(metodo.rawValue)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

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

    // MARK: - Paso 3: Datos / Confirmar

    private var paso3Datos: some View {
        VStack(spacing: 20) {
            if metodoSeleccionado == .applePay {
                applePayView
            } else {
                transferenciaView
            }
        }
    }

    private var applePayView: some View {
        VStack(spacing: 24) {
            Text("Confirmar con Apple Pay")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 60))
                    .foregroundStyle(.primary)
                Text("Usa Face ID o Touch ID para autorizar el pago")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 20))

            resumenPago
        }
    }

    private var transferenciaView: some View {
        VStack(spacing: 16) {
            Text("Datos de transferencia")
                .font(.title2.weight(.semibold))
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
                .foregroundStyle(.secondary)
            TextField(placeholder, text: texto)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var resumenPago: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total a pagar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(monto.formatted(.currency(code: "MXN")))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.tlaneGreen)
            }
            Spacer()
            Text(metodoSeleccionado?.rawValue ?? "")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.tlaneGreen.opacity(0.12),
                            in: Capsule())
                .foregroundStyle(Color.tlaneGreen)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Botón de acción

    private var botonAccion: some View {
        Button {
            accionPrincipal()
        } label: {
            Group {
                if procesando {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(labelBoton)
                        .font(.body.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(botonHabilitado ? Color.tlaneGreen : Color(.systemGray4),
                        in: RoundedRectangle(cornerRadius: 16))
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
        // Simular delay de procesamiento
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            procesando = false
            withAnimation(.spring(response: 0.4)) {
                mostrarExito = true
            }
        }
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

                Text("¡Pago exitoso!")
                    .font(.title.weight(.bold))

                Text(monto.formatted(.currency(code: "MXN")))
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("Vía \(metodoSeleccionado?.rawValue ?? "")")
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
}
