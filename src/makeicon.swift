import Cocoa

// Achromatic to match the till itself: ink ground, white marks. A sticker
// (peeling corner) over a 3D-printed cube — what the bazaar actually sells.
let size = 1024.0
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)
NSBezierPath(roundedRect: rect, xRadius: size*0.225, yRadius: size*0.225).addClip()
NSColor(srgbRed: 0.039, green: 0.039, blue: 0.039, alpha: 1).setFill()   // #0a0a0a
rect.fill()

let white = NSColor.white
let ink   = NSColor(srgbRed: 0.039, green: 0.039, blue: 0.039, alpha: 1)

// isometric cube, lower left
func poly(_ pts: [NSPoint], _ c: NSColor) {
    let p = NSBezierPath(); p.move(to: pts[0])
    pts.dropFirst().forEach { p.line(to: $0) }
    p.close(); c.setFill(); p.fill()
}
let cx = size*0.38, cy = size*0.33, w = size*0.20, h = size*0.115
poly([NSPoint(x:cx,y:cy+h*2), NSPoint(x:cx+w,y:cy+h*3), NSPoint(x:cx+w*2,y:cy+h*2), NSPoint(x:cx+w,y:cy+h)], white)
poly([NSPoint(x:cx,y:cy+h*2), NSPoint(x:cx+w,y:cy+h), NSPoint(x:cx+w,y:cy-h), NSPoint(x:cx,y:cy)],
     white.withAlphaComponent(0.72))
poly([NSPoint(x:cx+w*2,y:cy+h*2), NSPoint(x:cx+w,y:cy+h), NSPoint(x:cx+w,y:cy-h), NSPoint(x:cx+w*2,y:cy)],
     white.withAlphaComponent(0.45))

// sticker: rounded square with a peeled corner, upper right
let sx = size*0.46, sy = size*0.52, ss = size*0.34
let sticker = NSBezierPath(roundedRect: NSRect(x: sx, y: sy, width: ss, height: ss),
                           xRadius: ss*0.22, yRadius: ss*0.22)
white.setFill(); sticker.fill()
// peel
poly([NSPoint(x:sx+ss*0.70,y:sy), NSPoint(x:sx+ss,y:sy), NSPoint(x:sx+ss,y:sy+ss*0.30)], ink)
poly([NSPoint(x:sx+ss*0.70,y:sy), NSPoint(x:sx+ss,y:sy+ss*0.30), NSPoint(x:sx+ss*0.86,y:sy+ss*0.16)],
     white.withAlphaComponent(0.55))
// star on the sticker
let star = NSBezierPath()
let scx = sx+ss*0.44, scy = sy+ss*0.56, r1 = ss*0.22, r2 = ss*0.095
for i in 0..<10 {
    let a = Double(i) * .pi/5 - .pi/2
    let r = i % 2 == 0 ? r1 : r2
    let pt = NSPoint(x: scx + CGFloat(cos(a))*r, y: scy + CGFloat(sin(a))*r)
    if i == 0 { star.move(to: pt) } else { star.line(to: pt) }
}
star.close(); ink.setFill(); star.fill()

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed\n".data(using: .utf8)!); exit(1)
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
