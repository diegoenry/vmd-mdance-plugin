// The windows of a process (macOS), a line each:
//   id x y width height layer onscreen name
// figures.tcl finds the VMDance window among VMD's, and screencapture -l
// takes that window alone (its own pixels, whatever is over it).
//   swiftc -O -o build/macos_windows macos_windows.swift   (make figures does it)
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2, let pid = Int32(CommandLine.arguments[1]) else {
    FileHandle.standardError.write("usage: macos_windows pid\n".data(using: .utf8)!)
    exit(2)
}
let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
    guard let p = w[kCGWindowOwnerPID as String] as? Int32, p == pid else { continue }
    let num = w[kCGWindowNumber as String] as? Int ?? 0
    let b = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let layer = w[kCGWindowLayer as String] as? Int ?? 0
    let on = w[kCGWindowIsOnscreen as String] as? Bool ?? false
    let name = w[kCGWindowName as String] as? String ?? "-"
    print("\(num) \(b["X"] ?? 0) \(b["Y"] ?? 0) \(b["Width"] ?? 0) \(b["Height"] ?? 0) \(layer) \(on) \(name)")
}
