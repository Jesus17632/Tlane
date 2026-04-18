import Foundation

/// ValueType embebido en Sale. No es @Model — se persiste
/// dentro de Sale.itemsData como JSON.
struct SaleItem: Codable, Hashable, Identifiable {
  var id: UUID
  var productId: UUID
  var productName: String
  var quantity: Int
  var priceAtSale: Decimal

  init(
    id: UUID = UUID(),
    productId: UUID,
    productName: String,
    quantity: Int,
    priceAtSale: Decimal
  ) {
    self.id = id
    self.productId = productId
    self.productName = productName
    self.quantity = quantity
    self.priceAtSale = priceAtSale
  }
}
