//
//  VisionTrackerProcessor.swift
//  Elijah Wood Freefly Challenge
//
//  Created by Elijah Wood on 2/18/19.
//  Based on Vision sample by Apple Inc.
//  Copyright © 2019 Frodes. All rights reserved.
//

import AVFoundation
import UIKit
import Vision

enum VisionTrackerProcessorError: Error {
    case readerInitializationFailed
    case firstFrameReadFailed
    case objectTrackingFailed
    case rectangleDetectionFailed
}

protocol VisionTrackerProcessorDelegate: class {
    func displayFrame(_ rects: [TrackedPolyRect]?)
}

class VisionTrackerProcessor {
    var trackingLevel = VNRequestTrackingLevel.accurate
    var objectsToTrack = [TrackedPolyRect]()
    weak var delegate: VisionTrackerProcessorDelegate?
    var centerDetectedObservation: CGPoint = CGPoint.zero // Keep this updated to indicate the center of our detected observation
    var centerDetectionActive: Bool = false
    
    private var initialRectObservations = [VNRectangleObservation]()
    
    // Declare initial observations
    private var inputObservations = [UUID: VNDetectedObjectObservation]()
    private var trackedObjects = [UUID: TrackedPolyRect]()
    private var requestHandler: VNSequenceRequestHandler!
    private var trackingFailedForAtLeastOneObject = false
    private var didInitialize = false
    
    // MARK: InitializeTrackerProcessor
    func initializeTrackerProcessor() {
        inputObservations = [UUID: VNDetectedObjectObservation]()
        trackedObjects = [UUID: TrackedPolyRect]()
        
        for rect in self.objectsToTrack {
            let inputObservation = VNDetectedObjectObservation(boundingBox: rect.boundingBox)
            inputObservations[inputObservation.uuid] = inputObservation
            trackedObjects[inputObservation.uuid] = rect
        }
        
        requestHandler = VNSequenceRequestHandler()
    
        didInitialize = true
    }

    // MARK: ProcessFrame
    func processFrame(frame: CVPixelBuffer) throws {
        // Confirm proper initialization
        if (!didInitialize) {
            initializeTrackerProcessor()
            return
        }
        
        var rects = [TrackedPolyRect]()
        var trackingRequests = [VNRequest]()
        for inputObservation in inputObservations {
            let request = VNTrackObjectRequest(detectedObjectObservation: inputObservation.value)
            request.trackingLevel = trackingLevel
         
            trackingRequests.append(request)
        }
        
        // Perform array of requests
        do {
            try requestHandler.perform(trackingRequests, on: frame, orientation: .up)
        } catch {
            print(error)
            trackingFailedForAtLeastOneObject = true
            return
        }

        for processedRequest in trackingRequests {
            guard let results = processedRequest.results as? [VNObservation] else {
                continue
            }
            guard let observation = results.first as? VNDetectedObjectObservation else {
                continue
            }
            // Assume threshold = 0.5f
            let rectStyle: TrackedPolyRectStyle = observation.confidence > 0.5 ? .solid : .dashed
            let knownRect = trackedObjects[observation.uuid]!
            rects.append(TrackedPolyRect(observation: observation, color: knownRect.color, style: rectStyle))
            
            // Initialize inputObservation for the next iteration
            inputObservations[observation.uuid] = observation
        }
        
        // Assume there is only one rectangle given our restrictions for VNDetectedObjectObservation's
        calculateDetectedObservationCenter(rects.first?.boundingBox ?? CGRect.zero)

        // Draw results
        delegate?.displayFrame(rects)
        
        if trackingFailedForAtLeastOneObject {
            throw VisionTrackerProcessorError.objectTrackingFailed
        }
    }
    
    func calculateDetectedObservationCenter(_ rect: CGRect) {
        centerDetectionActive = true
        centerDetectedObservation = CGPoint(x: rect.midX, y: rect.midY)
    }
    
    // MARK: Reset initial conditions
    func reset() {
        didInitialize = false
        centerDetectionActive = false
    }
}
