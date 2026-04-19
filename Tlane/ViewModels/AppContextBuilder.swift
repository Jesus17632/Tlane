//
//  AppContextBuilder.swift
//  Tlane
//
//  Created by Dev Jr.16 on 19/04/26.
//
import Foundation
import SwiftData

struct AppContextBuilder {

    // MARK: - Punto de entrada principal

    static func build(context: ModelContext) -> String {
        let sales    = fetchSales(context: context)
        let products = fetchProducts(context: context)

        let now      = Date.now
        let calendar = Calendar.current
        let hour     = calendar.component(.hour, from: now)
        let weekday  = calendar.component(.weekday, from: now)
        let isWeekend = weekday == 1 || weekday == 7

        let todaySales  = sales.filter { calendar.isDateInToday($0.date) }
        let weekSales   = sales.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
        let monthSales  = sales.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }

        let todayTotal  = todaySales.reduce(Decimal(0))  { $0 + $1.amount }
        let weekTotal   = weekSales.reduce(Decimal(0))   { $0 + $1.amount }
        let monthTotal  = monthSales.reduce(Decimal(0))  { $0 + $1.amount }

        let topProducts = topSellingProducts(from: weekSales, products: products)
        let activeProds = products.filter { $0.currentStock > 0 }
        let lowStock    = products.filter { $0.currentStock == 1 && !$0.isUniqueItem }

        let cashCount    = todaySales.filter { $0.paymentMethod == .cash }.count
        let digitalCount = todaySales.filter { $0.paymentMethod == .digital }.count

        return """
        === CONTEXTO DEL NEGOCIO ===
        Fecha y hora: \(formattedDate(now)), \(hour):00 hrs (\(isWeekend ? "fin de semana" : "día entre semana"))

        --- Ventas ---
        Hoy: \(todaySales.count) ventas · $\(todayTotal.formatted()) MXN
        Esta semana: \(weekSales.count) ventas · $\(weekTotal.formatted()) MXN
        Este mes: \(monthSales.count) ventas · $\(monthTotal.formatted()) MXN
        Método de pago hoy: \(cashCount) efectivo · \(digitalCount) digital

        --- Inventario ---
        Productos activos (con stock): \(activeProds.count)
        Productos agotados: \(products.filter { $0.isSold }.count)
        \(lowStock.isEmpty ? "" : "⚠️ Stock casi agotado: \(lowStock.map(\.name).joined(separator: ", "))")

        --- Top 5 productos esta semana ---
        \(topProducts.isEmpty ? "Sin ventas esta semana aún." : topProducts)

        --- Categorías disponibles ---
        \(categorySummary(products: activeProds))
        === FIN DE CONTEXTO ===
        """
    }

    // MARK: - Helpers privados

    private static func fetchSales(context: ModelContext) -> [Sale] {
        // Solo últimos 30 días para no sobrecargar el contexto
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let descriptor = FetchDescriptor<Sale>(
            predicate: #Predicate { $0.date >= cutoff },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchProducts(context: ModelContext) -> [Product] {
        let descriptor = FetchDescriptor<Product>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func topSellingProducts(from sales: [Sale], products: [Product]) -> String {
        // Cuenta cuántas veces aparece cada productId en los SaleItems
        var counts: [UUID: (name: String, qty: Int, revenue: Decimal)] = [:]
        for sale in sales {
            for item in sale.items {
                if var entry = counts[item.productId] {
                    entry.qty     += item.quantity
                    entry.revenue += item.priceAtSale * Decimal(item.quantity)
                    counts[item.productId] = entry
                } else {
                    counts[item.productId] = (item.productName, item.quantity, item.priceAtSale)
                }
            }
        }
        return counts.values
            .sorted { $0.revenue > $1.revenue }
            .prefix(5)
            .enumerated()
            .map { i, p in "\(i+1). \(p.name) — \(p.qty) uds · $\(p.revenue.formatted()) MXN" }
            .joined(separator: "\n")
    }

    private static func categorySummary(products: [Product]) -> String {
        let grouped = Dictionary(grouping: products, by: \.category)
        return grouped
            .sorted { $0.key < $1.key }
            .map { cat, prods in "\(cat): \(prods.count) productos" }
            .joined(separator: " · ")
    }

    private static func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateStyle = .medium
        return f.string(from: date)
    }
}
