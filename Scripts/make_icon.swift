import AppKit
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let s = CGFloat(size)
    NSColor(calibratedRed: 0.04, green: 0.16, blue: 0.18, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: s*0.04, y: s*0.04, width: s*0.92, height: s*0.92), xRadius: s*0.21, yRadius: s*0.21).fill()
    for offset in [0.0, 0.12] {
        NSColor(calibratedRed: 0.28+offset, green: 0.72+offset, blue: 0.62+offset, alpha: 1).setStroke()
        let p = NSBezierPath(roundedRect: NSRect(x: s*(0.23+offset), y: s*(0.21+offset), width: s*0.43, height: s*0.43), xRadius: s*0.07, yRadius: s*0.07)
        p.lineWidth = s*0.045; p.stroke()
    }
    NSColor(calibratedRed: 0.96, green: 0.84, blue: 0.43, alpha: 1).setFill()
    let star = NSBezierPath(); star.move(to: NSPoint(x:s*0.70,y:s*0.83)); star.line(to:NSPoint(x:s*0.74,y:s*0.74)); star.line(to:NSPoint(x:s*0.83,y:s*0.70)); star.line(to:NSPoint(x:s*0.74,y:s*0.66)); star.line(to:NSPoint(x:s*0.70,y:s*0.57)); star.line(to:NSPoint(x:s*0.66,y:s*0.66)); star.line(to:NSPoint(x:s*0.57,y:s*0.70)); star.line(to:NSPoint(x:s*0.66,y:s*0.74)); star.close(); star.fill()
    image.unlockFocus()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let png = rep.representation(using: .png, properties: [:])!
    if size <= 512 { try png.write(to: output.appendingPathComponent("icon_\(size)x\(size).png")) }
    if size >= 32 { try png.write(to: output.appendingPathComponent("icon_\(size/2)x\(size/2)@2x.png")) }
}
