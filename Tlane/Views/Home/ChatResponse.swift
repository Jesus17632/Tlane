//
//  ChatResponse.swift
//  Tlane
//
//  Created by Dev Jr.16 on 19/04/26.
//

import Foundation
import FoundationModels

@Generable
struct ChatResponse {
    @Guide(description: "Respuesta conversacional al usuario, máximo 2 oraciones, español mexicano coloquial")
    var message: String

    @Guide(description: """
        Acción a ejecutar. Usa exactamente uno de estos valores:
        add_product, reduce_stock, register_sale, register_expense, none
        """)
    var action: String

    @Guide(description: "Nombre del producto mencionado, vacío si no aplica")
    var productName: String

    @Guide(description: "Precio del producto en pesos, 0 si no se menciona")
    var price: Double

    @Guide(description: "Cantidad o unidades, 1 si no se menciona")
    var quantity: Int

    @Guide(description: "Categoría: textil, barro, madera, joyería, otro. Vacío si no aplica")
    var category: String

    @Guide(description: "Monto del gasto o venta en pesos, 0 si no aplica")
    var amount: Double
}
