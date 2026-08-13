import AppKit

let canvas = NSSize(width: 81, height: 81)
let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  .appendingPathComponent("assets", isDirectory: true)

enum TabIcon: String, CaseIterable {
  case stub
  case trip
  case wall
  case profile
}

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
  NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func configureStroke(_ path: NSBezierPath, color: NSColor, width: CGFloat = 4.6) {
  path.lineWidth = width
  path.lineCapStyle = .round
  path.lineJoinStyle = .round
  color.setStroke()
}

func draw(_ icon: TabIcon, color: NSColor) {
  switch icon {
  case .stub:
    let ticket = roundedRect(NSRect(x: 18, y: 16, width: 45, height: 49), radius: 7)
    configureStroke(ticket, color: color)
    ticket.stroke()

    let dash = NSBezierPath()
    dash.move(to: NSPoint(x: 27, y: 48))
    dash.line(to: NSPoint(x: 54, y: 48))
    dash.move(to: NSPoint(x: 27, y: 37))
    dash.line(to: NSPoint(x: 48, y: 37))
    dash.move(to: NSPoint(x: 27, y: 27))
    dash.line(to: NSPoint(x: 42, y: 27))
    configureStroke(dash, color: color, width: 4)
    dash.stroke()

  case .trip:
    let book = NSBezierPath()
    book.move(to: NSPoint(x: 15, y: 60))
    book.curve(to: NSPoint(x: 39, y: 54), controlPoint1: NSPoint(x: 24, y: 62), controlPoint2: NSPoint(x: 33, y: 58))
    book.line(to: NSPoint(x: 39, y: 18))
    book.curve(to: NSPoint(x: 15, y: 24), controlPoint1: NSPoint(x: 31, y: 22), controlPoint2: NSPoint(x: 23, y: 26))
    book.close()
    book.move(to: NSPoint(x: 66, y: 60))
    book.curve(to: NSPoint(x: 42, y: 54), controlPoint1: NSPoint(x: 57, y: 62), controlPoint2: NSPoint(x: 48, y: 58))
    book.line(to: NSPoint(x: 42, y: 18))
    book.curve(to: NSPoint(x: 66, y: 24), controlPoint1: NSPoint(x: 50, y: 22), controlPoint2: NSPoint(x: 58, y: 26))
    book.close()
    configureStroke(book, color: color)
    book.stroke()

  case .wall:
    for row in 0..<2 {
      for column in 0..<2 {
        let rect = NSRect(x: 16 + CGFloat(column) * 27, y: 16 + CGFloat(row) * 27, width: 21, height: 21)
        let tile = roundedRect(rect, radius: 4)
        configureStroke(tile, color: color, width: 4.2)
        tile.stroke()
      }
    }

  case .profile:
    let head = NSBezierPath(ovalIn: NSRect(x: 31, y: 45, width: 19, height: 19))
    configureStroke(head, color: color)
    head.stroke()

    let shoulders = NSBezierPath()
    shoulders.move(to: NSPoint(x: 18, y: 18))
    shoulders.curve(to: NSPoint(x: 63, y: 18), controlPoint1: NSPoint(x: 23, y: 39), controlPoint2: NSPoint(x: 58, y: 39))
    configureStroke(shoulders, color: color)
    shoulders.stroke()
  }
}

func render(icon: TabIcon, active: Bool) throws {
  let image = NSImage(size: canvas)
  image.lockFocus()
  NSGraphicsContext.current?.imageInterpolation = .high
  let color = NSColor(calibratedRed: active ? 185 / 255 : 109 / 255,
                      green: active ? 71 / 255 : 98 / 255,
                      blue: active ? 56 / 255 : 88 / 255,
                      alpha: 1)
  draw(icon, color: color)
  image.unlockFocus()

  guard let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "StubTabIcons", code: 1)
  }

  let suffix = active ? "-active" : ""
  let destination = outputDirectory.appendingPathComponent("tab-\(icon.rawValue)\(suffix).png")
  try png.write(to: destination)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
for icon in TabIcon.allCases {
  try render(icon: icon, active: false)
  try render(icon: icon, active: true)
}

print("Generated \(TabIcon.allCases.count * 2) tab bar icons in \(outputDirectory.path)")
