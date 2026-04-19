import SwiftUI

struct AddProductView: View {
  let onSave: (String, String, Decimal, Data?) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var name: String = ""
  @State private var category: String = "textil"
  @State private var price: Decimal = 0
  @State private var imageData: Data?

  @State private var isShowingCamera = false
  @State private var isClassifying = false
  @State private var classificationHint: ClassificationResult?
  @State private var classifierError: String?

  private let categories = ["textil", "barro", "madera", "joyería", "otro"]
  private let classifier = ProductClassifierService()

  private var isValid: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty && price > 0
  }

  var body: some View {
    NavigationStack {
      Form {
        photoSection
        detailsSection
        uniqueItemSection
      }
      .navigationTitle("Nueva pieza")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancelar") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Guardar") {
            onSave(
              name.trimmingCharacters(in: .whitespaces),
              category,
              price,
              imageData
            )
            dismiss()
          }
          .disabled(!isValid)
        }
      }
      .sheet(isPresented: $isShowingCamera) {
        CameraPicker { image in
          handlePickedImage(image)
        }
        .ignoresSafeArea()
      }
    }
  }

  // MARK: - Secciones

  @ViewBuilder
  private var photoSection: some View {
    Section("Foto de la pieza") {
      if let data = imageData, let uiImage = UIImage(data: data) {
        VStack(spacing: 12) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))

          classificationStatusView

          Button {
            isShowingCamera = true
          } label: {
            Label("Tomar otra foto", systemImage: "camera.rotate")
          }
        }
      } else {
        Button {
          isShowingCamera = true
        } label: {
          HStack(spacing: 12) {
            Image(systemName: "camera.fill")
              .font(.title2)
              .foregroundStyle(Color.tlaneGreen)
            VStack(alignment: .leading, spacing: 2) {
              Text("Tomar foto")
                .font(.headline)
                .foregroundStyle(.primary)
              Text("El Consejero sugerirá la categoría")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
          }
          .padding(.vertical, 6)
        }
      }
    }
  }

  @ViewBuilder
  private var classificationStatusView: some View {
    if isClassifying {
      HStack(spacing: 10) {
        ProgressView()
        Text("Analizando foto…")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else if let hint = classificationHint {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          Image(systemName: "sparkles")
            .foregroundStyle(Color.tlaneGreen)
          Text("Sugerencia:")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text(hint.category.capitalized)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.tlaneGreen)
          Text("· \(hint.confidencePercent)%")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if category != hint.category {
          Button("Aceptar sugerencia") {
            category = hint.category
          }
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color.tlaneGreen)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else if let error = classifierError {
      Text(error)
        .font(.caption)
        .foregroundStyle(.red)
    }
  }

  private var detailsSection: some View {
    Section("Detalles") {
      TextField("Nombre", text: $name)

      Picker("Categoría", selection: $category) {
        ForEach(categories, id: \.self) { cat in
          Text(cat.capitalized).tag(cat)
        }
      }

      TextField("Precio", value: $price, format: .currency(code: "MXN"))
        .keyboardType(.decimalPad)
    }
  }

  private var uniqueItemSection: some View {
    Section {
      HStack {
        Text("Pieza única")
        Spacer()
        Text("Sí")
          .foregroundStyle(.secondary)
      }
    } footer: {
      Text("Las piezas únicas se marcan como vendidas al cobrarlas.")
    }
  }

  // MARK: - Flujo de clasificación

  private func handlePickedImage(_ image: UIImage) {
    // Comprimir a JPEG 0.7 — suficiente para UI y evita blobs gigantes en SwiftData
    imageData = image.jpegData(compressionQuality: 0.7)
    classificationHint = nil
    classifierError = nil
    isClassifying = true

    Task {
      do {
        let result = try await classifier.classify(image: image)
        await MainActor.run {
          classificationHint = result
          isClassifying = false
          // Auto-aplicar solo si el usuario no ha tocado el picker
          // y la confianza es razonable.
          if result.category != "otro", result.confidence >= 0.25 {
            category = result.category
          }
        }
      } catch {
        await MainActor.run {
          classifierError = "No se pudo analizar la foto."
          isClassifying = false
        }
      }
    }
  }
}

#Preview {
  AddProductView(onSave: { _, _, _, _ in })
}
