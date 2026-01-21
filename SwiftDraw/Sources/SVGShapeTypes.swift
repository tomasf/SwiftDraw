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

// MARK: - Color

public enum SVGColor: Sendable, Hashable {
    case none
    case rgba(r: Double, g: Double, b: Double, a: Double, space: SVGColorSpace)
    case gray(white: Double, a: Double)
}

public enum SVGColorSpace: Sendable, Hashable {
    case sRGB
    case p3
}

// MARK: - Gradients

public struct SVGGradientStop: Sendable, Hashable {
    public let offset: Double      // 0.0 - 1.0
    public let color: SVGColor
    public let opacity: Double

    public init(offset: Double, color: SVGColor, opacity: Double) {
        self.offset = offset
        self.color = color
        self.opacity = opacity
    }
}

public enum SVGGradientUnits: Sendable, Hashable {
    case userSpaceOnUse
    case objectBoundingBox
}

public struct SVGLinearGradient: Sendable, Hashable {
    public let stops: [SVGGradientStop]
    public let start: SVGPoint
    public let end: SVGPoint
    public let units: SVGGradientUnits
    public let transform: SVGTransformMatrix

    public init(stops: [SVGGradientStop], start: SVGPoint, end: SVGPoint, units: SVGGradientUnits, transform: SVGTransformMatrix) {
        self.stops = stops
        self.start = start
        self.end = end
        self.units = units
        self.transform = transform
    }
}

public struct SVGRadialGradient: Sendable, Hashable {
    public let stops: [SVGGradientStop]
    public let center: SVGPoint
    public let radius: Double
    public let focalCenter: SVGPoint    // Can differ from center
    public let focalRadius: Double
    public let units: SVGGradientUnits
    public let transform: SVGTransformMatrix

    public init(stops: [SVGGradientStop], center: SVGPoint, radius: Double, focalCenter: SVGPoint, focalRadius: Double, units: SVGGradientUnits, transform: SVGTransformMatrix) {
        self.stops = stops
        self.center = center
        self.radius = radius
        self.focalCenter = focalCenter
        self.focalRadius = focalRadius
        self.units = units
        self.transform = transform
    }
}

// MARK: - Pattern (simplified - frame only, contents not recursively exposed)

public struct SVGPattern: Sendable, Hashable {
    public let frame: SVGRect
    // Note: Pattern contents not exposed in v1 to avoid recursive complexity

    public init(frame: SVGRect) {
        self.frame = frame
    }
}

// MARK: - Paint (fill/stroke content)

public enum SVGFillPaint: Sendable, Hashable {
    case none
    case color(SVGColor)
    case linearGradient(SVGLinearGradient)
    case radialGradient(SVGRadialGradient)
    case pattern(SVGPattern)
}

public enum SVGStrokePaint: Sendable, Hashable {
    case none
    case color(SVGColor)
    case linearGradient(SVGLinearGradient)
    case radialGradient(SVGRadialGradient)
    // Note: SVG strokes don't support patterns
}

// MARK: - Fill & Stroke Info

public struct SVGFillInfo: Sendable, Hashable {
    public let paint: SVGFillPaint
    public let opacity: Double
    public let rule: SVGFillRule

    public init(paint: SVGFillPaint, opacity: Double, rule: SVGFillRule) {
        self.paint = paint
        self.opacity = opacity
        self.rule = rule
    }
}

public struct SVGStrokeInfo: Sendable, Hashable {
    public let paint: SVGStrokePaint
    public let width: Double
    public let lineCap: SVGLineCap
    public let lineJoin: SVGLineJoin
    public let miterLimit: Double

    public init(paint: SVGStrokePaint, width: Double, lineCap: SVGLineCap, lineJoin: SVGLineJoin, miterLimit: Double) {
        self.paint = paint
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

public struct SVGRect: Sendable, Hashable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct SVGTransformMatrix: Sendable, Hashable {
    public let a: Double
    public let b: Double
    public let c: Double
    public let d: Double
    public let tx: Double
    public let ty: Double

    public init(a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }

    public static let identity = SVGTransformMatrix(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
}
