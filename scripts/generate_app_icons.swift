import AppKit
import ImageIO
import Foundation
let root = FileManager.default.currentDirectoryPath
let url = URL(fileURLWithPath: root + "/assets/branding/pals_app_icon.png")
let source = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(url as CFURL, nil)!, 0, nil)!
func save(_ size: Int, _ path: String) {
 let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
 ctx.interpolationQuality = .high
 ctx.draw(source, in: CGRect(x: 0, y: 0, width: size, height: size))
 let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: root + "/" + path) as CFURL, "public.png" as CFString, 1, nil)!
 CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
 assert(CGImageDestinationFinalize(dest))
}
let dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
let data = try! Data(contentsOf: URL(fileURLWithPath: root + "/" + dir + "Contents.json"))
let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
for entry in json["images"] as! [[String:String]] {
 let size = Double(entry["size"]!.split(separator: "x")[0])!
 let scale = Double(entry["scale"]!.dropLast())!
 save(Int(size * scale), dir + entry["filename"]!)
}
for (density,size) in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)] {
 save(size,"android/app/src/main/res/mipmap-\(density)/ic_launcher.png")
}
print("Generated iOS and Android icons")
