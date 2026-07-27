#!/usr/bin/env swift
// 앱 아이콘 생성 — 한지 위의 명식.
//
// 네 기둥이 각각 천간과 지지 두 칸으로 서서 여덟 칸이 된다. 사주팔자이자
// 앱 이름이다. 일주 열에만 주사(朱砂) 테두리를 둘러 "나"를 표시한다.
//
// 사용: swift scripts/gen_appicon.swift <출력 PNG 경로>

import AppKit
import CoreGraphics

let size = 1024.0
let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "App/FourEight/Assets.xcassets/AppIcon.appiconset/icon_1024.png"

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

// 오행 잉크 — 앱의 라이트 모드 팔레트와 같은 값.
let wood: UInt32 = 0x00876B
let fire: UInt32 = 0xD8452B
let earth: UInt32 = 0x8A5C03
let metal: UInt32 = 0x6C7DD8
let water: UInt32 = 0x2E4E9C
let cinnabar: UInt32 = 0xB43A2E

let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// macOS 아이콘 관례의 둥근 사각 판.
let margin = size * 0.098
let plate = CGRect(x: margin, y: margin, width: size - margin * 2, height: size - margin * 2)
let plateRadius = plate.width * 0.225

ctx.saveGState()
ctx.addPath(CGPath(roundedRect: plate, cornerWidth: plateRadius, cornerHeight: plateRadius, transform: nil))
ctx.clip()
let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [color(0xFCF9F3), color(0xF0E9DA)] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: size / 2, y: size - margin),
    end: CGPoint(x: size / 2, y: margin),
    options: []
)
ctx.restoreGState()

// 여덟 칸. 열은 시일월년 순으로 서고, 위가 천간 아래가 지지다.
// 배열은 균형 잡힌 오행 분포를 따르되 일주 열(index 1)이 화·목이 되게 두었다.
let columns: [(stem: UInt32, branch: UInt32)] = [
    (metal, water),   // 시주
    (fire, wood),     // 일주 — 강조
    (wood, earth),    // 월주
    (water, fire),    // 년주
]
let dayColumn = 1

let cellW = plate.width * 0.152
let cellH = plate.height * 0.208
let colGap = plate.width * 0.052
let rowGap = plate.height * 0.030
let cellR = cellW * 0.26

let groupW = cellW * 4 + colGap * 3
let groupH = cellH * 2 + rowGap
let originX = plate.minX + (plate.width - groupW) / 2
let originY = plate.minY + (plate.height - groupH) / 2 + plate.height * 0.028

for (i, column) in columns.enumerated() {
    let x = originX + Double(i) * (cellW + colGap)

    for (row, ink) in [(1, column.stem), (0, column.branch)] {
        let y = originY + Double(row) * (cellH + rowGap)
        let rect = CGRect(x: x, y: y, width: cellW, height: cellH)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: cellR, cornerHeight: cellR, transform: nil))
        ctx.setFillColor(color(ink))
        ctx.fillPath()
    }
}

// 지반의 먹선. 일주 열 구간만 주사로 끊어 "나"의 자리를 표시한다.
//
// 열을 감싸는 테두리를 쓰면 시각 무게가 한쪽으로 쏠려 아이콘 전체가
// 기울어 보이고, 32pt 도크 크기에서는 잡음이 된다. 밑줄은 격자를
// 건드리지 않으면서 같은 정보를 전하고 작은 크기에서 자연스럽게 사라진다.
let baselineY = originY - plate.height * 0.077
let baselineH = plate.height * 0.0125
let baselineRect = CGRect(
    x: originX - cellW * 0.30, y: baselineY,
    width: groupW + cellW * 0.60, height: baselineH
)
ctx.setFillColor(color(0x3A342C))
ctx.addPath(CGPath(
    roundedRect: baselineRect,
    cornerWidth: baselineH / 2, cornerHeight: baselineH / 2,
    transform: nil
))
ctx.fillPath()

let markX = originX + Double(dayColumn) * (cellW + colGap)
let markH = baselineH * 2.1
let mark = CGRect(
    x: markX, y: baselineY - (markH - baselineH) / 2,
    width: cellW, height: markH
)
ctx.setFillColor(color(cinnabar))
ctx.addPath(CGPath(
    roundedRect: mark,
    cornerWidth: markH / 2, cornerHeight: markH / 2,
    transform: nil
))
ctx.fillPath()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
