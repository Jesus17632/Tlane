import SwiftUI
import SwiftData
import Speech
import AVFoundation
import FoundationModels

// MARK: - Modelos de chat (fuera del ViewModel)

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let text: String
    let date = Date.now
}

enum ChatRole { case user, assistant }

// MARK: - Bubbles

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(.footnote)
                .foregroundStyle(message.role == .user ? Color(hex: "#085041")! : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    message.role == .user
                        ? Color(hex: "#E1F5EE")!
                        : Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

struct ThinkingBubble: View {
    @State private var opacity: Double = 0.3

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(opacity)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(i) * 0.2),
                            value: opacity
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            Spacer(minLength: 40)
        }
        .onAppear { opacity = 1.0 }
    }
}

// MARK: - ChatViewModel

@Observable
@MainActor
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isThinking: Bool = false
    let voice = VoiceRecognizer()

    private var session: LanguageModelSession?

    func sendMessage(context: ModelContext) async {
        let text = voice.isRecording
            ? voice.transcript.trimmingCharacters(in: .whitespaces)
            : inputText.trimmingCharacters(in: .whitespaces)

        guard !text.isEmpty else { return }
        if voice.isRecording { voice.stopRecording() }

        messages.append(ChatMessage(role: .user, text: text))
        inputText = ""
        voice.transcript = ""
        isThinking = true

        let contextSummary = AppContextBuilder.build(context: context)

        if session == nil {
            session = LanguageModelSession(instructions: """
                Eres un asistente de ventas para artesanos mexicanos. \
                Entiendes lenguaje natural y puedes ejecutar acciones en la app. \
                Cuando el usuario quiera agregar producto, reducir stock, registrar \
                venta o gasto, extrae los datos y devuelve la acción correspondiente. \
                Si es solo conversación, usa action: none. \
                Responde siempre en español mexicano coloquial, máximo 2 oraciones.
                """)
        }

        let prompt = """
            Contexto del negocio:
            \(contextSummary)

            Mensaje del usuario: \(text)
            """

        do {
            #if targetEnvironment(simulator)
            try? await Task.sleep(for: .seconds(1))
            messages.append(ChatMessage(role: .assistant, text: "En simulador — en dispositivo real ejecutaría la acción."))
            #else
            guard case .available = SystemLanguageModel.default.availability else {
                messages.append(ChatMessage(role: .assistant, text: "Apple Intelligence no está disponible."))
                isThinking = false
                return
            }

            let response = try await session!.respond(to: prompt, generating: ChatResponse.self)
            let result = response.content

            if result.action != "none" {
                await executeAction(result, context: context)
            }

            messages.append(ChatMessage(role: .assistant, text: result.message))
            #endif
        } catch {
            messages.append(ChatMessage(role: .assistant, text: "No pude responder. Intenta de nuevo."))
        }

        isThinking = false
    }

    // MARK: - Ejecutor de acciones

    private func executeAction(_ intent: ChatResponse, context: ModelContext) async {
        switch intent.action {
        case "add_product":
            guard !intent.productName.isEmpty, intent.price > 0 else { return }
            let product = Product(
                name: intent.productName,
                category: intent.category.isEmpty ? "otro" : intent.category,
                initialStock: intent.quantity,
                currentStock: intent.quantity,
                price: Decimal(intent.price),
                isUniqueItem: intent.quantity == 1
            )
            context.insert(product)
            try? context.save()

        case "reduce_stock":
            guard !intent.productName.isEmpty else { return }
            let name = intent.productName
            let descriptor = FetchDescriptor<Product>(
                predicate: #Predicate { $0.name.localizedStandardContains(name) }
            )
            if let product = try? context.fetch(descriptor).first {
                product.currentStock = max(0, product.currentStock - max(1, intent.quantity))
                try? context.save()
            }

        case "register_sale":
            let amount = intent.amount > 0 ? intent.amount : intent.price
            guard amount > 0 else { return }
            let sale = Sale(
                amount: Decimal(amount),
                paymentMethod: .cash,
                items: intent.productName.isEmpty ? [] : [
                    SaleItem(
                        productId: UUID(),
                        productName: intent.productName,
                        quantity: intent.quantity,
                        priceAtSale: Decimal(amount)
                    )
                ]
            )
            context.insert(sale)
            try? context.save()

        case "register_expense":
            let amount = intent.amount > 0 ? intent.amount : intent.price
            guard amount > 0 else { return }
            let expense = Sale(
                amount: -Decimal(amount),
                paymentMethod: .cash,
                items: []
            )
            context.insert(expense)
            try? context.save()

        default:
            break
        }
    }
}

// MARK: - ConsejeroCardView

struct ConsejeroCardView: View {
    @Bindable var viewModel: InsightsViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var chatVM = ChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            consejoHeader
            Divider()
            chatArea
            Divider()
            inputBar
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .task {
            await viewModel.generateIfNeeded(context: modelContext)
            await chatVM.voice.requestPermissions()
        }
        .onChange(of: chatVM.voice.isRecording) { _, recording in
            if !recording && !chatVM.voice.transcript.isEmpty {
                Task { await chatVM.sendMessage(context: modelContext) }
            }
        }
    }

    // MARK: - Consejo arriba

    private var consejoHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Color.tlaneGreen)
                Text("Consejo del día")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.tlaneGreen)
                Spacer()
                if viewModel.isLoading {
                    ProgressView().scaleEffect(0.6).tint(Color.tlaneGreen)
                } else {
                    Button {
                        Task { await viewModel.generateInsight(context: modelContext) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(Color.tlaneGreen.opacity(0.7))
                    }
                }
            }

            if viewModel.isLoading {
                Text("Analizando tu negocio…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let insight = viewModel.insight {
                Text(insight.mainAdvice)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                if !insight.suggestedAction.isEmpty {
                    Text(insight.suggestedAction)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } else {
                Text("Toca ↻ para generar un consejo")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Área de chat

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(chatVM.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                    if chatVM.isThinking {
                        ThinkingBubble()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .frame(minHeight: 180)
            .onChange(of: chatVM.messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(chatVM.messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: chatVM.isThinking) { _, _ in
                withAnimation {
                    proxy.scrollTo(chatVM.messages.last?.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Pregunta algo…", text: $chatVM.inputText)
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.06), in: Capsule())
                .disabled(chatVM.voice.isRecording)
                .overlay {
                    if chatVM.voice.isRecording {
                        Capsule()
                            .strokeBorder(Color.tlaneGreen, lineWidth: 1)
                        Text(chatVM.voice.transcript.isEmpty ? "Escuchando…" : chatVM.voice.transcript)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .lineLimit(1)
                    }
                }

            Button {
                chatVM.voice.toggle()
            } label: {
                Image(systemName: chatVM.voice.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(chatVM.voice.isRecording ? .white : Color.tlaneGreen)
                    .frame(width: 34, height: 34)
                    .background(
                        chatVM.voice.isRecording ? Color.tlaneGreen : Color.tlaneGreen.opacity(0.12),
                        in: Circle()
                    )
            }
            .disabled(!chatVM.voice.hasPermission || chatVM.isThinking)

            Button {
                Task { await chatVM.sendMessage(context: modelContext) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        chatVM.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.tlaneGreen.opacity(0.3)
                            : Color.tlaneGreen,
                        in: Circle()
                    )
            }
            .disabled(chatVM.inputText.trimmingCharacters(in: .whitespaces).isEmpty || chatVM.isThinking)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

#Preview {
    let vm = InsightsViewModel()
    return ConsejeroCardView(viewModel: vm)
        .padding()
        .background(Color.tlaneBackground)
}
