import SwiftUI

struct AddProductView: View {
  let onSave: (String, String, Decimal) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var name: String = ""
  @State private var category: String = "textil"
  @State private var price: Decimal = 0

  private let categories = ["textil", "barro", "madera", "joyería", "otro"]

  private var isValid: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty && price > 0
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Detalles de la pieza") {
          TextField("Nombre", text: $name)

          Picker("Categoría", selection: $category) {
            ForEach(categories, id: \.self) { cat in
              Text(cat.capitalized).tag(cat)
            }
          }

          TextField("Precio", value: $price, format: .currency(code: "MXN"))
            .keyboardType(.decimalPad)
        }

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
              price
            )
            dismiss()
          }
          .disabled(!isValid)
        }
      }
    }
  }
}

#Preview {
  AddProductView(onSave: { _, _, _ in })
}
