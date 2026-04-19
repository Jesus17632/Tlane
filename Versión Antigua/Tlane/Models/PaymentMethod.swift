import Foundation

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
  case cash    = "Efectivo"
  case digital = "Digital"

  var id: String { rawValue }

  var systemImage: String {
    switch self {
    case .cash:    "banknote"
    case .digital: "wave.3.right.circle.fill"
    }
  }
}
