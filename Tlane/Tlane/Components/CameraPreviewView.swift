import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
  let session: AVCaptureSession

  #if targetEnvironment(simulator)
  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.backgroundColor = UIColor(white: 0.12, alpha: 1.0)

    let label = UILabel()
    label.text = "Cámara no disponible en Simulator"
    label.textColor = .white
    label.font = .systemFont(ofSize: 16, weight: .medium)
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
    ])
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {}

  #else
  func makeUIView(context: Context) -> PreviewLayerView {
    let view = PreviewLayerView()
    view.setSession(session)
    return view
  }

  func updateUIView(_ uiView: PreviewLayerView, context: Context) {}

  /// Llamado por SwiftUI al destruir la vista — detiene la sesión en background
  /// para liberar el hardware de la cámara correctamente.
  static func dismantleUIView(_ uiView: PreviewLayerView, coordinator: ()) {
    Task.detached {
      uiView.session?.stopRunning()
    }
  }

  final class PreviewLayerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    // ↓ CAMBIO: `weak` → strong. Con `weak`, la referencia ya era nil
    //   cuando SwiftUI llamaba dismantleUIView, y stopRunning() nunca se ejecutaba.
    var session: AVCaptureSession?

    func setSession(_ session: AVCaptureSession) {
      guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else { return }
      self.session = session
      previewLayer.session = session
      previewLayer.videoGravity = .resizeAspectFill
    }
  }
  #endif
}
