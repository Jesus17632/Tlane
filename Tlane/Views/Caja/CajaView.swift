// Renombrado de CajaView → UserView

import SwiftUI
import SwiftData
import Charts

struct UserView: View {
  @Environment(\.modelContext) private var context
  @State private var viewModel: CajaViewModel?

  var body: some View {
    ZStack {
      Color.tlaneBackground.ignoresSafeArea()

      if let viewModel {
        content(vm: viewModel)
      } else {
        ProgressView()
      }
    }
    .navigationTitle("Mi Perfil")
    .onAppear {
      if viewModel == nil {
        viewModel = CajaViewModel(context: context)
      }
    }
  }

  @ViewBuilder
  private func content(vm: CajaViewModel) -> some View {
    ScrollView {
      VStack(spacing: 20) {
        avatarSection
        totalCard(vm: vm)
        ingresosChart(vm: vm)
        desgloseSection(vm: vm)
        operacionesCard(vm: vm)
        historicoPlaceholder
      }
      .padding()
    }
  }

  // MARK: - Avatar

  private var avatarSection: some View {
    VStack(spacing: 10) {
      ZStack {
        Circle()
          .fill(Color.tlaneGreen.opacity(0.15))
          .frame(width: 90, height: 90)

        Circle()
          .strokeBorder(Color.tlaneGreen.opacity(0.4), lineWidth: 2)
          .frame(width: 90, height: 90)

        Image(systemName: "person.crop.circle.fill")
          .font(.system(size: 64))
          .foregroundStyle(Color.tlaneGreen)
      }

      Text("Mi cuenta")
        .font(.title2.weight(.bold))

      Text("Vendedor independiente")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
  }

  // MARK: - Total del mes

  private func totalCard(vm: CajaViewModel) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Total del mes")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(vm.monthLabel)
        .font(.caption)
        .foregroundStyle(.tertiary)
      Text(vm.totalMes.formatted(.currency(code: "MXN")))
        .font(.system(size: 44, weight: .bold, design: .rounded))
        .foregroundStyle(Color.tlaneGreen)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
        .padding(.top, 4)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(in: RoundedRectangle(cornerRadius: 20))
  }

  // MARK: - Gráfica ingresos por día

  private func ingresosChart(vm: CajaViewModel) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Ingresos por día")
        .font(.headline)

      if vm.ingresosPorDia.isEmpty {
        HStack {
          Image(systemName: "chart.bar.xaxis")
            .foregroundStyle(.secondary)
          Text("Sin datos este mes")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
      } else {
        Chart {
          ForEach(vm.ingresosPorDia, id: \.dia) { punto in
            BarMark(
              x: .value("Día", punto.dia, unit: .day),
              y: .value("Ingreso", punto.total as Decimal)
            )
            .foregroundStyle(Color.tlaneGreen.gradient)
            .cornerRadius(4)
          }
        }
        .chartXAxis {
          AxisMarks(values: .stride(by: .day, count: 5)) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
            AxisValueLabel(format: .dateTime.day())
              .font(.caption2)
          }
        }
        .chartYAxis {
          AxisMarks { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
            AxisValueLabel {
              if let d = value.as(Double.self) {
                Text("$\(Int(d))")
                  .font(.caption2)
              }
            }
          }
        }
        .frame(height: 180)
      }
    }
    .padding(16)
    .glassEffect(in: RoundedRectangle(cornerRadius: 20))
  }

  // MARK: - Desglose Efectivo vs Digital

  private func desgloseSection(vm: CajaViewModel) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Desglose por método")
        .font(.headline)

      VStack(spacing: 10) {
        metodoRow(
          titulo: "Efectivo",
          systemImage: "banknote",
          color: .tlaneEarth,
          monto: vm.totalEfectivoMes,
          ratio: vm.efectivoRatio
        )
        metodoRow(
          titulo: "Digital",
          systemImage: "wave.3.right.circle.fill",
          color: .tlaneGreen,
          monto: vm.totalDigitalMes,
          ratio: 1 - vm.efectivoRatio
        )
      }
    }
  }

  private func metodoRow(
    titulo: String,
    systemImage: String,
    color: Color,
    monto: Decimal,
    ratio: Double
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 12) {
        Image(systemName: systemImage)
          .font(.title3)
          .foregroundStyle(color)
          .frame(width: 28)

        Text(titulo)
          .font(.subheadline.weight(.semibold))

        Spacer()

        Text(monto.formatted(.currency(code: "MXN")))
          .font(.subheadline.weight(.bold))
          .foregroundStyle(color)
      }

      GeometryReader { geo in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 4)
            .fill(color.opacity(0.15))
          RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: geo.size.width * ratio)
        }
      }
      .frame(height: 6)

      Text("\(Int((ratio * 100).rounded()))% del total")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
  }

  // MARK: - Operaciones

  private func operacionesCard(vm: CajaViewModel) -> some View {
    HStack(spacing: 14) {
      Image(systemName: "list.bullet.rectangle")
        .font(.title2)
        .foregroundStyle(Color.tlaneGreen)

      VStack(alignment: .leading, spacing: 2) {
        Text("\(vm.operacionesMes)")
          .font(.title2.weight(.bold))
        Text(vm.operacionesMes == 1 ? "operación este mes" : "operaciones este mes")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(16)
    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
  }

  // MARK: - Placeholder histórico

  private var historicoPlaceholder: some View {
    VStack(spacing: 8) {
      Image(systemName: "clock.arrow.circlepath")
        .font(.title)
        .foregroundStyle(.secondary)
      Text("Historial completo próximamente")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding(24)
    .frame(maxWidth: .infinity)
    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
  }
}

#Preview {
  NavigationStack {
    UserView()
  }
  .modelContainer(AppContainer.preview)
}
