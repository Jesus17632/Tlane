import Foundation
import SwiftData

@Observable
@MainActor
final class CaptureViewModel {
  private let context: ModelContext

  var selectedProduct: Product?
  var isShowingPaymentSheet: Bool = false
  var isShowingTapToPay: Bool = false
  var lastSaleConfirmation: String?

  init(context: ModelContext) {
    self.context = context
  }

  /// Productos disponibles para vender (stock > 0).
  var availableProducts: [Product] {
    let predicate = #Predicate<Product> { $0.currentStock > 0 }
    let descriptor = FetchDescriptor<Product>(
      predicate: predicate,
      sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    return (try? context.fetch(descriptor)) ?? []
  }

  func selectProduct(_ product: Product) {
    selectedProduct = product
    isShowingPaymentSheet = true
  }

  /// Registra venta en efectivo (inmediata, sin flujo Tap to Pay).
  func registerCashSale() {
    guard let product = selectedProduct else { return }
    persistSale(for: product, method: .cash)
    dismissAll()
  }

  /// Inicia flujo de Tap to Pay (el Sale se persiste al completar).
  func startTapToPay() {
    isShowingPaymentSheet = false
    isShowingTapToPay = true
  }

  /// Callback del TapToPayMockView al completar las 3 fases.
  func completeTapToPay() {
    guard let product = selectedProduct else { return }
    persistSale(for: product, method: .digital)
    dismissAll()
  }

  func cancelTapToPay() {
    isShowingTapToPay = false
  }

  // MARK: - Privado

  private func persistSale(for product: Product, method: PaymentMethod) {
    let item = SaleItem(
      productId: product.id,
      productName: product.name,
      quantity: 1,
      priceAtSale: product.price
    )
    let sale = Sale(
      amount: product.price,
      paymentMethod: method,
      items: [item]
    )
    context.insert(sale)
    product.currentStock -= 1

    do {
      try context.save()
      lastSaleConfirmation = "Venta registrada: \(product.name)"
    } catch {
      lastSaleConfirmation = "Error al guardar la venta"
    }
  }

  private func dismissAll() {
    isShowingPaymentSheet = false
    isShowingTapToPay = false
    selectedProduct = nil
  }
}
