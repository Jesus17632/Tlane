import Foundation
import SwiftData

@Model
final class Sale {
  @Attribute(.unique) var id: UUID
  var amount: Decimal
  var date: Date
  var paymentMethod: PaymentMethod

  // SwiftData no persiste [SaleItem] nativamente (struct Codable).
  // Serializamos a JSON en este campo y exponemos `items` como
  // computed property.
  private var itemsData: Data

  init(
    id: UUID = UUID(),
    amount: Decimal,
    date: Date = .now,
    paymentMethod: PaymentMethod,
    items: [SaleItem] = []
  ) {
    self.id = id
    self.amount = amount
    self.date = date
    self.paymentMethod = paymentMethod
    self.itemsData = (try? JSONEncoder().encode(items)) ?? Data()
  }

  var items: [SaleItem] {
    get {
      guard !itemsData.isEmpty,
            let decoded = try? JSONDecoder().decode([SaleItem].self, from: itemsData)
      else { return [] }
      return decoded
    }
    set {
      itemsData = (try? JSONEncoder().encode(newValue)) ?? Data()
    }
  }
}
