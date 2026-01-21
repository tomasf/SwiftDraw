//
//  SVG+ShapeExtraction.swift
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

public import Foundation
import SwiftDrawDOM

public extension SVG {
    /// Extracts shapes from an SVG file using the provided consumer.
    static func extractShapes<C: SVGShapeConsumer>(
        from url: URL,
        using consumer: C,
        options: Options = .default
    ) throws -> C.Shape {
        let dom = try DOM.SVG.parse(fileURL: url)
        return extractShapes(from: dom, using: consumer, options: options)
    }

    /// Extracts shapes from SVG data using the provided consumer.
    static func extractShapes<C: SVGShapeConsumer>(
        from data: Data,
        using consumer: C,
        options: Options = .default
    ) throws -> C.Shape {
        let dom = try DOM.SVG.parse(data: data)
        return extractShapes(from: dom, using: consumer, options: options)
    }

    private static func extractShapes<C: SVGShapeConsumer>(
        from dom: DOM.SVG,
        using consumer: C,
        options: Options
    ) -> C.Shape {
        let layer = LayerTree.Builder(svg: dom).makeLayer()
        let extractor = SVGShapeExtractor(consumer: consumer)
        let shapes = extractor.extractShapes(from: layer, transform: .identity)
        return consumer.finalizeDocument(
            shapes: shapes,
            size: (width: Double(dom.width), height: Double(dom.height))
        )
    }
}

// MARK: - Internal Extractor

private struct SVGShapeExtractor<C: SVGShapeConsumer> {
    let consumer: C

    func extractShapes(
        from layer: LayerTree.Layer,
        transform: LayerTree.Transform.Matrix
    ) -> [C.Shape] {
        let combinedTransform = transform.concatenated(layer.transform.toMatrix())
        var output: [C.Shape] = []

        for content in layer.contents {
            switch content {
            case let .shape(shape, strokeAttributes, fillAttributes):
                let path = shape.path.applying(matrix: combinedTransform)
                if let shape = makeShape(path: path, stroke: strokeAttributes, fill: fillAttributes) {
                    output.append(shape)
                }

            case .layer(let nested):
                output.append(contentsOf: extractShapes(from: nested, transform: combinedTransform))

            default:
                continue
            }
        }

        return output
    }

    private func makeShape(
        path: LayerTree.Path,
        stroke: LayerTree.StrokeAttributes,
        fill: LayerTree.FillAttributes
    ) -> C.Shape? {
        var builder = consumer.makePathBuilder()

        for segment in path.segments {
            switch segment {
            case let .move(to: point):
                builder.move(to: consumer.makePoint(x: Double(point.x), y: Double(point.y)))

            case let .line(to: point):
                builder.line(to: consumer.makePoint(x: Double(point.x), y: Double(point.y)))

            case let .cubic(to: point, control1: control1, control2: control2):
                builder.cubic(
                    to: consumer.makePoint(x: Double(point.x), y: Double(point.y)),
                    control1: consumer.makePoint(x: Double(control1.x), y: Double(control1.y)),
                    control2: consumer.makePoint(x: Double(control2.x), y: Double(control2.y))
                )

            case .close:
                builder.close()
            }
        }

        let builtPath = builder.build()
        let fillInfo = makeFillInfo(from: fill)
        let strokeInfo = makeStrokeInfo(from: stroke)

        return consumer.makeShape(path: builtPath, fill: fillInfo, stroke: strokeInfo)
    }

    private func makeFillInfo(from fill: LayerTree.FillAttributes) -> SVGFillInfo? {
        let paint = makeFillPaint(from: fill.fill)

        // No fill if paint is none or opacity is zero
        guard paint != .none, fill.opacity > 0 else { return nil }

        return SVGFillInfo(
            paint: paint,
            opacity: Double(fill.opacity),
            rule: makeFillRule(from: fill.rule)
        )
    }

    private func makeStrokeInfo(from stroke: LayerTree.StrokeAttributes) -> SVGStrokeInfo? {
        guard stroke.width > 0 else { return nil }

        let paint = makeStrokePaint(from: stroke.color)
        guard paint != .none else { return nil }

        return SVGStrokeInfo(
            paint: paint,
            width: Double(stroke.width),
            lineCap: makeLineCap(from: stroke.cap),
            lineJoin: makeLineJoin(from: stroke.join),
            miterLimit: Double(stroke.miterLimit)
        )
    }

    // MARK: - Paint Conversions

