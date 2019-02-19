/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the tracker processing logic using Vision.
*/

#warning("Modified")

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
//    func displayFrameCounter(_ frame: Int)
    func didFinishTracking()
}

class VisionTrackerProcessor {
    var trackingLevel = VNRequestTrackingLevel.accurate
    var objectsToTrack = [TrackedPolyRect]()
    weak var delegate: VisionTrackerProcessorDelegate?

//    private var cancelRequested = false
    private var initialRectObservations = [VNRectangleObservation]()
    
    /// - Tag: SetInitialCondition
    func readAndDisplayFirstFrame(frame: CVPixelBuffer, performRectanglesDetection: Bool) throws {
        
        var firstFrameRects: [TrackedPolyRect]? = nil
        if performRectanglesDetection {
            // Vision Rectangle Detection
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: frame, orientation: .left, options: [:]) // Force left orientation
            
            let rectangleDetectionRequest = VNDetectRectanglesRequest()
            rectangleDetectionRequest.minimumAspectRatio = VNAspectRatio(0.2)
            rectangleDetectionRequest.maximumAspectRatio = VNAspectRatio(1.0)
            rectangleDetectionRequest.minimumSize = Float(0.1)
            rectangleDetectionRequest.maximumObservations = Int(10)
            
            do {
                try imageRequestHandler.perform([rectangleDetectionRequest])
            } catch {
                throw VisionTrackerProcessorError.rectangleDetectionFailed
            }

            if let rectObservations = rectangleDetectionRequest.results as? [VNRectangleObservation] {
                initialRectObservations = rectObservations
                var detectedRects = [TrackedPolyRect]()
                for (index, rectangleObservation) in initialRectObservations.enumerated() {
                    let rectColor = TrackedObjectsPalette.color(atIndex: index)
                    detectedRects.append(TrackedPolyRect(observation: rectangleObservation, color: rectColor))
                }
                firstFrameRects = detectedRects
            }
        }
        
        delegate?.displayFrame(firstFrameRects)
    }

    /// - Tag: PerformRequests
    func performTracking(frame: CVPixelBuffer, type: TrackedObjectType) throws {
        
        // Create initial observations
        var inputObservations = [UUID: VNDetectedObjectObservation]()
        var trackedObjects = [UUID: TrackedPolyRect]()
        switch type {
        case .object:
            for rect in self.objectsToTrack {
                let inputObservation = VNDetectedObjectObservation(boundingBox: rect.boundingBox)
                inputObservations[inputObservation.uuid] = inputObservation
                trackedObjects[inputObservation.uuid] = rect
            }
        case .rectangle:
            for rectangleObservation in initialRectObservations {
                inputObservations[rectangleObservation.uuid] = rectangleObservation
                let rectColor = TrackedObjectsPalette.color(atIndex: trackedObjects.count)
                trackedObjects[rectangleObservation.uuid] = TrackedPolyRect(observation: rectangleObservation, color: rectColor)
            }
        }
        let requestHandler = VNSequenceRequestHandler()
        var trackingFailedForAtLeastOneObject = false
        
        var rects = [TrackedPolyRect]()
        var trackingRequests = [VNRequest]()
        for inputObservation in inputObservations {
            let request: VNTrackingRequest!
            switch type {
            case .object:
                request = VNTrackObjectRequest(detectedObjectObservation: inputObservation.value)
            case .rectangle:
                guard let rectObservation = inputObservation.value as? VNRectangleObservation else {
                    continue
                }
                request = VNTrackRectangleRequest(rectangleObservation: rectObservation)
            }
            request.trackingLevel = trackingLevel
         
            trackingRequests.append(request)
        }
        
        // Perform array of requests
        do {
            try requestHandler.perform(trackingRequests, on: frame, orientation: .left)
            #warning("orientation property?")
        } catch {
            trackingFailedForAtLeastOneObject = true
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
            switch type {
            case .object:
                rects.append(TrackedPolyRect(observation: observation, color: knownRect.color, style: rectStyle))
            case .rectangle:
                guard let rectObservation = observation as? VNRectangleObservation else {
                    break
                }
                rects.append(TrackedPolyRect(observation: rectObservation, color: knownRect.color, style: rectStyle))
            }
            // Initialize inputObservation for the next iteration
            inputObservations[observation.uuid] = observation
        }

        // Draw results
        delegate?.displayFrame(rects)
//        print("display frame")
        
//        }

//        delegate?.didFinishTracking()
        
        if trackingFailedForAtLeastOneObject {
            throw VisionTrackerProcessorError.objectTrackingFailed
        }
    }
        
//    func cancelTracking() {
//        cancelRequested = true
//    }
}
