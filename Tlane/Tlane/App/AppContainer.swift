import Foundation
import SwiftData

enum AppContainer {
  static let schema = Schema([
    Product.self,
    Sale.self
  ])

  /// Contenedor de producción, persistente en disco.
  static func makeProduction() -> ModelContainer {
    let config = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false
    )
    do {
      return try ModelContainer(for: schema, configurations: config)
    } catch {
      // En producción este crash indica corrupción de store;
      // considerar estrategia de reset en versión futura.
      fatalError("No se pudo inicializar ModelContainer: \(error)")
    }
  }

  /// Contenedor en memoria con datos de muestra para PreviewProviders.
  @MainActor
  static let preview: ModelContainer = {
    let config = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: true
    )
    do {
      let container = try ModelContainer(for: schema, configurations: config)
      seed(into: container.mainContext)
      return container
    } catch {
      fatalError("Preview container falló: \(error)")
    }
  }()

  @MainActor
  private static func seed(into context: ModelContext) {
    let products: [Product] = [
      Product(name: "Huipil bordado a mano",    category: "textil",  price: 850),
      Product(name: "Cazuela de barro negro",   category: "barro",   price: 320),
      Product(name: "Máscara tallada de copal", category: "madera",  price: 480),
      Product(name: "Collar de jade oaxaqueño", category: "joyería", price: 650),
      Product(name: "Sarape de Saltillo",       category: "textil",  price: 1_200)
    ]
    products.forEach { context.insert($0) }

    let now = Date.now
    let hourAgo: (Int) -> Date = { now.addingTimeInterval(TimeInterval(-3600 * $0)) }

    let sales: [Sale] = [
      Sale(
        amount: 850,
        date: hourAgo(1),
        paymentMethod: .cash,
        items: [SaleItem(
          productId: products[0].id,
          productName: products[0].name,
          quantity: 1,
          priceAtSale: 850
        )]
      ),
      Sale(
        amount: 320,
        date: hourAgo(3),
        paymentMethod: .digital,
        items: [SaleItem(
          productId: products[1].id,
          productName: products[1].name,
          quantity: 1,
          priceAtSale: 320
        )]
      ),
      Sale(
        amount: 480,
        date: hourAgo(5),
        paymentMethod: .cash,
        items: [SaleItem(
          productId: products[2].id,
          productName: products[2].name,
          quantity: 1,
          priceAtSale: 480
        )]
      )
    ]
    sales.forEach { context.insert($0) }

    try? context.save()
  }
}
