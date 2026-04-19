import SwiftUI

extension Color {
  static let tlaneGreen      = Color(hex: "#2D6A4F") ?? .green
  static let tlaneEarth      = Color(hex: "#8B5E3C") ?? .brown
  static let tlaneBackground = Color(hex: "#F9F6F0") ?? .white
  static let tlaneContrast   = Color.white

  init?(hex: String) {
    var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.hasPrefix("#") { value.removeFirst() }

    // Soporta formatos RGB (3) y RRGGBB (6)
    guard value.count == 3 || value.count == 6 else { return nil }
    if value.count == 3 {
      value = value.map { "\($0)\($0)" }.joined()
    }

    var int: UInt64 = 0
    guard Scanner(string: value).scanHexInt64(&int) else { return nil }

    let r = Double((int & 0xFF0000) >> 16) / 255.0
    let g = Double((int & 0x00FF00) >> 8)  / 255.0
    let b = Double( int & 0x0000FF)        / 255.0

    self.init(red: r, green: g, blue: b)
  }
}
