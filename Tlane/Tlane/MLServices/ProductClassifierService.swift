import Vision
import UIKit
import CoreML

struct ClassificationResult {
  let category: String        // en español, mapeado
  let confidence: Float
  let rawLabel: String        // lo que devolvió el modelo
  var confidencePercent: Int { Int((confidence * 100).rounded()) }
}

enum ClassifierError: Error {
  case invalidImage
  case modelLoadFailed
  case visionFailed(Error)
}

struct ProductClassifierService {

  // Umbral mínimo de confianza. Debajo de esto → "otro"
  // Ajústalo si después de probar ves falsos positivos o falsos negativos.
  private let confidenceThreshold: Float = 0.80

  /// Mapa de nombre-de-carpeta → categoría Tlane que muestra la UI.
  /// Cambia estos según los nombres reales de tus carpetas en Create ML.
  private let labelToCategory: [String: String] = [
    "piramide":  "Escultura de Piedra",
    "llavero":  "Llavero",
    "tortuga":  "Escultura de Onix",
    "otro":     "otro"
  ]

  func classify(image: UIImage) async throws -> ClassificationResult {
    guard let cgImage = image.cgImage else {
      throw ClassifierError.invalidImage
    }

    // Cargar modelo compilado que Xcode generó automáticamente
    let config = MLModelConfiguration()
    config.computeUnits = .all
    guard let model = try? TlaneClassifier1(configuration: config),
          let visionModel = try? VNCoreMLModel(for: model.model) else {
      throw ClassifierError.modelLoadFailed
    }

    return try await withCheckedThrowingContinuation { continuation in
      let request = VNCoreMLRequest(model: visionModel) { request, error in
        if let error {
          continuation.resume(throwing: ClassifierError.visionFailed(error))
          return
        }

        let observations = (request.results as? [VNClassificationObservation]) ?? []
        let result = self.interpret(observations: observations)
        continuation.resume(returning: result)
      }
      request.imageCropAndScaleOption = .centerCrop

      let handler = VNImageRequestHandler(
        cgImage: cgImage,
        orientation: cgOrientation(from: image.imageOrientation)
      )
      do {
        try handler.perform([request])
      } catch {
        continuation.resume(throwing: ClassifierError.visionFailed(error))
      }
    }
  }

  // MARK: - Private

  private func interpret(observations: [VNClassificationObservation]) -> ClassificationResult {
    guard let top = observations.first else {
      return ClassificationResult(category: "otro", confidence: 0, rawLabel: "empty")
    }

    let label = top.identifier.lowercased()

    // Si la predicción top es "otro" o no supera el umbral → devolvemos "otro"
    if label == "otro" || top.confidence < confidenceThreshold {
      return ClassificationResult(
        category: "otro",
        confidence: top.confidence,
        rawLabel: top.identifier
      )
    }

    let category = labelToCategory[label] ?? "otro"
    return ClassificationResult(
      category: category,
      confidence: top.confidence,
      rawLabel: top.identifier
    )
  }

  private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch uiOrientation {
    case .up:            .up
    case .down:          .down
    case .left:          .left
    case .right:         .right
    case .upMirrored:    .upMirrored
    case .downMirrored:  .downMirrored
    case .leftMirrored:  .leftMirrored
    case .rightMirrored: .rightMirrored
    @unknown default:    .up
    }
  }
}
