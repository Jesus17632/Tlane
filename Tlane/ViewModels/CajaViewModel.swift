import Foundation
import SwiftData

@Observable
@MainActor
final class CajaViewModel {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  private var allSales: [Sale] {
    let descriptor = FetchDescriptor<Sale>(
      sortBy: [SortDescriptor(\.date, order: .reverse)]
    )
    return (try? context.fetch(descriptor)) ?? []
  }

  // MARK: - Mes en curso

  private var currentMonthSales: [Sale] {
    let calendar = Calendar.current
    let now = Date.now
    guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else {
      return []
    }
    return allSales.filter { $0.date >= monthStart }
  }

  var totalMes: Decimal {
    currentMonthSales.reduce(Decimal(0)) { $0 + $1.amount }
  }

  var totalEfectivoMes: Decimal {
    currentMonthSales
      .filter { $0.paymentMethod == .cash }
      .reduce(Decimal(0)) { $0 + $1.amount }
  }

  var totalDigitalMes: Decimal {
    currentMonthSales
      .filter { $0.paymentMethod == .digital }
      .reduce(Decimal(0)) { $0 + $1.amount }
  }

  var operacionesMes: Int {
    currentMonthSales.count
  }

  /// Porcentaje de efectivo sobre el total del mes (0.0 - 1.0).
  var efectivoRatio: Double {
    guard totalMes > 0 else { return 0 }
    let efectivo = NSDecimalNumber(decimal: totalEfectivoMes).doubleValue
    let total = NSDecimalNumber(decimal: totalMes).doubleValue
    return efectivo / total
  }

  /// Nombre del mes en curso capitalizado ("Abril 2026").
  var monthLabel: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_MX")
    formatter.dateFormat = "LLLL yyyy"
    return formatter.string(from: .now).capitalized
  }
}
