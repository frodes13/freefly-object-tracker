/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Defines common types used throughout the sample.
*/

import Foundation
import UIKit
import Vision

enum TrackedObjectType: Int {
    case object
    case rectangle
}

enum TrackedPolyRectStyle: Int {
    case solid
    case dashed
}

struct TrackedObjectsPalette {
    static var palette = [
        UIColor.green,
        UIColor.cyan,
        UIColor.orange,
        UIColor.brown,
        UIColor.darkGray,
        UIColor.red,
        UIColor.yellow,
        UIColor.magenta,
        #colorLiteral(red: 0, green: 1, blue: 0, alpha: 1), // light green
        UIColor.gray,
        UIColor.purple,
        UIColor.clear,
        #colorLiteral(red: 0, green: 0.9800859094, blue: 0.941437602, alpha: 1),   // light blue
        UIColor.lightGray,
        UIColor.black,
        UIColor.blue
    ]
    
    static func color(atIndex index: Int) -> UIColor {
        if index < palette.count {
            return palette[index]
        }
        return randomColor()
    }
    
    static func randomColor() -> UIColor {
        func randomComponent() -> CGFloat {
            return CGFloat(arc4random_uniform(256)) / 255.0
        }
        return UIColor(red: randomComponent(), green: randomComponent(), blue: randomComponent(), alpha: 1.0)
    }
}

struct TrackedPolyRect {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomLeft: CGPoint
    var bottomRight: CGPoint
    var color: UIColor
    var style: TrackedPolyRectStyle
    
    var cornerPoints: [CGPoint] {
        return [topLeft, topRight, bottomRight, bottomLeft]
    }
    
    var boundingBox: CGRect {
        let topLeftRect = CGRect(origin: topLeft, size: .zero)
        let topRightRect = CGRect(origin: topRight, size: .zero)
        let bottomLeftRect = CGRect(origin: bottomLeft, size: .zero)
        let bottomRightRect = CGRect(origin: bottomRight, size: .zero)

        return topLeftRect.union(topRightRect).union(bottomLeftRect).union(bottomRightRect)
    }
    
    init(observation: VNDetectedObjectObservation, color: UIColor, style: TrackedPolyRectStyle = .solid) {
        self.init(cgRect: observation.boundingBox, color: color, style: style)
    }
    
    init(observation: VNRectangleObservation, color: UIColor, style: TrackedPolyRectStyle = .solid) {
        topLeft = observation.topLeft
        topRight = observation.topRight
        bottomLeft = observation.bottomLeft
        bottomRight = observation.bottomRight
        self.color = color
        self.style = style
    }

    init(cgRect: CGRect, color: UIColor, style: TrackedPolyRectStyle = .solid) {
        topLeft = CGPoint(x: cgRect.minX, y: cgRect.maxY)
        topRight = CGPoint(x: cgRect.maxX, y: cgRect.maxY)
        bottomLeft = CGPoint(x: cgRect.minX, y: cgRect.minY)
        bottomRight = CGPoint(x: cgRect.maxX, y: cgRect.minY)
        self.color = color
        self.style = style
    }
}

