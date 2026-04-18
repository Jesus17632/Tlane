import SwiftUI
import SwiftData

struct HomeView: View {
  @Environment(\.modelContext) private var context
  @State private var viewModel: HomeViewModel?

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        if let viewModel {
          cajasSection(vm: viewModel)
          ultimasVentasSection(vm: viewModel)
          consejeroSection
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 8)
    }
    .background(Color.tlaneBackground)
    .navigationTitle("Inicio")
    .onAppear {
      if viewModel == nil {
        viewModel = HomeViewModel(context: context)
      }
    }
  }

  // MARK: - Cajas

  private func cajasSection(vm: HomeViewModel) -> some View {
    HStack(spacing: 12) {
      cajaCard(
        titulo: "Caja Chica",
        subtitulo: "Hoy",
        monto: vm.cajaChica
      )
      cajaCard(
        titulo: "Caja Grande",
        subtitulo: "Histórico",
        monto: vm.cajaGrande
      )
    }
  }

  private func cajaCard(titulo: String, subtitulo: String, monto: Decimal) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(titulo)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(subtitulo)
        .font(.caption)
        .foregroundStyle(.tertiary)
      Text(monto.formatted(.currency(code: "MXN")))
        .font(.largeTitle.weight(.bold))
        .foregroundStyle(Color.tlaneGreen)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(in: RoundedRectangle(cornerRadius: 20))
  }

  // MARK: - Últimas ventas

  private func ultimasVentasSection(vm: HomeViewModel) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Últimas ventas")
        .font(.headline)

      if vm.ultimasVentas.isEmpty {
        emptyVentasRow
      } else {
        VStack(spacing: 8) {
          ForEach(vm.ultimasVentas) { sale in
            ventaRow(sale: sale)
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

      ConsejeroCardView()
    }
  }
}

#Preview {
  NavigationStack {
    HomeView()
  }
  .modelContainer(AppContainer.preview)
}
