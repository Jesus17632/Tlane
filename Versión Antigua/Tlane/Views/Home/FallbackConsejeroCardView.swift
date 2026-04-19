import SwiftUI
import FoundationModels
import Speech
import AVFoundation

// MARK: - Salida estructurada

@Generable
struct ConsejoIA {
    @Guide(description: "Nombre de un SF Symbol de sistema, p.ej. 'sun.max.fill' o 'sparkles'")
    var icon: String
    @Guide(description: "Consejo principal, máximo 12 palabras")
    var mainAdvice: String
    @Guide(description: "Razón breve del consejo, máximo 20 palabras")
    var reasoning: String
    @Guide(description: "Acción concreta que puede hacer ahora, máximo 15 palabras")
    var suggestedAction: String
}

// MARK: - Voice Recognizer

@Observable
final class VoiceRecognizer {
    var transcript    = ""
    var isRecording   = false
    var hasPermission = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    func requestPermissions() async {
        #if targetEnvironment(simulator)
        hasPermission = false   // mic no disponible en simulator
        return
        #else
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        let micGranted: Bool
        if #available(iOS 17, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }
        hasPermission = speechStatus == .authorized && micGranted
        #endif
    }

    func startRecording() throws {
        #if targetEnvironment(simulator)
        return
        #else
        recognitionTask?.cancel()
        recognitionTask = nil
        transcript = ""

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults  = true
        request.requiresOnDeviceRecognition = true

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result { self.transcript = result.bestTranscription.formattedString }
            if error != nil || result?.isFinal == true { self.stopRecording() }
        }

        let inputNode = audioEngine.inputNode
        let format    = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buf, _ in
            request.append(buf)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        #endif
    }

    func stopRecording() {
        #if !targetEnvironment(simulator)
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask    = nil
        isRecording        = false
        #endif
    }

    func toggle() {
        if isRecording { stopRecording() } else { try? startRecording() }
    }
}

// MARK: - ViewModel

@Observable
final class ConsejeroViewModel {

    var icon            = "sparkles"
    var mainAdvice      = ""
    var reasoning       = ""
    var suggestedAction = ""
    var isLoading       = false
    var errorMessage: String?

    let voice = VoiceRecognizer()

    // La sesión sólo existe en dispositivo real
    private let session: LanguageModelSession? = {
        #if targetEnvironment(simulator)
        return nil
        #else
        return LanguageModelSession(
            instructions: """
            Eres un consejero experto para artesanos y vendedores \
            en mercados tradicionales de México. \
            Da consejos prácticos sobre ventas, presentación de productos \
            y atención al cliente. Sé breve y directo.
            """
        )
        #endif
    }()

    @MainActor
    func loadAdvice() async {
        let weekday   = Calendar.current.component(.weekday, from: .now)
        let isWeekend = weekday == 1 || weekday == 7
        let hour      = Calendar.current.component(.hour, from: .now)
        await ask("Hoy es \(isWeekend ? "fin de semana" : "día entre semana"), son las \(hour):00 hrs. Dame un consejo de ventas práctico para hoy.")
    }

    @MainActor
    func submitVoice() async {
        let text = voice.transcript.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        await ask(text)
    }

    @MainActor
    private func ask(_ prompt: String) async {
        #if targetEnvironment(simulator)
        loadFallback()          // simulator siempre usa fallback
        return
        #else
        guard let session else { loadFallback(); return }

        switch SystemLanguageModel.default.availability {
        case .available: break
        case .unavailable:
            loadFallback(); return
        }

        isLoading    = true
        errorMessage = nil

        do {
            let response    = try await session.respond(to: prompt, generating: ConsejoIA.self)
            let consejo     = response.content
            icon            = consejo.icon
            mainAdvice      = consejo.mainAdvice
            reasoning       = consejo.reasoning
            suggestedAction = consejo.suggestedAction
        } catch {
            errorMessage = error.localizedDescription
            loadFallback()
        }

        isLoading = false
        #endif
    }

