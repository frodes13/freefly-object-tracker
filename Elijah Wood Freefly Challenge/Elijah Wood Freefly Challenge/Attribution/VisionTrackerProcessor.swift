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
}

class VisionTrackerProcessor {
    var trackingLevel = VNRequestTrackingLevel.accurate
    var objectsToTrack = [TrackedPolyRect]()
    weak var delegate: VisionTrackerProcessorDelegate?

    private var initialRectObservations = [VNRectangleObservation]()
    
    // Create initial observations
    private var inputObservations = [UUID: VNDetectedObjectObservation]()
    private var trackedObjects = [UUID: TrackedPolyRect]()
    private var requestHandler: VNSequenceRequestHandler!
    private var trackingFailedForAtLeastOneObject = false
    private var didInitialize = false
    
    /// - Tag: SetInitialCondition
    /// - Tag: InitializeTrackerProcessor
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
    
    func reset() {
        didInitialize = false
    }

    /// - Tag: ProcessFrame
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
            #warning("orientation property?")
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

        // Draw results
        delegate?.displayFrame(rects)
        
        if trackingFailedForAtLeastOneObject {
            print ("PENIS ERROR")
            throw VisionTrackerProcessorError.objectTrackingFailed
        }
    }

    func readAndDisplayFirstFrame(frame: CVPixelBuffer, performRectanglesDetection: Bool) throws {

        var firstFrameRects: [TrackedPolyRect]? = nil
        if performRectanglesDetection {
            // Vision Rectangle Detection
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: frame, orientation: .up, options: [:]) // Force left orientation

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
}
