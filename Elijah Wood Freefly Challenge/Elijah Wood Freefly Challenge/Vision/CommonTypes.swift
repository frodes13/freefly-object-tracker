//
//  CommonTypes.swift
//  Elijah Wood Freefly Challenge
//
//  Created by Elijah Wood on 2/18/19.
//  Based on Vision sample by Apple Inc.
//  Copyright © 2019 Frodes. All rights reserved.
//

import Foundation
import UIKit
import Vision

enum TrackedPolyRectStyle: Int {
    case solid
    case dashed
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

