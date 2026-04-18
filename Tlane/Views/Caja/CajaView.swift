import SwiftUI
import SwiftData
import Charts
import PhotosUI

struct CajaView: View {
  @Environment(\.modelContext) private var context
  @State private var viewModel: CajaViewModel?

  // Persistencia del avatar y nombre
  @AppStorage("usuario_nombre") private var usuarioNombre: String = "Mi cuenta"
  @AppStorage("usuario_rol")    private var usuarioRol: String    = "Vendedor independiente"
  @AppStorage("usuario_avatar") private var avatarBase64: String  = ""

  @State private var photoItem: PhotosPickerItem?
  @State private var avatarImage: UIImage?
  @State private var editandoNombre = false
  @State private var editandoRol    = false
  @State private var nombreTemp     = ""
  @State private var rolTemp        = ""

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
      // Cargar avatar guardado
      if !avatarBase64.isEmpty,
         let data = Data(base64Encoded: avatarBase64),
         let img  = UIImage(data: data) {
        avatarImage = img
      }
    }
    .onChange(of: photoItem) { _, newItem in
      Task {
        if let data = try? await newItem?.loadTransferable(type: Data.self),
           let img  = UIImage(data: data) {
          avatarImage  = img
          avatarBase64 = data.base64EncodedString()
        }
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

  // MARK: - Avatar editable

  private var avatarSection: some View {
    VStack(spacing: 12) {

      // Foto / ícono con botón de edición
      PhotosPicker(selection: $photoItem, matching: .images) {
        ZStack(alignment: .bottomTrailing) {
          Group {
            if let img = avatarImage {
              Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 90, height: 90)
                .clipShape(Circle())
            } else {
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
            }
          }

          // Badge de edición
          ZStack {
            Circle()
              .fill(Color.tlaneGreen)
              .frame(width: 26, height: 26)
            Image(systemName: "camera.fill")
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(.white)
          }
          .offset(x: 2, y: 2)
        }
      }

      // Nombre editable
      Group {
        if editandoNombre {
          HStack(spacing: 6) {
            TextField("Nombre", text: $nombreTemp)
              .font(.title2.weight(.bold))
              .multilineTextAlignment(.center)
              .submitLabel(.done)
              .onSubmit {
                usuarioNombre  = nombreTemp.isEmpty ? "Mi cuenta" : nombreTemp
                editandoNombre = false
              }
            Button {
              usuarioNombre  = nombreTemp.isEmpty ? "Mi cuenta" : nombreTemp
              editandoNombre = false
            } label: {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.tlaneGreen)
            }
          }
          .padding(.horizontal, 32)
        } else {
          Button {
            nombreTemp     = usuarioNombre
            editandoNombre = true
          } label: {
            HStack(spacing: 4) {
              Text(usuarioNombre)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
              Image(systemName: "pencil")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }

      // Rol editable
      Group {
        if editandoRol {
          HStack(spacing: 6) {
            TextField("Descripción", text: $rolTemp)
              .font(.caption)
              .multilineTextAlignment(.center)
              .submitLabel(.done)
              .onSubmit {
                usuarioRol  = rolTemp.isEmpty ? "Vendedor independiente" : rolTemp
                editandoRol = false
              }
            Button {
              usuarioRol  = rolTemp.isEmpty ? "Vendedor independiente" : rolTemp
              editandoRol = false
            } label: {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.tlaneGreen)
                .font(.caption)
            }
          }
          .padding(.horizontal, 40)
        } else {
          Button {
            rolTemp     = usuarioRol
            editandoRol = true
          } label: {
            HStack(spacing: 4) {
              Text(usuarioRol)
                .font(.caption)
                .foregroundStyle(.secondary)
              Image(systemName: "pencil")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            }
          }
        }
      }
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
              y: .value("Ingreso", NSDecimalNumber(decimal: punto.total).doubleValue)
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
    CajaView()
  }
  .modelContainer(AppContainer.preview)
}
