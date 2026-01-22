//
//  SVGShapeTypes.swift
//  SwiftDraw
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/swhitty/SwiftDraw
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

// MARK: - Fill & Stroke Info

public struct SVGFillInfo: Sendable, Hashable {
    public let hasFill: Bool
    public let opacity: Double
    public let rule: SVGFillRule

    public init(hasFill: Bool, opacity: Double, rule: SVGFillRule) {
        self.hasFill = hasFill
        self.opacity = opacity
        self.rule = rule
    }
}

public struct SVGStrokeInfo: Sendable, Hashable {
    public let hasStroke: Bool
    public let width: Double
    public let lineCap: SVGLineCap
    public let lineJoin: SVGLineJoin
    public let miterLimit: Double

    public init(hasStroke: Bool, width: Double, lineCap: SVGLineCap, lineJoin: SVGLineJoin, miterLimit: Double) {
        self.hasStroke = hasStroke
        self.width = width
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = miterLimit
    }
}

// MARK: - Enums

public enum SVGFillRule: Sendable, Hashable {
    case nonZero
    case evenOdd
}

public enum SVGLineCap: Sendable, Hashable {
    case butt
    case round
    case square
}

public enum SVGLineJoin: Sendable, Hashable {
    case miter
    case round
    case bevel
}

// MARK: - Geometry primitives

public struct SVGPoint: Sendable, Hashable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

// MARK: - Text

public struct SVGTextInfo: Sendable, Hashable {
    public let content: String
    public let position: SVGPoint
    public let fontName: String
    public let fontSize: Double
    public let anchor: SVGTextAnchor

    public init(content: String, position: SVGPoint, fontName: String, fontSize: Double, anchor: SVGTextAnchor) {
        self.content = content
        self.position = position
        self.fontName = fontName
        self.fontSize = fontSize
        self.anchor = anchor
    }
}

public enum SVGTextAnchor: Sendable, Hashable {
    case start   // left-aligned
    case middle  // center-aligned
    case end     // right-aligned
}