    private func loadFallback() {
        let fallbacks: [(icon: String, main: String, reason: String, action: String)] = [
            (
                "sun.max.fill",
                "Los días soleados aumentan el flujo en el mercado.",
                "La gente pasea más y se detiene en puestos visibles.",
                "Coloca tus piezas más coloridas al frente hoy."
            ),
            (
                "calendar.badge.clock",
                "Tus ventas del fin de semana suelen duplicar las de entre semana.",
                "Sábados y domingos concentran turistas y familias.",
                "Lleva cambio suficiente en billetes de $50 y $100."
            ),
            (
                "sparkles",
                "Las piezas únicas se venden mejor con una historia detrás.",
                "Los compradores valoran el origen y quién la hizo.",
                "Anota una frase corta sobre el origen de cada pieza."
            )
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1
        let f   = fallbacks[day % fallbacks.count]
        icon            = f.icon
        mainAdvice      = f.main
        reasoning       = f.reason
        suggestedAction = f.action
    }
}

// MARK: - View principal

struct FallbackConsejeroCardView: View {
    @State private var vm = ConsejeroViewModel()

    var body: some View {
        VStack(spacing: 12) {
            ConsejeroCardContent(
                icon:            vm.icon.isEmpty            ? "sparkles" : vm.icon,
                mainAdvice:      vm.mainAdvice.isEmpty      ? " "        : vm.mainAdvice,
                reasoning:       vm.reasoning.isEmpty       ? " "        : vm.reasoning,
                suggestedAction: vm.suggestedAction.isEmpty ? " "        : vm.suggestedAction,
                isLoading:       vm.isLoading
            )
            VoiceBar(vm: vm)
        }
        .task {
            await vm.voice.requestPermissions()
            await vm.loadAdvice()
        }
        .onChange(of: vm.voice.isRecording) { _, recording in
            if !recording {
                Task { await vm.submitVoice() }
            }
        }
    }
}

// MARK: - Barra de voz

private struct VoiceBar: View {
    let vm: ConsejeroViewModel
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            Text(
                vm.voice.isRecording
                    ? (vm.voice.transcript.isEmpty ? "Escuchando…" : vm.voice.transcript)
                    : "Toca el micrófono para preguntar"
            )
            .font(.footnote)
            .foregroundStyle(vm.voice.isRecording ? .primary : .secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                vm.voice.toggle()
            } label: {
                ZStack {
                    if vm.voice.isRecording {
                        Circle()
                            .fill(Color.tlaneGreen.opacity(0.25))
                            .frame(width: 52, height: 52)
                            .scaleEffect(pulse ? 1.4 : 1.0)
                            .opacity(pulse ? 0 : 1)
                            .animation(
                                .easeOut(duration: 0.9).repeatForever(autoreverses: false),
                                value: pulse
                            )
                    }
                    Circle()
                        .fill(vm.voice.isRecording ? Color.tlaneGreen : Color.tlaneGreen.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: vm.voice.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(vm.voice.isRecording ? .white : Color.tlaneGreen)
                }
            }
            .disabled(!vm.voice.hasPermission || vm.isLoading)
            .onAppear { pulse = true }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Card UI

struct ConsejeroCardContent: View {
    let icon: String
    let mainAdvice: String
    let reasoning: String
    let suggestedAction: String
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.tlaneGreen)
                Text("Consejo del día")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.tlaneGreen)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.tlaneGreen.opacity(0.12), in: Capsule())
            .padding(.bottom, 14)

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView().tint(Color.tlaneGreen)
                    Text("Pensando…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
            } else {
                Text(mainAdvice)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)

                Text(reasoning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 14)

                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.tlaneGreen)
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)
                    Text(suggestedAction)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Preview
// Usa ConsejeroCardContent directamente — sin ViewModel ni AI

#Preview {
    VStack(spacing: 12) {
        ConsejeroCardContent(
            icon: "sparkles",
            mainAdvice: "Las piezas únicas se venden mejor con una historia detrás.",
            reasoning: "Los compradores valoran el origen y quién la hizo.",
            suggestedAction: "Anota una frase corta sobre el origen de cada pieza.",
            isLoading: false
        )

        // Preview del estado cargando
        ConsejeroCardContent(
            icon: "sparkles",
            mainAdvice: " ",
            reasoning: " ",
            suggestedAction: " ",
            isLoading: true
        )
    }
    .padding()
    .background(Color.tlaneBackground)
}
