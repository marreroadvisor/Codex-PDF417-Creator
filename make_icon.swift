import AppKit

let canvas = NSImage(size: NSSize(width: 1024, height: 1024))
canvas.lockFocus()
NSColor(calibratedRed: 0.07, green: 0.17, blue: 0.38, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 190, yRadius: 190).fill()
let config = NSImage.SymbolConfiguration(pointSize: 620, weight: .bold)
let symbol = NSImage(systemSymbolName: "barcode", accessibilityDescription: "PDF417")!.withSymbolConfiguration(config)!
NSColor.white.set()
symbol.draw(in: NSRect(x: 135, y: 205, width: 754, height: 614))
canvas.unlockFocus()
let rep = NSBitmapImageRep(data: canvas.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
