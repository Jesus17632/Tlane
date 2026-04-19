import Foundation
import SwiftData

@Model
final class Product {
  @Attribute(.unique) var id: UUID
  var name: String
  var category: String        // "textil","barro","madera","joyería","otro"
  var initialStock: Int
  var currentStock: Int
  var price: Decimal
  var isUniqueItem: Bool
  var imageData: Data?
  var createdAt: Date

  init(
    id: UUID = UUID(),
    name: String,
    category: String,
    initialStock: Int = 1,
    currentStock: Int? = nil,
    price: Decimal,
    isUniqueItem: Bool = true,
    imageData: Data? = nil,
    createdAt: Date = .now
  ) {
    self.id = id
    self.name = name
    self.category = category
    self.initialStock = initialStock
    // Si no se pasa stock actual, iguala al inicial
    self.currentStock = currentStock ?? initialStock
    self.price = price
    self.isUniqueItem = isUniqueItem
    self.imageData = imageData
    self.createdAt = createdAt
  }

  var isSold: Bool { currentStock <= 0 }
}
