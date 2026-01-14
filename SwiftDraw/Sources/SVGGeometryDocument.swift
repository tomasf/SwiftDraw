public import Foundation
import SwiftDrawDOM

public struct SVGGeometryDocument: Sendable, Hashable {
    public struct Size: Sendable, Hashable {
        public var width: Double
        public var height: Double

        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
    }

    public struct Point: Sendable, Hashable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public enum FillRule: Sendable, Hashable {
        case nonZero
        case evenOdd
    }

    public enum LineJoin: Sendable, Hashable {
        case miter
        case round
        case bevel
    }

    public enum LineCap: Sendable, Hashable {
        case butt
        case round
        case square
    }

    public struct Stroke: Sendable, Hashable {
        public var width: Double
        public var lineCap: LineCap
        public var lineJoin: LineJoin
        public var miterLimit: Double

        public init(width: Double, lineCap: LineCap, lineJoin: LineJoin, miterLimit: Double) {
            self.width = width
            self.lineCap = lineCap
            self.lineJoin = lineJoin
            self.miterLimit = miterLimit
        }
    }

    public enum PathSegment: Sendable, Hashable {
        case move(to: Point)
        case line(to: Point)
        case cubic(to: Point, control1: Point, control2: Point)
        case close
    }

    public struct Path: Sendable, Hashable {
        public var segments: [PathSegment]

        public init(segments: [PathSegment]) {
            self.segments = segments
        }
    }

    public struct Shape: Sendable, Hashable {
        public var path: Path
        public var fillRule: FillRule
        public var hasFill: Bool
        public var stroke: Stroke?

        public init(path: Path, fillRule: FillRule, hasFill: Bool, stroke: Stroke?) {
            self.path = path
            self.fillRule = fillRule
            self.hasFill = hasFill
            self.stroke = stroke
        }
    }

    public var size: Size
    public var shapes: [Shape]

    public init?(fileURL url: URL, options: SVG.Options = .default) {
        do {
            let dom = try DOM.SVG.parse(fileURL: url)
            self.init(dom: dom, options: options)
        } catch {
            return nil
        }
    }

    public init?(data: Data, options: SVG.Options = .default) {
        do {
            let dom = try DOM.SVG.parse(data: data)
            self.init(dom: dom, options: options)
        } catch {
            return nil
        }
    }

    public init?(xml: String, options: SVG.Options = .default) {
        guard let data = xml.data(using: .utf8) else { return nil }
        self.init(data: data, options: options)
    }

    private init(dom: DOM.SVG, options: SVG.Options) {
        size = Size(width: Double(dom.width), height: Double(dom.height))
        let layer = LayerTree.Builder(svg: dom).makeLayer()
        shapes = Self.makeShapes(from: layer)
    }
}

private extension SVGGeometryDocument {
    static func makeShapes(from layer: LayerTree.Layer) -> [Shape] {
        collectShapes(from: layer, transform: .identity)
    }

    static func collectShapes(from layer: LayerTree.Layer,
                              transform: LayerTree.Transform.Matrix) -> [Shape] {
        let combinedTransform = transform.concatenated(layer.transform.toMatrix())
        var output: [Shape] = []

        for content in layer.contents {
            switch content {
            case let .shape(shape, strokeAttributes, fillAttributes):
                let path = shape.path.applying(matrix: combinedTransform)
                let fillRule = FillRule(layerRule: fillAttributes.rule)
                let hasFill = fillAttributes.opacity > 0 && fillAttributes.fill.isVisible
                let stroke = Stroke(strokeAttributes)
                output.append(
                    Shape(
                        path: Path(path),
                        fillRule: fillRule,
                        hasFill: hasFill,
                        stroke: stroke
                    )
                )

            case .layer(let nested):
                output.append(contentsOf: collectShapes(from: nested, transform: combinedTransform))

            default:
                continue
            }
        }

        return output
    }
}

private extension SVGGeometryDocument.Point {
    init(_ point: LayerTree.Point) {
        self.init(x: Double(point.x), y: Double(point.y))
    }
}

private extension SVGGeometryDocument.Path {
    init(_ path: LayerTree.Path) {
        segments = path.segments.map { segment in
            switch segment {
            case let .move(to: point):
                return .move(to: .init(point))
            case let .line(to: point):
                return .line(to: .init(point))
            case let .cubic(to: point, control1: control1, control2: control2):
                return .cubic(to: .init(point), control1: .init(control1), control2: .init(control2))
            case .close:
                return .close
            }
        }
    }
}

private extension SVGGeometryDocument.FillRule {
    init(layerRule: LayerTree.FillRule) {
        switch layerRule {
        case .nonzero:
            self = .nonZero
        case .evenodd:
            self = .evenOdd
        }
    }
}

private extension SVGGeometryDocument.Stroke {
    init?(_ attributes: LayerTree.StrokeAttributes) {
        guard attributes.width > 0, attributes.color.isVisible else { return nil }
        self.init(
            width: Double(attributes.width),
            lineCap: SVGGeometryDocument.LineCap(layerCap: attributes.cap),
            lineJoin: SVGGeometryDocument.LineJoin(layerJoin: attributes.join),
            miterLimit: Double(attributes.miterLimit)
        )
    }
}

private extension SVGGeometryDocument.LineJoin {
    init(layerJoin: LayerTree.LineJoin) {
        switch layerJoin {
        case .miter:
            self = .miter
        case .round:
            self = .round
        case .bevel:
            self = .bevel
        }
    }
}

private extension SVGGeometryDocument.LineCap {
    init(layerCap: LayerTree.LineCap) {
        switch layerCap {
        case .butt:
            self = .butt
        case .round:
            self = .round
        case .square:
            self = .square
        }
    }
}

private extension LayerTree.FillAttributes.Fill {
    var isVisible: Bool {
        switch self {
        case .color(let color):
            return color.isVisible
        case .pattern, .linearGradient, .radialGradient:
            return true
        }
    }
}

private extension LayerTree.StrokeAttributes.Stroke {
    var isVisible: Bool {
        switch self {
        case .color(let color):
            return color.isVisible
        case .linearGradient, .radialGradient:
            return true
        }
    }
}

private extension LayerTree.Color {
    var isVisible: Bool {
        switch self {
        case .none:
            return false
        case .rgba(_, _, _, let alpha, _):
            return alpha > 0
        case .gray(_, let alpha):
            return alpha > 0
        }
    }
}
