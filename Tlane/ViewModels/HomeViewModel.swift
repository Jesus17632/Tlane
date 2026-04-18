import Foundation
import SwiftData

@Observable
@MainActor
final class HomeViewModel {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  /// Ventas de hoy (desde las 00:00).
  var todaysSales: [Sale] {
    let start = Calendar.current.startOfDay(for: .now)
    let predicate = #Predicate<Sale> { $0.date >= start }
    let descriptor = FetchDescriptor<Sale>(
      predicate: predicate,
      sortBy: [SortDescriptor(\.date, order: .reverse)]
    )
    return (try? context.fetch(descriptor)) ?? []
  }

  /// Todas las ventas históricas.
  var allSales: [Sale] {
    let descriptor = FetchDescriptor<Sale>(
      sortBy: [SortDescriptor(\.date, order: .reverse)]
    )
    return (try? context.fetch(descriptor)) ?? []
  }

  var cajaChica: Decimal {
    todaysSales.reduce(Decimal(0)) { $0 + $1.amount }
  }

  var cajaGrande: Decimal {
    allSales.reduce(Decimal(0)) { $0 + $1.amount }
  }

  var ultimasVentas: [Sale] {
    Array(todaysSales.prefix(5))
  }

  /// Resumen textual de ventas del día para alimentar al Consejero más adelante.
  var salesSummaryForAdvisor: String {
    let total = cajaChica.formatted(.currency(code: "MXN"))
    let count = todaysSales.count
    let byCategory = Dictionary(grouping: todaysSales.flatMap(\.items), by: \.productName)
      .mapValues { $0.count }
      .sorted { $0.value > $1.value }
      .prefix(3)
      .map { "\($0.key) (\($0.value))" }
      .joined(separator: ", ")

    return """
    Ventas de hoy: \(count) operaciones, total \(total).
    Productos más vendidos: \(byCategory.isEmpty ? "ninguno aún" : byCategory).
    """
  }
}
