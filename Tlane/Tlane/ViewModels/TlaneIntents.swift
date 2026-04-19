//
//  TlaneIntents.swift
//  Tlane
//
//  Created by Dev Jr.16 on 19/04/26.
//

import AppIntents
import SwiftData

// MARK: - Agregar producto

struct AgregarProductoIntent: AppIntent {
    static var title: LocalizedStringResource = "Agregar producto"
    static var description = IntentDescription("Agrega un nuevo producto al inventario de Tlane")

    static var openAppWhenRun = false

    @Parameter(title: "Nombre del producto")
    var nombre: String

    @Parameter(title: "Precio en pesos")
    var precio: Double

    @Parameter(title: "Cantidad", default: 1)
    var cantidad: Int

    @Parameter(title: "Categoría", default: "otro")
    var categoria: String

    static var parameterSummary: some ParameterSummary {
        Summary("Agregar \(\.$nombre) a $\(\.$precio) con \(\.$cantidad) unidades")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = AppContainer.makeProduction()
        let context = container.mainContext
        let product = Product(
            name: nombre,
            category: categoria,
            initialStock: cantidad,
            currentStock: cantidad,
            price: Decimal(precio),
            isUniqueItem: cantidad == 1
        )
        context.insert(product)
        try context.save()
        return .result(dialog: "Listo, agregué \(nombre) a tu inventario por $\(Int(precio)).")
    }
}

// MARK: - Registrar venta

struct RegistrarVentaIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar venta"
    static var description = IntentDescription("Registra una venta en Tlane")

    static var openAppWhenRun = false

    @Parameter(title: "Monto en pesos")
    var monto: Double

    @Parameter(title: "Producto vendido", default: "")
    var producto: String

    static var parameterSummary: some ParameterSummary {
        Summary("Registrar venta de $\(\.$monto) por \(\.$producto)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = AppContainer.makeProduction()
        let context = container.mainContext
        let sale = Sale(
            amount: Decimal(monto),
            paymentMethod: .cash,
            items: producto.isEmpty ? [] : [
                SaleItem(
                    productId: UUID(),
                    productName: producto,
                    quantity: 1,
                    priceAtSale: Decimal(monto)
                )
            ]
        )
        context.insert(sale)
        try context.save()
        return .result(dialog: "Registré una venta de $\(Int(monto)). ¡Buen trabajo!")
    }
}

// MARK: - Registrar gasto

struct RegistrarGastoIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar gasto"
    static var description = IntentDescription("Registra un gasto en Tlane")

    static var openAppWhenRun = false

    @Parameter(title: "Monto en pesos")
    var monto: Double

    @Parameter(title: "Concepto", default: "")
    var concepto: String

    static var parameterSummary: some ParameterSummary {
        Summary("Registrar gasto de $\(\.$monto) por \(\.$concepto)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = AppContainer.makeProduction()
        let context = container.mainContext
        let expense = Sale(
            amount: -Decimal(monto),
            paymentMethod: .cash,
            items: []
        )
        context.insert(expense)
        try context.save()
        return .result(dialog: "Registré un gasto de $\(Int(monto)).")
    }
}

// MARK: - Reducir stock

struct ReducirStockIntent: AppIntent {
    static var title: LocalizedStringResource = "Reducir stock"
    static var description = IntentDescription("Reduce el stock de un producto en Tlane")

    static var openAppWhenRun = false

    @Parameter(title: "Nombre del producto")
    var producto: String

    @Parameter(title: "Cantidad a reducir", default: 1)
    var cantidad: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Reducir \(\.$cantidad) unidades de \(\.$producto)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = AppContainer.makeProduction()
        let context = container.mainContext
        let name = producto
        let descriptor = FetchDescriptor<Product>(
            predicate: #Predicate { $0.name.localizedStandardContains(name) }
        )
        guard let product = try context.fetch(descriptor).first else {
            return .result(dialog: "No encontré ningún producto llamado \(producto).")
        }
        product.currentStock = max(0, product.currentStock - cantidad)
        try context.save()
        return .result(dialog: "Reduje \(cantidad) unidades de \(product.name). Quedan \(product.currentStock).")
    }
}

// MARK: - Shortcuts App

struct TlaneShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AgregarProductoIntent(),
            phrases: [
                "Agregar producto en \(.applicationName)",
                "Nuevo producto en \(.applicationName)",
                "Añadir al inventario en \(.applicationName)"
            ],
            shortTitle: "Agregar producto",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: RegistrarVentaIntent(),
            phrases: [
                "Registrar venta en \(.applicationName)",
                "Vendí algo en \(.applicationName)",
                "Nueva venta en \(.applicationName)"
            ],
            shortTitle: "Registrar venta",
            systemImageName: "arrow.down.circle"
        )
        AppShortcut(
            intent: RegistrarGastoIntent(),
            phrases: [
                "Registrar gasto en \(.applicationName)",
                "Nuevo gasto en \(.applicationName)",
                "Gasté en \(.applicationName)"
            ],
            shortTitle: "Registrar gasto",
            systemImageName: "arrow.up.circle"
        )
        AppShortcut(
            intent: ReducirStockIntent(),
            phrases: [
                "Reducir stock en \(.applicationName)",
                "Quitar producto en \(.applicationName)"
            ],
            shortTitle: "Reducir stock",
            systemImageName: "minus.circle"
        )
    }
}
