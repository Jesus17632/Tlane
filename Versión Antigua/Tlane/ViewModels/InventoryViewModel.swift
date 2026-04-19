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

  init(context: ModelContext) {
    self.context = context
    super.init()
  }

  // MARK: - Permiso

  func requestCameraPermission() async {
    #if targetEnvironment(simulator)
    state = .scanning
    return
    #else
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .authorized:
      setupCameraSession()
      state = .scanning
    case .notDetermined:
      let granted = await AVCaptureDevice.requestAccess(for: .video)
      if granted {
        setupCameraSession()
        state = .scanning
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

    Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(1400))
      await MainActor.run {
        self?.resetToScanning()
      }
    }
  }

  func resetToScanning() {
    productName = ""
    productPrice = 0
    productQuantity = 0
    clearDebounce()
    state = .scanning
    startCamera()
  }

  // MARK: - Control de cámara

  func stopCamera() {
    sessionQueue.async { [weak self] in
      guard let session = self?.cameraSession, session.isRunning else { return }
      session.stopRunning()
    }
  }

  func startCamera() {
    sessionQueue.async { [weak self] in
      guard let session = self?.cameraSession, !session.isRunning else { return }
      session.startRunning()
    }
  }

  // MARK: - Debounce helpers

  private func clearDebounce() {
    lastCategoryRaw = nil
    lastCategoryTimestamp = nil
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension InventoryViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
  nonisolated func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
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

    Task { [weak self] in
      await self?.analyze(image: uiImage)
      self?.isAnalyzing = false
    }
  }

  private func analyze(image: UIImage) async {
    guard case .scanning = state else { return }

    let result: ClassificationResult
    do {
      result = try await classifier.classify(image: image)
    } catch {
      return
    }

    guard result.category != "otro" else {
      await MainActor.run { self.clearDebounce() }
      return
    }

    await MainActor.run {
      let now = Date()
      if self.lastCategoryRaw == result.category,
         let ts = self.lastCategoryTimestamp,
         now.timeIntervalSince(ts) >= 1.5 {
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
