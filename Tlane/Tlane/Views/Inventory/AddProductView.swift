import SwiftUI

struct AddProductView: View {
    let onSave: (String, String, Decimal, Data?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String     = ""
    @State private var category: String = "textil"
    @State private var price: Decimal   = 0
    @State private var imageData: Data?

    @State private var isShowingCamera    = false
    @State private var isClassifying      = false
    @State private var classificationHint: ClassificationResult?
    @State private var classifierError: String?

    // Animaciones
    @State private var fotoVisible   = false
    @State private var campoVisible  = false
    @State private var guardandoPulse = false

    private let categories = ["textil", "barro", "madera", "joyería", "otro"]
    private let classifier  = ProductClassifierService()

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && price > 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color.tlaneGreen.opacity(0.04)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        fotoCard
                        detallesCard
                        piezaUnicaCard
                        Spacer(minLength: 40)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Nueva pieza")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        guardarPieza()
                    } label: {
                        Text("Guardar")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isValid ? Color.tlaneGreen : Color(.systemGray3))
                            .scaleEffect(guardandoPulse ? 0.92 : 1.0)
                            .animation(.spring(response: 0.25), value: guardandoPulse)
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker { image in handlePickedImage(image) }
                    .ignoresSafeArea()
            }
            .onAppear { animarEntrada() }
        }
    }

    // MARK: - Foto card

    private var fotoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: "camera.fill", titulo: "Foto de la pieza")

            if let data = imageData, let uiImage = UIImage(data: data) {
                VStack(spacing: 14) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.tlaneGreen.opacity(0.25), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))

                    classificationStatusView

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        isShowingCamera = true
                    } label: {
                        Label("Tomar otra foto", systemImage: "camera.rotate")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.tlaneGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.tlaneGreen.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .animation(.spring(response: 0.45), value: imageData != nil)

            } else {
                // Botón vacío para tomar foto
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    isShowingCamera = true
                } label: {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.tlaneGreen.opacity(0.1))
                                .frame(width: 72, height: 72)
                            Circle()
                                .strokeBorder(Color.tlaneGreen.opacity(0.3),
                                              style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                .frame(width: 72, height: 72)
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(Color.tlaneGreen)
                        }
                        VStack(spacing: 3) {
                            Text("Tomar foto")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("El Consejero sugerirá la categoría")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(Color.tlaneGreen.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.tlaneGreen.opacity(0.2),
                                          style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 20))
        .opacity(fotoVisible ? 1 : 0)
        .offset(y: fotoVisible ? 0 : 18)
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: fotoVisible)
    }

    // MARK: - Estado clasificación

    @ViewBuilder
    private var classificationStatusView: some View {
        if isClassifying {
            HStack(spacing: 10) {
                ProgressView().tint(Color.tlaneGreen)
                Text("Analizando foto…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.tlaneGreen.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 12))
            .transition(.scale(scale: 0.95).combined(with: .opacity))

        } else if let hint = classificationHint {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.tlaneGreen)
                        .symbolEffect(.pulse)
                    Text("Sugerencia:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(hint.category.capitalized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.tlaneGreen)
                    Spacer()
                    // Confianza como badge
                    Text("\(hint.confidencePercent)%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.tlaneGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.tlaneGreen.opacity(0.12), in: Capsule())
                }

                if category != hint.category {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3)) { category = hint.category }
                    } label: {
                        Label("Aceptar sugerencia", systemImage: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.tlaneGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.tlaneGreen.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
            }
            .padding(12)
            .background(Color.tlaneGreen.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 12))
            .transition(.scale(scale: 0.95).combined(with: .opacity))
            .animation(.spring(response: 0.38), value: category)

        } else if let error = classifierError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .padding(10)
            .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }

    // MARK: - Detalles card

    private var detallesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "tag.fill", titulo: "Detalles")

            // Nombre
            VStack(alignment: .leading, spacing: 6) {
                Text("Nombre")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Ej: Huipil bordado a mano", text: $name)
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                name.isEmpty ? Color.clear : Color.tlaneGreen.opacity(0.4),
                                lineWidth: 1
                            )
                    }
                    .animation(.easeInOut(duration: 0.2), value: name.isEmpty)
            }

            // Categoría
            VStack(alignment: .leading, spacing: 6) {
                Text("Categoría")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3)) { category = cat }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: categoryIcon(cat))
                                        .font(.caption)
                                    Text(cat.capitalized)
                                        .font(.subheadline.weight(.medium))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    category == cat
                                        ? Color.tlaneGreen
                                        : Color(.tertiarySystemGroupedBackground),
                                    in: Capsule()
                                )
                                .foregroundStyle(category == cat ? .white : .primary)
                                .overlay {
                                    Capsule()
                                        .strokeBorder(
                                            category == cat ? Color.clear : Color(.systemGray4),
                                            lineWidth: 1
                                        )
                                }
                                .scaleEffect(category == cat ? 1.04 : 1.0)
                            }
                            .animation(.spring(response: 0.3), value: category)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            // Precio
            VStack(alignment: .leading, spacing: 6) {
                Text("Precio")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text("MXN")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.tlaneGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(Color.tlaneGreen.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 10))

                    TextField("0.00", value: $price, format: .currency(code: "MXN"))
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(Color(.tertiarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    price > 0 ? Color.tlaneGreen.opacity(0.4) : Color.clear,
                                    lineWidth: 1
                                )
                        }
                        .animation(.easeInOut(duration: 0.2), value: price > 0)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 20))
        .opacity(campoVisible ? 1 : 0)
        .offset(y: campoVisible ? 0 : 18)
        .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.08), value: campoVisible)
    }

    // MARK: - Pieza única card

    private var piezaUnicaCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.tlaneGreen.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "star.fill")
                        .font(.body)
                        .foregroundStyle(Color.tlaneGreen)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Pieza única")
                        .font(.subheadline.weight(.semibold))
                    Text("Se marca como vendida al cobrar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.tlaneGreen)
                    .font(.title3)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
        .opacity(campoVisible ? 1 : 0)
        .offset(y: campoVisible ? 0 : 18)
        .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.14), value: campoVisible)
    }

    // MARK: - Helpers UI

    private func sectionHeader(icon: String, titulo: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.tlaneGreen)
            Text(titulo)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.tlaneGreen)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.tlaneGreen.opacity(0.1), in: Capsule())
    }

    private func categoryIcon(_ cat: String) -> String {
        switch cat {
        case "textil":  "tshirt.fill"
        case "barro":   "cup.and.saucer.fill"
        case "madera":  "tree.fill"
        case "joyería": "sparkles"
        default:        "tag.fill"
        }
    }

    // MARK: - Lógica

    private func guardarPieza() {
        guard isValid else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        guardandoPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guardandoPulse = false
            onSave(
                name.trimmingCharacters(in: .whitespaces),
                category,
                price,
                imageData
            )
            dismiss()
        }
    }

    private func animarEntrada() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation { fotoVisible  = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation { campoVisible = true }
        }
    }

    private func handlePickedImage(_ image: UIImage) {
        withAnimation(.spring(response: 0.45)) {
            imageData = image.jpegData(compressionQuality: 0.7)
        }
        classificationHint = nil
        classifierError    = nil
        isClassifying      = true

        Task {
            do {
                let result = try await classifier.classify(image: image)
                await MainActor.run {
                    withAnimation(.spring()) { classificationHint = result }
                    isClassifying = false
                    if result.category != "otro", result.confidence >= 0.25 {
                        withAnimation(.spring(response: 0.3)) { category = result.category }
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation { classifierError = "No se pudo analizar la foto." }
                    isClassifying = false
                }
            }
        }
    }
}

#Preview {
    AddProductView(onSave: { _, _, _, _ in })
}
