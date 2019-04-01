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

// Freefly Movi Color (#ee715d)
var MOVI_ORANGE_COLOR: UIColor = UIColor(red: 238/255, green: 113/255, blue: 93/255, alpha: 1)

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

// Limit to pan / tilt
struct MoviMoveRate {
    var pan: Float
    var tilt: Float
    
    init(mPan: Float, mTilt: Float) {
        pan = mPan
        tilt = mTilt
    }
}

// LIMITED in its current form, QUICK DEMO PURPOSES
struct MoviRXButtonStates {
    /*
     QX.BTN_TOP
     QX.BTN_TRIGGER
     QX.BTN_CENTER
     QX.BTN_LEFT
     QX.BTN_RIGHT
     QX.BTN_DOWN
     QX.BTN_UP
    */
    
    var BTN_TOP: QX.BTN
    var BTN_TRIGGER: QX.BTN
    var BTN_CENTER: QX.BTN
//    var BTN_LEFT: QX.BTN
//    var BTN_RIGHT: QX.BTN
//    var BTN_DOWN: QX.BTN
//    var BTN_UP: QX.BTN
    
    // There's a better way to do this
    // Limited in its current form
    init(_ event: QX.Event) {
        if (event.isButtonEvent(QX.BTN_TOP, QX.BTN.PRESS)) {
            BTN_TOP = QX.BTN.PRESS
        } else {
            BTN_TOP = QX.BTN.RELEASE
        }
        if (event.isButtonEvent(QX.BTN_TRIGGER, QX.BTN.PRESS)) {
            BTN_TRIGGER = QX.BTN.PRESS
        } else {
            BTN_TRIGGER = QX.BTN.RELEASE
        }
        if (event.isButtonEvent(QX.BTN_CENTER, QX.BTN.PRESS)) {
            BTN_CENTER = QX.BTN.PRESS
        } else {
            BTN_CENTER = QX.BTN.RELEASE
        }
    }
    
    init() {
        // Set initial state
        BTN_TOP = QX.BTN.RELEASE
        BTN_TRIGGER = QX.BTN.RELEASE
        BTN_CENTER = QX.BTN.RELEASE
    }

    func isEqual(_ to: MoviRXButtonStates) -> Bool {
        if (BTN_TOP == to.BTN_TOP
            && BTN_TRIGGER == to.BTN_TRIGGER
            && BTN_CENTER == to.BTN_CENTER) {
            return true
        }
        return false
    }
}
