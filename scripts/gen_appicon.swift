#!/usr/bin/env swift
// 앱 아이콘 생성 — 한지 위 네 기둥.
// 사용: swift scripts/gen_appicon.swift <출력 PNG 경로>

import AppKit
import CoreGraphics

let size = 1024.0
let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "App/FourEight/Assets.xcassets/AppIcon.appiconset/icon_1024.png"

func color(_ hex: UInt32) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// macOS 아이콘 관례: 여백을 두른 둥근 사각 판.
let margin = size * 0.098
let plate = CGRect(x: margin, y: margin, width: size - margin * 2, height: size - margin * 2)
let plateRadius = plate.width * 0.225

// 한지 판 — 살짝 따뜻한 종이색, 아래로 미세한 명암.
let platePath = CGPath(roundedRect: plate, cornerWidth: plateRadius, cornerHeight: plateRadius, transform: nil)
ctx.addPath(platePath)
ctx.clip()
let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [color(0xFBF8F1), color(0xF1EBDD)] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: size / 2, y: size - margin),
    end: CGPoint(x: size / 2, y: margin),
    options: []
)

// 네 기둥 — 오행 잉크 (청록·주사·황토·감청), 시일월년의 압축 상형.
let inks: [UInt32] = [0x00876B, 0xD84B2F, 0x8A5C03, 0x2E4E9C]
let barCount = 4.0
let barWidth = plate.width * 0.118
let barGap = plate.width * 0.072
let groupWidth = barWidth * barCount + barGap * (barCount - 1)
let baseX = plate.minX + (plate.width - groupWidth) / 2
let baseY = plate.minY + plate.height * 0.24
// 높낮이 리듬 — 명식의 들쭉날쭉한 기세.
let heights: [Double] = [0.42, 0.52, 0.36, 0.47]

for i in 0..<4 {
    let h = plate.height * heights[i]
    let rect = CGRect(
        x: baseX + Double(i) * (barWidth + barGap),
        y: baseY,
        width: barWidth,
        height: h
    )
    let path = CGPath(
        roundedRect: rect,
        cornerWidth: barWidth * 0.24, cornerHeight: barWidth * 0.24,
        transform: nil
    )
    ctx.addPath(path)
    ctx.setFillColor(color(inks[i]))
    ctx.fillPath()
}

// 바닥 기준선 — 지평의 먹선.
ctx.setFillColor(color(0x3A342C))
let baseline = CGRect(
    x: plate.minX + plate.width * 0.16,
    y: baseY - plate.height * 0.045,
    width: plate.width * 0.68,
    height: plate.height * 0.012
)
ctx.addPath(CGPath(roundedRect: baseline, cornerWidth: baseline.height / 2, cornerHeight: baseline.height / 2, transform: nil))
ctx.fillPath()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
