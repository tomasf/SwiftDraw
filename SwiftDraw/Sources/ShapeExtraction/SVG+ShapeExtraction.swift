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

            case let .text(string, point, attributes):
                let textInfo = makeTextInfo(string: string, point: point, attributes: attributes, transform: combinedTransform)
                if let shape = consumer.makeText(info: textInfo) {
                    output.append(shape)
                }

            case .image:
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
        let hasFill = hasFillPaint(fill.fill)

        // No fill if paint is none or opacity is zero
        guard hasFill, fill.opacity > 0 else { return nil }

        return SVGFillInfo(
            hasFill: true,
            opacity: Double(fill.opacity),
            rule: makeFillRule(from: fill.rule)
        )
    }

    private func makeStrokeInfo(from stroke: LayerTree.StrokeAttributes) -> SVGStrokeInfo? {
        guard stroke.width > 0 else { return nil }

        let hasStroke = hasStrokePaint(stroke.color)
        guard hasStroke else { return nil }

        return SVGStrokeInfo(
            hasStroke: true,
            width: Double(stroke.width),
            lineCap: makeLineCap(from: stroke.cap),
            lineJoin: makeLineJoin(from: stroke.join),
            miterLimit: Double(stroke.miterLimit)
        )
    }

    // MARK: - Paint Detection

    private func hasFillPaint(_ fill: LayerTree.FillAttributes.Fill) -> Bool {
        switch fill {
        case .color(let color):
            return !isNoneColor(color)
        case .linearGradient, .radialGradient, .pattern:
            return true
        }
    }

    private func hasStrokePaint(_ stroke: LayerTree.StrokeAttributes.Stroke) -> Bool {
        switch stroke {
        case .color(let color):
            return !isNoneColor(color)
        case .linearGradient, .radialGradient:
            return true
        }
    }

    private func isNoneColor(_ color: LayerTree.Color) -> Bool {
        if case .none = color {
            return true
        }
        return false
    }

    // MARK: - Text Conversion

    private func makeTextInfo(
        string: String,
        point: LayerTree.Point,
        attributes: LayerTree.TextAttributes,
        transform: LayerTree.Transform.Matrix
    ) -> SVGTextInfo {
        // Apply transform to the text position
        let transformedPoint = transform.transform(point: point)

        return SVGTextInfo(
            content: string,
            position: SVGPoint(x: Double(transformedPoint.x), y: Double(transformedPoint.y)),
            fontName: attributes.fontName,
            fontSize: Double(attributes.size),
            anchor: makeTextAnchor(from: attributes.anchor)
        )
    }

    private func makeTextAnchor(from anchor: DOM.TextAnchor) -> SVGTextAnchor {
        switch anchor {
        case .start:
            return .start
        case .middle:
            return .middle
        case .end:
            return .end
        }
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
