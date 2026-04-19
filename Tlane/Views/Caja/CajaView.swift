import SwiftUI
import SwiftData
import Charts
import PhotosUI

struct IngresoDia {
  let dia: Date
  let total: Decimal
}

struct CajaView: View {
  @Environment(\.modelContext) private var context

  // MARK: - @Query reactivo (reemplaza CajaViewModel)
  @Query(sort: \Sale.date, order: .reverse) private var allSales: [Sale]

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

  // MARK: - Derivados reactivos

  private var currentMonthSales: [Sale] {
    let calendar = Calendar.current
    guard let monthStart = calendar.dateInterval(of: .month, for: .now)?.start else {
      return []
    }
    return allSales.filter { $0.date >= monthStart }
  }

  private var totalMes: Decimal {
    currentMonthSales.reduce(Decimal(0)) { $0 + $1.amount }
  }

    private var totalEfectivoMes: Decimal {
      currentMonthSales
        .filter { $0.paymentMethod == .cash && $0.amount > 0 }
        .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var totalDigitalMes: Decimal {
      currentMonthSales
        .filter { $0.paymentMethod == .digital && $0.amount > 0 }
        .reduce(Decimal(0)) { $0 + $1.amount }
    }

  private var operacionesMes: Int { currentMonthSales.count }

  private var efectivoRatio: Double {
    guard totalMes > 0 else { return 0 }
    let efectivo = NSDecimalNumber(decimal: totalEfectivoMes).doubleValue
    let total = NSDecimalNumber(decimal: totalMes).doubleValue
    return efectivo / total
  }

  private var monthLabel: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_MX")
    formatter.dateFormat = "LLLL yyyy"
    return formatter.string(from: .now).capitalized
  }

  private var ingresosPorDia: [IngresoDia] {
    let calendar = Calendar.current
    var grupos: [Date: Decimal] = [:]
    for sale in currentMonthSales {
      let inicio = calendar.startOfDay(for: sale.date)
      grupos[inicio, default: Decimal(0)] += sale.amount
    }
    return grupos
      .map { IngresoDia(dia: $0.key, total: $0.value) }
      .sorted { $0.dia < $1.dia }
  }

  // MARK: - Body

  var body: some View {
    ZStack {
      Color.tlaneBackground.ignoresSafeArea()
      ScrollView {
        VStack(spacing: 20) {
          avatarSection
          totalCard
          ingresosChart
          desgloseSection
          operacionesCard
          historicoPlaceholder
        }
        .padding()
      }
    }
    .navigationTitle("Mi Perfil")
    .onAppear {
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

  // MARK: - Avatar

  private var avatarSection: some View {
    VStack(spacing: 12) {
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

  private var totalCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Total del mes")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(monthLabel)
        .font(.caption)
        .foregroundStyle(.tertiary)
      Text(totalMes.formatted(.currency(code: "MXN")))
        .font(.system(size: 44, weight: .bold, design: .rounded))
        .foregroundStyle(Color.tlaneGreen)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
        .padding(.top, 4)
        .contentTransition(.numericText())
        .animation(.easeInOut, value: totalMes)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(in: RoundedRectangle(cornerRadius: 20))
  }

  // MARK: - Gráfica

  private var ingresosChart: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Ingresos por día")
        .font(.headline)

      if ingresosPorDia.isEmpty {
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
          ForEach(ingresosPorDia, id: \.dia) { punto in
            BarMark(
              x: .value("Día", punto.dia, unit: .day),
              y: .value("Ingreso", NSDecimalNumber(decimal: punto.total).doubleValue)
            )
            .foregroundStyle(Color.tlaneGreen.gradient)
            .cornerRadius(4)
          }
        }
        .chartXAxis {
          AxisMarks(values: .stride(by: .day, count: 5)) { _ in
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

  // MARK: - Desglose

  private var desgloseSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Desglose por método")
        .font(.headline)

      VStack(spacing: 10) {
        metodoRow(
          titulo: "Efectivo",
          systemImage: "banknote",
          color: .tlaneEarth,
          monto: totalEfectivoMes,
          ratio: efectivoRatio
        )
        metodoRow(
          titulo: "Digital",
          systemImage: "wave.3.right.circle.fill",
          color: .tlaneGreen,
          monto: totalDigitalMes,
          ratio: 1 - efectivoRatio
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
          .contentTransition(.numericText())
          .animation(.easeInOut, value: monto)
      }

      GeometryReader { geo in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 4)
            .fill(color.opacity(0.15))
          RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: geo.size.width * ratio)
            .animation(.easeInOut(duration: 0.4), value: ratio)
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

  private var operacionesCard: some View {
    HStack(spacing: 14) {
      Image(systemName: "list.bullet.rectangle")
        .font(.title2)
        .foregroundStyle(Color.tlaneGreen)
      VStack(alignment: .leading, spacing: 2) {
        Text("\(operacionesMes)")
          .font(.title2.weight(.bold))
          .contentTransition(.numericText())
          .animation(.easeInOut, value: operacionesMes)
        Text(operacionesMes == 1 ? "operación este mes" : "operaciones este mes")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(16)
    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
  }

  // MARK: - Placeholder

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
