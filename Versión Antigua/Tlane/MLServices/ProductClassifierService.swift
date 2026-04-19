import Vision
import UIKit

struct ClassificationResult {
  let category: String        // mapeado a español: textil/barro/madera/joyería/otro
  let confidence: Float       // 0.0 - 1.0
  let rawLabel: String        // label original de Apple, para debug

  var confidencePercent: Int {
    Int((confidence * 100).rounded())
  }
}

enum ClassifierError: Error {
  case invalidImage
  case visionFailed(Error)
}

struct ProductClassifierService {

  /// Umbral mínimo para aceptar una sugerencia. Por debajo → "otro".
  private let confidenceThreshold: Float = 0.15

  /// Mapa de keywords (en label original de Apple) a categoría Tlane.
  /// La búsqueda es por `contains`, no por equality.
  private let categoryKeywords: [(keywords: [String], category: String)] = [
    (["textile", "fabric", "cloth", "rug", "carpet", "tapestry",
      "blanket", "scarf", "shawl", "weaving", "poncho", "quilt"],
     "textil"),
    (["pottery", "ceramic", "vase", "pot", "bowl", "clay",
      "earthenware", "jug", "jar", "mug", "cup", "saucer", "plate"],
     "barro"),
    (["wood", "wooden", "carving", "sculpture", "figurine",
      "mask", "box", "spoon", "bowl_wood"],
     "madera"),
    (["jewelry", "necklace", "earring", "bracelet", "ring",
      "pendant", "bead", "chain"],
     "joyería")
  ]

  func classify(image: UIImage) async throws -> ClassificationResult {
    guard let cgImage = image.cgImage else {
      throw ClassifierError.invalidImage
    }

    return try await withCheckedThrowingContinuation { continuation in
      let request = VNClassifyImageRequest { request, error in
        if let error {
          continuation.resume(throwing: ClassifierError.visionFailed(error))
          return
        }

        let observations = (request.results as? [VNClassificationObservation]) ?? []
        let result = self.mapObservations(observations)
        continuation.resume(returning: result)
      }

      let handler = VNImageRequestHandler(
        cgImage: cgImage,
        orientation: cgOrientation(from: image.imageOrientation),
        options: [:]
      )

      do {
        try handler.perform([request])
      } catch {
        continuation.resume(throwing: ClassifierError.visionFailed(error))
      }
    }
  }

  // MARK: - Private

  private func mapObservations(
    _ observations: [VNClassificationObservation]
  ) -> ClassificationResult {
    // Tomamos top 10 para tener margen — los primeros resultados de Apple
    // suelen ser muy genéricos ("object", "material").
    let top = observations.prefix(10)

    for obs in top {
      let label = obs.identifier.lowercased()
      for entry in categoryKeywords {
        if entry.keywords.contains(where: { label.contains($0) }),
           obs.confidence >= confidenceThreshold {
          return ClassificationResult(
            category: entry.category,
            confidence: obs.confidence,
            rawLabel: obs.identifier
          )
        }
      }
    }

    // Nada match — devolvemos "otro" con el label top para debug
    let topLabel = observations.first?.identifier ?? "unknown"
    let topConfidence = observations.first?.confidence ?? 0
    return ClassificationResult(
      category: "otro",
      confidence: topConfidence,
      rawLabel: topLabel
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
