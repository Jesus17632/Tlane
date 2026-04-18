import Foundation
import SwiftData

@Observable
@MainActor
final class InventoryViewModel {
  private let context: ModelContext
  var isShowingAddProduct: Bool = false

  init(context: ModelContext) {
    self.context = context
  }

  var products: [Product] {
    let descriptor = FetchDescriptor<Product>(
      sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    return (try? context.fetch(descriptor)) ?? []
  }

  var availableCount: Int {
    products.filter { !$0.isSold }.count
  }

  var soldCount: Int {
    products.filter { $0.isSold }.count
  }

  var totalStockValue: Decimal {
    products
      .filter { !$0.isSold }
      .reduce(Decimal(0)) { $0 + $1.price }
  }

  func addProduct(name: String, category: String, price: Decimal) {
    let product = Product(name: name, category: category, price: price)
    context.insert(product)
    try? context.save()
  }

  func delete(product: Product) {
    context.delete(product)
    try? context.save()
  }
}
