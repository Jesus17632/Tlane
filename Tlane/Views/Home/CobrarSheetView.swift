//
//  CobrarSheetView.swift
//  Tlane
//
//  Created by Dev Jr.16 on 18/04/26.
//

import SwiftUI
import SwiftData

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

// MARK: - ViewModel / Acción

typealias OnVentaRegistrada = (Double, TipoCobro) -> Void

// MARK: - View Principal

struct CobrarSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let onVentaRegistrada: OnVentaRegistrada

    @State private var montoTexto: String = ""
    @State private var tipoSeleccionado: TipoCobro? = nil
    @State private var paso: Int = 1           // 1: monto, 2: tipo, 3: simulación
    @State private var estadoSimulacion: EstadoSim = .esperando
    @State private var mostrarExito = false

    private var monto: Double { Double(montoTexto) ?? 0 }
    private var montoValido: Bool { monto > 0 }

    enum EstadoSim { case esperando, procesando, aprobado }

    var body: some View {
        NavigationStack {
            ZStack {
                mainContent
                if mostrarExito { overlayExito }
            }
            .navigationTitle("Cobrar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    // MARK: - Contenido

    private var mainContent: some View {
        VStack(spacing: 0) {
            stepIndicator

            ScrollView {
                VStack(spacing: 24) {
                    switch paso {
                    case 1: paso1Monto
                    case 2: paso2TipoCobro
                    case 3: paso3Simulacion
                    default: EmptyView()
                    }
                }
                .padding(20)
            }

            if paso < 3 {
                botonAccion.padding(20)
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

    // MARK: - Paso 1: Monto

    private var paso1Monto: some View {
        VStack(spacing: 20) {
            Text("¿Cuánto vas a cobrar?")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(monto == 0 ? "$0.00" : monto.formatted(.currency(code: "MXN")))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(montoValido ? Color.tlaneGreen : .secondary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16))

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
            if let punto = montoTexto.firstIndex(of: "."),
               montoTexto.distance(from: punto, to: montoTexto.endIndex) > 2 { return }
            montoTexto += tecla
        }
    }

    // MARK: - Paso 2: Tipo de cobro

    private var paso2TipoCobro: some View {
        VStack(spacing: 20) {
            Text("¿Cómo quieres cobrar?")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(monto.formatted(.currency(code: "MXN")))
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                ForEach(TipoCobro.allCases) { tipo in
                    tipoCobro(tipo)
                }
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

    // Tap to Pay
    private var simTapToPay: some View {
        VStack(spacing: 28) {
            Text(monto.formatted(.currency(code: "MXN")))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Color.tlaneGreen)

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
                Button {
                    simularPago()
                } label: {
                    Text("Simular cobro")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.tlaneGreen, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.top, 8)
    }

    // QR / CoDi
    private var simQR: some View {
        VStack(spacing: 24) {
            Text(monto.formatted(.currency(code: "MXN")))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Color.tlaneGreen)

            // QR generado con símbolo del sistema como placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 200, height: 200)

                Image(systemName: "qrcode")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .foregroundStyle(.primary)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.tlaneGreen, lineWidth: 2)
            )

            Text(estadoSimulacion == .esperando
                 ? "El cliente escanea este código con CoDi o su app bancaria"
                 : estadoSimulacion == .procesando ? "Esperando confirmación..."
                 : "¡Pago recibido!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if estadoSimulacion == .esperando {
                Button {
                    simularPago()
                } label: {
                    Text("Confirmar escaneo")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.tlaneGreen, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // Efectivo
    private var simEfectivo: some View {
        VStack(spacing: 28) {
            Text(monto.formatted(.currency(code: "MXN")))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Color.tlaneGreen)

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 140, height: 140)
                Image(systemName: "banknote")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
            }

            Text("Recibe el efectivo del cliente y confirma el cobro.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if estadoSimulacion == .esperando {
                Button {
                    simularPago()
                } label: {
                    Text("Efectivo recibido")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.tlaneGreen, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
            }

            if estadoSimulacion == .procesando {
                ProgressView("Registrando venta...")
                    .tint(Color.tlaneGreen)
            }
        }
    }

    // MARK: - Simulación de cobro

    private func simularPago() {
        withAnimation { estadoSimulacion = .procesando }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.spring(response: 0.4)) {
                estadoSimulacion = .aprobado
                mostrarExito = true
            }
            onVentaRegistrada(monto, tipoSeleccionado ?? .efectivo)
        }
    }

    // MARK: - Botón de acción (pasos 1 y 2)

    private var botonAccion: some View {
        Button {
            withAnimation(.spring(response: 0.4)) { paso += 1 }
        } label: {
            Text(paso == 1 ? "Continuar" : "Ir a cobrar")
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
        paso == 1 ? montoValido : tipoSeleccionado != nil
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

                Text(monto.formatted(.currency(code: "MXN")))
                    .font(.title2)
                    .foregroundStyle(.secondary)

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
}