    private func makeFillPaint(from fill: LayerTree.FillAttributes.Fill) -> SVGFillPaint {
        switch fill {
        case .color(let color):
            let svgColor = makeColor(from: color)
            return svgColor == .none ? .none : .color(svgColor)

        case .linearGradient(let gradient):
            return .linearGradient(makeLinearGradient(from: gradient))

        case .radialGradient(let gradient):
            return .radialGradient(makeRadialGradient(from: gradient))

        case .pattern(let pattern):
            return .pattern(makePattern(from: pattern))
        }
    }

    private func makeStrokePaint(from stroke: LayerTree.StrokeAttributes.Stroke) -> SVGStrokePaint {
        switch stroke {
        case .color(let color):
            let svgColor = makeColor(from: color)
            return svgColor == .none ? .none : .color(svgColor)

        case .linearGradient(let gradient):
            return .linearGradient(makeLinearGradient(from: gradient))

        case .radialGradient(let gradient):
            return .radialGradient(makeRadialGradient(from: gradient))
        }
    }

    // MARK: - Color Conversion

    private func makeColor(from color: LayerTree.Color) -> SVGColor {
        switch color {
        case .none:
            return .none
        case let .rgba(r, g, b, a, space):
            let colorSpace: SVGColorSpace = (space == .p3) ? .p3 : .sRGB
            return .rgba(r: Double(r), g: Double(g), b: Double(b), a: Double(a), space: colorSpace)
        case let .gray(white, a):
            return .gray(white: Double(white), a: Double(a))
        }
    }

    // MARK: - Gradient Conversion

    private func makeLinearGradient(from gradient: LayerTree.LinearGradient) -> SVGLinearGradient {
        SVGLinearGradient(
            stops: gradient.gradient.stops.map(makeGradientStop),
            start: SVGPoint(x: Double(gradient.start.x), y: Double(gradient.start.y)),
            end: SVGPoint(x: Double(gradient.end.x), y: Double(gradient.end.y)),
            units: makeGradientUnits(from: gradient.units),
            transform: makeTransformMatrix(from: gradient.transform)
        )
    }

    private func makeRadialGradient(from gradient: LayerTree.RadialGradient) -> SVGRadialGradient {
        SVGRadialGradient(
            stops: gradient.gradient.stops.map(makeGradientStop),
            center: SVGPoint(x: Double(gradient.center.x), y: Double(gradient.center.y)),
            radius: Double(gradient.radius),
            focalCenter: SVGPoint(x: Double(gradient.endCenter.x), y: Double(gradient.endCenter.y)),
            focalRadius: Double(gradient.endRadius),
            units: makeGradientUnits(from: gradient.units),
            transform: makeTransformMatrix(from: gradient.transform)
        )
    }

    private func makeGradientStop(from stop: LayerTree.Gradient.Stop) -> SVGGradientStop {
        SVGGradientStop(
            offset: Double(stop.offset),
            color: makeColor(from: stop.color),
            opacity: Double(stop.opacity)
        )
    }

    private func makeGradientUnits(from units: LayerTree.Gradient.Units) -> SVGGradientUnits {
        switch units {
        case .userSpaceOnUse:
            return .userSpaceOnUse
        case .objectBoundingBox:
            return .objectBoundingBox
        }
    }

    // MARK: - Pattern Conversion

    private func makePattern(from pattern: LayerTree.Pattern) -> SVGPattern {
        SVGPattern(frame: SVGRect(
            x: Double(pattern.frame.x),
            y: Double(pattern.frame.y),
            width: Double(pattern.frame.width),
            height: Double(pattern.frame.height)
        ))
    }

    // MARK: - Transform Conversion

    private func makeTransformMatrix(from transforms: [LayerTree.Transform]) -> SVGTransformMatrix {
        let matrix = transforms.toMatrix()
        return SVGTransformMatrix(
            a: Double(matrix.a),
            b: Double(matrix.b),
            c: Double(matrix.c),
            d: Double(matrix.d),
            tx: Double(matrix.tx),
            ty: Double(matrix.ty)
        )
    }

    // MARK: - Enum Conversions

    private func makeFillRule(from rule: LayerTree.FillRule) -> SVGFillRule {
        switch rule {
        case .nonzero:
            return .nonZero
        case .evenodd:
            return .evenOdd
        }
    }

    private func makeLineCap(from cap: LayerTree.LineCap) -> SVGLineCap {
        switch cap {
        case .butt:
            return .butt
        case .round:
            return .round
        case .square:
            return .square
        }
    }

    private func makeLineJoin(from join: LayerTree.LineJoin) -> SVGLineJoin {
        switch join {
        case .miter:
            return .miter
        case .round:
            return .round
        case .bevel:
            return .bevel
        }
    }
}
