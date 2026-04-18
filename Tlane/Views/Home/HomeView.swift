import SwiftUI
import SwiftData

struct HomeView: View {
  @Environment(\.modelContext) private var context
  @State private var viewModel: HomeViewModel?
  @State private var mostrarTodasVentas = false

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        if let viewModel {
          cajaChicaSection(vm: viewModel)
          botonesSection
          ultimasVentasSection(vm: viewModel)
          consejeroSection
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 8)
    }
    .background(Color.tlaneBackground)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        NavigationLink(destination: CajaView()) {
          Image(systemName: "person.circle.fill")
            .font(.title2)
            .foregroundStyle(Color.tlaneGreen)
        }
      }
    }
    .onAppear {
      if viewModel == nil {
        viewModel = HomeViewModel(context: context)
      }
    }
  }

  // MARK: - Caja Chica (alineado al mismo nivel que botón usuario en toolbar)
  private func cajaChicaSection(vm: HomeViewModel) -> some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Caja Chica")
          .font(.largeTitle.weight(.bold))
          .foregroundStyle(.primary)
        Text("Hoy")
          .font(.caption)
          .foregroundStyle(.tertiary)
        Text(vm.cajaChica.formatted(.currency(code: "MXN")))
          .font(.largeTitle.weight(.bold))
          .foregroundStyle(Color.tlaneGreen)
          .minimumScaleFactor(0.6)
          .lineLimit(1)
      }
      Spacer()
    }
    .padding(.top, 4)
  }

  // MARK: - Botones de acción
  private var botonesSection: some View {
    HStack(alignment: .center, spacing: 12) {

      // Botón Caja Grande — alargado, mismo alto que los círculos
      Button {
        // acción caja grande
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "plus.circle.fill")
            .font(.title2.weight(.semibold))
          Text("Caja Grande")
            .font(.body.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: 70)
      }
      .buttonStyle(.borderedProminent)
      .tint(Color.tlaneGreen)
      .cornerRadius(16)

      // Pagar
      Button {
        // acción pagar
      } label: {
        VStack(spacing: 3) {
          Image(systemName: "arrow.up")
            .font(.title3.weight(.bold))
          Text("Pagar")
            .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(width: 70, height: 70)
        .background(Color.blue)
        .clipShape(Circle())
      }

      // Cobrar
      Button {
        // acción cobrar
      } label: {
        VStack(spacing: 3) {
          Image(systemName: "arrow.down")
            .font(.title3.weight(.bold))
          Text("Cobrar")
            .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(width: 70, height: 70)
        .background(Color.tlaneGreen)
        .clipShape(Circle())
      }
    }
  }

  // MARK: - Últimas ventas (desplegable)
  private func ultimasVentasSection(vm: HomeViewModel) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Últimas ventas")
        .font(.headline)

      if vm.ultimasVentas.isEmpty {
        emptyVentasRow
      } else {
        VStack(spacing: 8) {
          let visibles = mostrarTodasVentas
            ? vm.ultimasVentas
            : Array(vm.ultimasVentas.prefix(3))

          ForEach(visibles) { sale in
            ventaRow(sale: sale)
          }

          // Botón mostrar más / menos
          if vm.ultimasVentas.count > 3 {
            Button {
              withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                mostrarTodasVentas.toggle()
              }
            } label: {
              HStack(spacing: 6) {
                Text(mostrarTodasVentas ? "Ver menos" : "Ver más")
                  .font(.subheadline.weight(.medium))
                Image(systemName: mostrarTodasVentas
                      ? "chevron.up"
                      : "chevron.down")
                  .font(.caption.weight(.bold))
              }
              .foregroundStyle(Color.tlaneGreen)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
            }
            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
          }
        }
      }
    }
  }

  private var emptyVentasRow: some View {
    HStack {
      Image(systemName: "tray")
        .foregroundStyle(.secondary)
      Text("Aún no hay ventas hoy.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Spacer()
    }
    .padding(16)
    .frame(maxWidth: .infinity)
    .glassEffect(in: RoundedRectangle(cornerRadius: 16))
  }

  private func ventaRow(sale: Sale) -> some View {
    HStack(spacing: 12) {
      Image(systemName: sale.paymentMethod.systemImage)
        .font(.title3)
        .foregroundStyle(Color.tlaneGreen)
        .frame(width: 32)

      VStack(alignment: .leading, spacing: 2) {
        Text(sale.amount.formatted(.currency(code: "MXN")))
          .font(.body.weight(.semibold))
        Text(sale.paymentMethod.rawValue)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Text(sale.date.formatted(date: .omitted, time: .shortened))
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
  }

  // MARK: - Consejero
  private var consejeroSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Consejo del día")
        .font(.headline)
      FallbackConsejeroCardView()
    }
  }
}

#Preview {
  NavigationStack {
    HomeView()
  }
  .modelContainer(AppContainer.preview)
}
