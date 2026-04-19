import Foundation
import SwiftData
import AVFoundation
import UIKit

enum CaptureState {
  case requestingPermission
  case denied
  case scanning
  case detected(category: String, frame: UIImage)
  case saving
}

@Observable
@MainActor
final class InventoryViewModel: NSObject {
  private let context: ModelContext

  var state: CaptureState = .requestingPermission
  var productName: String = ""
  var productPrice: Decimal = 0
  var productQuantity: Int = 0

  let cameraSession = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "tlane.camera.session")
  private let classifier = ProductClassifierService()

  nonisolated(unsafe) private var lastCategoryRaw: String?
  nonisolated(unsafe) private var lastCategoryTimestamp: Date?
  nonisolated(unsafe) private var lastAnalysisTime: Date = .distantPast
  nonisolated(unsafe) private var isAnalyzing: Bool = false
  nonisolated(unsafe) private var isScanningActive: Bool = false
  nonisolated(unsafe) private var scanningEpoch: Int = 0

  /// Task pendiente del timer de saveProduct (1.4s antes de reset).
  /// Se cancela cuando sales del tab durante el save.
  nonisolated(unsafe) private var saveCompletionTask: Task<Void, Never>?

  init(context: ModelContext) {
    self.context = context
    super.init()
  }

  // MARK: - Permiso

  func requestCameraPermission() async {
    #if targetEnvironment(simulator)
    state = .scanning
    isScanningActive = true
    scanningEpoch += 1
    return
    #else
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .authorized:
      setupCameraSession()
      state = .scanning
      isScanningActive = true
      scanningEpoch += 1
    case .notDetermined:
      let granted = await AVCaptureDevice.requestAccess(for: .video)
      if granted {
        setupCameraSession()
        state = .scanning
        isScanningActive = true
        scanningEpoch += 1
      } else {
        state = .denied
      }
    case .denied, .restricted:
      state = .denied
    @unknown default:
      state = .denied
    }
    #endif
  }

  // MARK: - Camera setup

  private func setupCameraSession() {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      cameraSession.beginConfiguration()
      cameraSession.sessionPreset = .high

      guard let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            cameraSession.canAddInput(input) else {
        cameraSession.commitConfiguration()
        return
      }
      cameraSession.addInput(input)

      let output = AVCaptureVideoDataOutput()
      output.setSampleBufferDelegate(self, queue: sessionQueue)
      output.alwaysDiscardsLateVideoFrames = true
      if cameraSession.canAddOutput(output) {
        cameraSession.addOutput(output)
      }

      cameraSession.commitConfiguration()
      cameraSession.startRunning()
    }
  }

  // MARK: - Guardar

  func saveProduct(category: String, imageData: Data?) {
    let trimmed = productName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, productPrice > 0, productQuantity > 0 else { return }

    let product = Product(
      name: trimmed,
      category: category,
      initialStock: productQuantity,
      currentStock: productQuantity,
      price: productPrice,
      isUniqueItem: productQuantity == 1,
      imageData: imageData
    )
    context.insert(product)
    try? context.save()

    state = .saving

    // Cancelar cualquier task anterior antes de crear uno nuevo
    saveCompletionTask?.cancel()

    // Guardar referencia para poder cancelarlo si salimos del tab
    saveCompletionTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(1400))
      // Si el task fue cancelado durante el sleep → no resetear
      guard !Task.isCancelled else {
        print("⏹️ saveCompletionTask cancelado, no resetear")
        return
      }
      await MainActor.run {
        self?.resetToScanning()
      }
    }
  }

  func resetToScanning() {
    print("♻️ resetToScanning")
    productName = ""
    productPrice = 0
    productQuantity = 0
    clearDebounce()
    state = .scanning
    startCamera()
  }

  /// Limpia el estado sin arrancar la cámara (para cuando sales del tab).
  func cancelPendingDetection() {
    print("❌ cancelPendingDetection — state era: \(state)")
    // Cancelar task del save si estaba pendiente (CRÍTICO)
    saveCompletionTask?.cancel()
    saveCompletionTask = nil

    productName = ""
    productPrice = 0
    productQuantity = 0
    clearDebounce()
    state = .scanning
    isScanningActive = false
  }

  // MARK: - Control de cámara

  func stopCamera() {
    print("🛑 stopCamera — epoch antes: \(scanningEpoch), state: \(state)")
    isScanningActive = false
    scanningEpoch += 1
    clearDebounce()
    // Cancelar también el task pendiente del save (por si acaso)
    saveCompletionTask?.cancel()
    print("🛑 stopCamera — epoch después: \(scanningEpoch)")

    sessionQueue.async { [weak self] in
      guard let session = self?.cameraSession, session.isRunning else { return }
      session.stopRunning()
      print("🛑 sesión AVCapture detenida")
    }
  }

  func startCamera() {
    print("▶️ startCamera — epoch antes: \(scanningEpoch), state: \(state)")
    clearDebounce()
    isScanningActive = true
    scanningEpoch += 1
    print("▶️ startCamera — epoch después: \(scanningEpoch)")

    sessionQueue.async { [weak self] in
      guard let session = self?.cameraSession, !session.isRunning else { return }
      session.startRunning()
      print("▶️ sesión AVCapture arrancada")
    }
  }

  // MARK: - Debounce helpers

  private func clearDebounce() {
    lastCategoryRaw = nil
    lastCategoryTimestamp = nil
    lastAnalysisTime = .distantPast
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension InventoryViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
  nonisolated func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard isScanningActive else { return }

    let now = Date()
    guard now.timeIntervalSince(lastAnalysisTime) >= 0.5, !isAnalyzing else { return }
    lastAnalysisTime = now
    isAnalyzing = true

    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      isAnalyzing = false
      return
    }

    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let ciContext = CIContext()
    guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
      isAnalyzing = false
      return
    }
    let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)

    let epochAtStart = scanningEpoch

    Task { [weak self] in
      await self?.analyze(image: uiImage, expectedEpoch: epochAtStart)
      self?.isAnalyzing = false
    }
  }

  private func analyze(image: UIImage, expectedEpoch: Int) async {
    guard isScanningActive else { return }
    guard scanningEpoch == expectedEpoch else {
      print("🚫 analyze: epoch viejo \(expectedEpoch), actual \(scanningEpoch)")
      return
    }
    guard case .scanning = state else { return }

    let result: ClassificationResult
    do {
      result = try await classifier.classify(image: image)
    } catch {
      return
    }

    await MainActor.run {
      guard self.isScanningActive else { return }
      guard self.scanningEpoch == expectedEpoch else {
        print("🚫 analyze MainActor: epoch viejo \(expectedEpoch), actual \(self.scanningEpoch)")
        return
      }
      guard case .scanning = self.state else { return }

      let now = Date()
      if self.lastCategoryRaw == result.category,
         let ts = self.lastCategoryTimestamp,
         now.timeIntervalSince(ts) >= 1.5 {
        print("✅ DETECTADO: \(result.category) — epoch: \(self.scanningEpoch)")
        self.state = .detected(category: result.category, frame: image)
        self.stopCamera()
        self.clearDebounce()
      } else if self.lastCategoryRaw != result.category {
        self.lastCategoryRaw = result.category
        self.lastCategoryTimestamp = now
      }
    }
  }
}
