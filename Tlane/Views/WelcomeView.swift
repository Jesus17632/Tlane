import SwiftUI
import PhotosUI

struct WelcomeView: View {
    @AppStorage("onboarding_completo") private var onboardingCompleto: Bool = false
    @AppStorage("usuario_nombre")      private var usuarioNombre: String   = "Mi cuenta"
    @AppStorage("usuario_rol")         private var usuarioRol: String      = "Vendedor independiente"
    @AppStorage("usuario_avatar")      private var avatarBase64: String    = ""

    @State private var paso: Int = 1
    @State private var nombre: String = ""
    @State private var negocio: String = ""
    @State private var emojiInput: String = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var avatarData: Data?
    @FocusState private var campoActivo: Campo?

    enum Campo { case nombre, negocio }

    private let verde = Color(red: 0.18, green: 0.47, blue: 0.20)

    private var nombreValido: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color.tlaneBackground.ignoresSafeArea()

            Group {
                switch paso {
                case 1: pantallaBienvenida
                case 2: pantallaPerfil
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal:   .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: paso)
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let img  = UIImage(data: data) {
                    avatarImage = img
                    avatarData  = data
                }
            }
        }
    }

    // MARK: - Pantalla 1: Bienvenida

    private var pantallaBienvenida: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("Inicio")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .padding(.bottom, 10)

            VStack(spacing: 5) {
                Text("Bienvenido a")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("Tlane")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(verde)

                Text("Tu negocio, en la palma de tu mano.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                feature(icono: "camera.fill",
                        titulo: "Escanea tus piezas",
                        descripcion: "Identifica artesanías con la cámara.")
                feature(icono: "arrow.down.circle.fill",
                        titulo: "Cobra con un toque",
                        descripcion: "Efectivo, transferencia o tap to pay.")
                feature(icono: "chart.bar.fill",
                        titulo: "Controla tu caja",
                        descripcion: "Ingresos y egresos, siempre al día.")
            }
            .padding(.horizontal, 32)

            Spacer()

            botonPrincipal(titulo: "Continuar") { paso = 2 }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
    }

    private func feature(icono: String, titulo: String, descripcion: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(verde.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icono)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(verde)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.subheadline.weight(.semibold))
                Text(descripcion).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Pantalla 2: Perfil

    private var pantallaPerfil: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                Button { paso = 1 } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(verde)
                        .frame(width: 44, height: 44)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            // Contenido scrolleable — ignora teclado sin saltar
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 6) {
                        Text("Crea tu perfil")
                            .font(.largeTitle.weight(.bold))
                        Text("Nos ayuda a personalizar tu experiencia.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    avatarSelector

                    VStack(spacing: 16) {
                        campoTexto(titulo: "Nombre",
                                   placeholder: "¿Cómo te llamas?",
                                   texto: $nombre,
                                   campo: .nombre,
                                   requerido: true)

                        campoTexto(titulo: "Nombre del negocio",
                                   placeholder: "Ej. Artesanías Guadalupe",
                                   texto: $negocio,
                                   campo: .negocio,
                                   requerido: false)
                    }
                    .padding(.horizontal, 24)

                    // Espacio extra para que el botón no tape los campos
                    Spacer(minLength: 100)
                }
            }
            .scrollDismissesKeyboard(.interactively) // ← desliza para cerrar teclado
            .animation(nil, value: campoActivo)      // ← evita saltos de animación

            // Botón fijo abajo
            botonPrincipal(
                titulo: "Comenzar",
                activo: nombreValido,
                accion: guardarYEntrar
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 8)
            .background(Color.tlaneBackground) // ← tapa el scroll por debajo
        }
    }

    // MARK: - Avatar selector

    private var avatarSelector: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                if let img = avatarImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(verde.opacity(0.15))
                            .frame(width: 120, height: 120)
                        Circle()
                            .strokeBorder(verde.opacity(0.4),
                                          style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .frame(width: 120, height: 120)
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(verde)
                            Text("Añadir foto")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(verde)
                        }
                    }
                }

                if avatarImage != nil {
                    ZStack {
                        Circle().fill(verde).frame(width: 32, height: 32)
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 2, y: 2)
                }
            }
        }
    }

    // MARK: - Campo de texto

    private func campoTexto(
        titulo: String,
        placeholder: String,
        texto: Binding<String>,
        campo: Campo,
        requerido: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(titulo)
                    .font(.subheadline.weight(.semibold))
                if requerido {
                    Text("*").font(.subheadline.weight(.bold)).foregroundStyle(.red)
                } else {
                    Text("(opcional)").font(.caption).foregroundStyle(.tertiary)
                }
                Spacer()
            }

            TextField(placeholder, text: texto)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 12))
                .focused($campoActivo, equals: campo)
                .submitLabel(campo == .nombre ? .next : .done)
                .onSubmit {
                    if campo == .nombre { campoActivo = .negocio }
                    else { campoActivo = nil }
                }
        }
    }

    // MARK: - Botón reutilizable

    @ViewBuilder
    private func botonPrincipal(
        titulo: String,
        activo: Bool = true,
        accion: @escaping () -> Void
    ) -> some View {
        Button(action: accion) {
            Text(titulo)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(activo ? verde : Color(.systemGray4),
                            in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
        .disabled(!activo)
        .animation(.easeInOut(duration: 0.2), value: activo)
    }

    // MARK: - Guardar y entrar

    private func guardarYEntrar() {
        campoActivo = nil // cierra teclado antes de salir
        let nombreLimpio  = nombre.trimmingCharacters(in: .whitespaces)
        let negocioLimpio = negocio.trimmingCharacters(in: .whitespaces)

        usuarioNombre = nombreLimpio.isEmpty ? "Mi cuenta" : nombreLimpio
        usuarioRol    = negocioLimpio.isEmpty ? "Vendedor independiente" : negocioLimpio

        if let data = avatarData {
            avatarBase64 = data.base64EncodedString()
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            onboardingCompleto = true
        }
    }
}

#Preview {
    WelcomeView()
}
