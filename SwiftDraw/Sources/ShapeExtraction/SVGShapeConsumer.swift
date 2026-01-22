//
//  SVGShapeConsumer.swift
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

/// Protocol for consuming SVG shapes. Consumers provide their own types
/// and receive callbacks during extraction to build their representation.
public protocol SVGShapeConsumer {
    associatedtype Point
    associatedtype Path
    associatedtype Shape

    func makePoint(x: Double, y: Double) -> Point
    func makePathBuilder() -> any SVGPathBuilder<Point, Path>
    func makeShape(path: Path, fill: SVGFillInfo?, stroke: SVGStrokeInfo?) -> Shape?

    /// Creates a shape from text. Return nil to skip text rendering.
    func makeText(info: SVGTextInfo) -> Shape?

    func finalizeDocument(shapes: [Shape], size: (width: Double, height: Double)) -> Shape
}

public extension SVGShapeConsumer {
    /// Default implementation that skips text rendering.
    func makeText(info: SVGTextInfo) -> Shape? { nil }
}

/// Protocol for building paths from SVG path commands.
public protocol SVGPathBuilder<Point, Path> {
    associatedtype Point
    associatedtype Path

    mutating func move(to point: Point)
    mutating func line(to point: Point)
    mutating func cubic(to end: Point, control1: Point, control2: Point)
    mutating func close()
    func build() -> Path
}
